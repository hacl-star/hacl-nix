# This Nix expression provides helper functions for creating Hydra
# declarative jobsets
{ pkgs }:
let inherit (pkgs.lib) flip hasPrefix filter splitString; in
rec {
  makeJob = priority: description: flake: {
    inherit description flake;
    enabled = 1;
    type = 1;
    hidden = false;
    # If [checkinterval ≠ 0], then job is evaluated a first time at [t=0]!
    # Here, we basically disable [checkinterval], but still, with jobs being evaluated on creation
    checkinterval = 120;
    schedulingshares = priority;
    enableemail = false;
    emailoverride = "";
    keepnr = 1;
  };
  attrsToList = l:
    builtins.attrValues (
      builtins.mapAttrs (name: value: {inherit name value;}) l
    );
  readJSONFile = prs: builtins.fromJSON (builtins.readFile prs);
  mapFilter = f: l: builtins.filter (x: !(isNull x)) (map f l);
  mapFilterAttrs = f: attrs: builtins.listToAttrs (mapFilter ({name, value}: f name value) (attrsToList attrs));
  default-blacklist = lines (builtins.readFile ./blacklist.txt);
  makeGitHubJobsets' = {repo, owner, blacklist ? default-blacklist, dir ? null }:
    let
      blacklisted = sha: pkgs.lib.any (flip hasPrefix sha) blacklist;
      jobOfRef = name: {ref, object, ...}:
        if isNull (builtins.match "^refs/heads/[^_].*$" ref)
           || blacklisted object.sha
        then null
        else {
          name = "branch-${name}";
          value = makeJob (if name == "master" then 1000 else 1)
            "Branch ${name}"
            (if dir == null then "github:${owner}/${repo}?ref=${ref}" else "github:${owner}/${repo}?ref=${ref}?dir=${dir}");
        };
      jobOfPR = id: info:
        # If the PR is a branch of the repository [owner/repo], we
        # wanna avoid two jobsets with two different names for the
        # exact same branch
        if info.head.repo.name == repo && info.head.repo.owner.login == owner && !(hasPrefix "_" info.head.ref)
        then jobOfRef info.head.ref {ref = "refs/heads/${info.head.ref}"; object = {inherit (info.head) sha;};}
        else
          if blacklisted info.head.sha
          then null
          else {
            name = "pr-${id}";
            value = makeJob 50
              "PR ${id}: ${info.title}"
              "github:${info.head.repo.full_name}?ref=${info.head.ref}";
          };
    in
      { prs, refs, ... }: mapFilterAttrs jobOfPR  prs
                       // mapFilterAttrs jobOfRef refs;
  makeGitHubJobsets =
    opts: { prs, refs, dir ? null, ... }:
    {
      jobsets = pkgs.writeText "spec.json" (builtins.toJSON (makeGitHubJobsets' opts {
        prs  = readJSONFile prs;
        refs = readJSONFile refs;
      }));
    };
  lines = s: filter (x: x != "") (splitString "\n" s);
}

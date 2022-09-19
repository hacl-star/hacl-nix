{ owner, repo, prs, refs, hacl-nix, ... }:
(import (hacl-nix + "/hydra-helpers/default.nix")).lib.${builtins.currentSystem}.makeGitHubJobsets
  {inherit owner repo;}
  {inherit prs refs;}

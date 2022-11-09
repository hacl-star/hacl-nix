{
  description = "Hacl*";

  inputs = {
    fstar-src = {
      url = "github:fstarlang/fstar";
      flake = false;
    };
    karamel-src = {
      url = "github:fstarlang/karamel";
      flake = false;
    };
    flake-utils.url = "flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, fstar-src, karamel-src, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs.lib)
          mapAttrs mapAttrs' mapAttrsToList nameValuePair filterAttrs foldAttrs;
        haclDeps =
          import ./haclDeps.nix { inherit pkgs fstar-src karamel-src; };
      in rec {
        packages = haclDeps;
        hydraJobs = haclDeps;
      });
}

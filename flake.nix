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
    hacl-src = {
      url = "github:hacl-star/hacl-star";
      flake = false;
    };

    flake-utils.url = "flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { fstar-src, karamel-src, hacl-src, flake-utils, nixpkgs, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs.lib)
          mapAttrs mapAttrs' mapAttrsToList nameValuePair filterAttrs foldAttrs;
        everestPackages = import ./everestPackages.nix {
          inherit pkgs fstar-src karamel-src hacl-src;
        };
      in rec {
        packages = everestPackages // { default = everestPackages.hacl; };
        hydraJobs = everestPackages // {
          hacl-build-products = packages.hacl.passthru.build-products;
          hacl-stats = packages.hacl.passthru.stats;
        };
      });
}

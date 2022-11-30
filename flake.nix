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
    hacl-star = {
      url = "github:hacl-star/hacl-star";
      inputs = {
        fstar-src.follows = "fstar-src";
        karamel-src.follows = "karamel-src";
        hacl-nix.follows = "/";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, fstar-src, karamel-src, flake-utils, nixpkgs, hacl-star }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haclDeps =
          import ./haclDeps.nix { inherit pkgs fstar-src karamel-src; };
        inherit (hacl-star.packages.${system}) hacl;
        haclPackages = haclDeps // { inherit hacl; };
      in rec {
        packages = haclPackages // { default = haclPackages.hacl; };
        hydraJobs = haclPackages;
      });
}

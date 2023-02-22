{
  description = "Hacl*";

  inputs = {
    fstar.url = "github:fstarlang/fstar";
    flake-utils.follows = "fstar/flake-utils";
    nixpkgs.follows = "fstar/nixpkgs";
    karamel-src = {
      url = "github:fstarlang/karamel";
      flake = false;
    };
    hacl = {
      url = "github:hacl-star/hacl-star";
      inputs = {
        fstar.follows = "fstar";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        karamel-src.follows = "karamel-src";
      };
    };
  };

  outputs = { flake-utils, hacl, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        haclPackages = {
          inherit (hacl.packages.${system}) z3 fstar karamel vale hacl;
        };
      in {
        packages = haclPackages;
        hydraJobs = haclPackages;
      });
}

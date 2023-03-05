{
  description = "Hacl*";

  inputs = {
    fstar.url = "github:fstarlang/fstar";
    flake-utils.follows = "fstar/flake-utils";
    nixpkgs.follows = "fstar/nixpkgs";
    karamel = {
      url = "github:fstarlang/karamel";
      inputs.fstar.follows = "fstar";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hacl = {
      url = "github:hacl-star/hacl-star";
      inputs = {
        fstar.follows = "fstar";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        karamel.follows = "karamel";
      };
    };
  };

  outputs = { self, flake-utils, nixpkgs, fstar, karamel, hacl }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        haclPackages = {
          inherit (fstar.packages.${system}) z3 fstar;
          inherit (karamel.packages.${system}) karamel;
          inherit (hacl.packages.${system}) hacl;
        };
      in {
        packages = haclPackages // { default = hacl.packages.${system}.hacl; };
        hydraJobs = haclPackages;
      });
}

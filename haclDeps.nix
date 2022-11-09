{ pkgs, fstar-src, karamel-src }:

let
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;
  haclDeps = rec {
    z3 = pkgs.callPackage ./z3 { };
    fstar = pkgs.callPackage ./fstar {
      inherit ocamlPackages z3;
      src = fstar-src;
    };
    karamel = pkgs.callPackage ./karamel {
      inherit ocamlPackages fstar z3;
      src = karamel-src;
    };
    vale = pkgs.callPackage ./vale { };
  };
in haclDeps

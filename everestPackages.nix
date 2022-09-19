{ pkgs, fstar-src, karamel-src, hacl-src }:

let
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;
  everestPackages = rec {
    mlcrypto = pkgs.callPackage ./mlcrypto { };
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
    hacl = pkgs.callPackage ./hacl {
      inherit ocamlPackages z3 fstar karamel vale mlcrypto;
      src = hacl-src;
    };
  };
in everestPackages

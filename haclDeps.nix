{ pkgs, fstar-src, karamel-src }:

let
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;
  z3 = pkgs.callPackage ./z3 { };
  vale = pkgs.callPackage ./vale { };
  libFstar = pkgs.callPackage ./fstar/lib.nix { inherit ocamlPackages z3; };
  fstar = libFstar.binary-of-ml-snapshot {
    pname = "fstar";
    version = fstar-src.rev;
    src = fstar-src;
  };
  karamel = pkgs.callPackage ./karamel {
    inherit ocamlPackages fstar z3;
    src = karamel-src;
  };
in { inherit z3 vale fstar karamel; }

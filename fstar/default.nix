{ stdenv, lib, makeWrapper, which, ocamlPackages, sd, sphinx, python39Packages
, z3, src, fetchFromGitHub }@inputs:
let
  inherit (import ./fstar-factory.nix {
    inherit stdenv lib makeWrapper which ocamlPackages sd fetchFromGitHub;
    z3 = z3;
  })
    binary-of-fstar check-fstar;
  pname = "fstar";
  rev = src.rev;
  bin = binary-of-fstar { inherit src pname rev; };
in bin // {
  passthru = {
    tests = check-fstar {
      inherit src;
      pname = "${pname}-checks";
      rev = src.rev;
      existing-fstar = bin;
    };
    doc = stdenv.mkDerivation {
      name = "${pname}-book";
      src = src + "/doc/book";
      buildInputs = [ sphinx python39Packages.sphinx_rtd_theme ];
      installPhase = ''
        mkdir -p "$out"/nix-support
        echo "doc manual $out/book" >> $out/nix-support/hydra-build-products
        mv _build/html $out/book
        echo "test3" > $out/book/test-wit
      '';
    };
  };
}

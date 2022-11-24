/* Provides derivations that operate on F* source trees.

   Those derivations realizes F* bootstraping. F* is bootsrapped via
   OCaml; F* source trees are assumed to provide an OCaml snapshot (in
   [src/ocaml-output]).

    - [ml-snapshot-of-fstar]: given an F* source tree [src] and an
      existing F* binary [existing-fstar], [ml-snapshot-of-fstar {src,
      existing-fstar, ...}] extracts F* sources (written in F*) as an
      OCaml snapshot.

    - [binary-of-ml-snapshot]: given an F* source tree [src] and a bunch
      of build options[1] [opts], [binary-of-ml-snapshot {src, opts, ...}]
      builds the OCaml snapshot [${src}/src/ocaml-output].

    - [binary-of-fstar] is basically the composition
      [binary-of-ml-snapshot ∘ ml-snapshot-of-fstar ∘ binary-of-ml-snapshot],
      that is the full bootrapping of the compiler.

   [1]: Options are given as a set composed of the following keys:
    • [keep-sources]     (defaults to [false])
         Whether the folder [src] is kept during [installPhase]
         (keep in mind OCaml snapshots live under [src])
    • [compile-fstar]    (defaults to [true] )
         Wether [bin/fstar.exe] is built
    • [compile-bytecode] (defaults to [false])
         Wether [bin/fstar.ocaml] is built
    • [compile-tests]    (defaults to [false])
         Wether [bin/test.exe] is built
    • [compile-comp-lib]  (defaults to [true] )
         Wether F*'s compiler OCaml library is built & installed
    • [compile-ulib]     (defaults to [true] )
         Wether F*'s [ulib] OCaml library is built & installed
*/
{ stdenv, lib, makeWrapper, which, z3, ocamlPackages, sd, ... }:
let
  /* Following [https://github.com/FStarLang/FStar/blob/master/fstar.opam],
     [ocamlBuildInputs] is the list of OCaml packages necessary to build F* snapshots.
  */
  ocamlNativeBuildInputs = with ocamlPackages; [
    ocaml
    ocamlbuild
    findlib
    menhir
  ];
  ocamlBuildInputs = with ocamlPackages; [
    batteries
    zarith
    stdint
    yojson
    fileutils
    menhirLib
    pprint
    sedlex
    ppxlib
    ppx_deriving
    ppx_deriving_yojson
    process
  ];
  preBuild = { pname, version }: ''
    echo "echo ${lib.escapeShellArg pname}-${version}" > src/tools/get_commit
    patchShebangs src/tools ulib/gen_mllib.sh bin
    substituteInPlace src/ocaml-output/Makefile --replace '$(COMMIT)' '${version}'
  '';
  # Default options
  defaults = {
    keep-sources = false;
    compile-fstar = true;
    compile-bytecode = false;
    compile-tests = true;
    compile-comp-lib = true;
    compile-ulib = true;
  };
  binary-of-ml-snapshot = { src, pname, version, opts ? { } }:
    stdenv.mkDerivation (defaults // opts // {
      inherit src pname version;

      nativeBuildInputs = [ makeWrapper z3 ] ++ ocamlNativeBuildInputs;
      buildInputs = ocamlBuildInputs;

      preBuildPhases = [ "preparePhase" ];
      preparePhase = preBuild { inherit pname version; };

      # Triggers [make] rules according to [opts] contents
      buildPhase = ''
        MAKE_FLAGS="-j$NIX_BUILD_CORES"
        [ -z "$compile-fstar"    ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/fstar.exe
        [ -z "$compile-bytecode" ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/fstar.ocaml
        [ -z "$compile-tests"    ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/tests.exe
        [ -z "$compile-comp-lib" ] || make $MAKE_FLAGS -C src/ocaml-output install-compiler-lib
        [ -z "$compile-ulib"     ] || { make $MAKE_FLAGS -C ulib/ml && make $MAKE_FLAGS -C ulib; }
      '';

      OCAML_VERSION = ocamlPackages.ocaml.version;
      Z3_PATH = lib.getBin z3;
      # Installs binaries and libraries according to [opts] contents
      installPhase = ''
        SITE_LIB="$out/lib/ocaml/$OCAML_VERSION/site-lib"
        copyBin () { cp bin/$1 $out/bin
                     wrapProgram $out/bin/$1 --prefix PATH ":" "$Z3_PATH/bin"
                   }
        instLib () { mkdir -p "$SITE_LIB"
                     cp -r "bin/$1" "$out/bin/$1"
                     ln -s "$out/bin/$1" "$SITE_LIB/$1"
                   }
        mkdir $out/{,ulib,bin}
        cp -r ./ulib/ $out/
        [ -z "$compile-fstar"    ] || copyBin fstar.exe
        [ -z "$compile-bytecode" ] || copyBin fstar.ocaml
        [ -z "$compile-tests"    ] || copyBin tests.exe
        [ -z "$keep-sources"     ] || cp -r ./src/ $out/
        [ -z "$compile-ulib"     ] || { instLib fstarlib
                                        instLib fstar-tactics-lib ; }
        [ -z "$compile-comp-lib" ] || { instLib fstar-compiler-lib; }
      '';

      dontFixup = true;

      meta.mainProgram = "fstar.exe";
    });
  # Helper derivation that prepares an F* source tree with an existing F* binary/
  with-existing-fstar = { src, pname, version, existing-fstar, patches ? [ ], }:
    stdenv.mkDerivation {
      inherit pname src patches version;
      EX_FSTAR = existing-fstar;
      nativeBuildInputs = [ z3 which existing-fstar ];
      preBuildPhases = [ "preparePhase" "copyBinPhase" ];
      preparePhase = preBuild { inherit pname version; };
      copyBinPhase = ''
        cd bin
        # Next line is required when building F* before commit [6dbcdc1bce]
        rm fstar-any.sh 2>/dev/null && ln -s "$EX_FSTAR/bin/fstar.exe" fstar-any.sh
        for f in "$EX_FSTAR"/bin/*; do
          file=$(basename -- "$f")
          test -f "$file" && rm "$file"
          ln -s "$f" ./
        done
        cd ..
      '';
      dontFixup = true;
    };
  ml-snapshot-of-fstar = opts:
    (with-existing-fstar opts).overrideAttrs (o: {
      buildFlags = [ "ocaml" "-C" "src" ];
      installPhase = "cp -r . $out";
    });
  /* F* tests are twofold:
     - the binary [tests.exe] runs "internal" tests;
     - the folder [tests] holds number of test cases under the shape of F* modules.
     [check-fstar] runs both.
  */
  check-fstar = opts:
    (with-existing-fstar opts).overrideAttrs (o: {
      buildPhase = ''
        ./bin/tests.exe
        ${sd}/bin/sd -s "/bin/echo" "echo" tests/machine_integers/Makefile
        # [OCAMLPATH] is already correctly set, disable override
        ${sd}/bin/sd -s "OCAMLPATH=" "IGNOREME=" ./ulib/gmake/Makefile.tmpl ./ulib/ml/Makefile.include
        make -j$NIX_BUILD_CORES -C tests
      '';
      installPhase = "touch $out";
      nativeBuildInputs = o.nativeBuildInputs ++ ocamlNativeBuildInputs;
      buildInputs = ocamlBuildInputs;
    });
  binary-of-fstar = { src, pname, version, patches ? [ ], existing-fstar ?
      binary-of-ml-snapshot {
        inherit src version;
        pname = "${pname}-bootstrap";
        opts = {
          compile-ulib = false;
          compile-comp-lib = false;
        };
      }, opts ? defaults }:
    binary-of-ml-snapshot {
      inherit pname version opts;
      src = ml-snapshot-of-fstar {
        inherit src existing-fstar patches;
        pname = "${pname}-ml-snapshot";
        inherit version;
      };
    };
in {
  inherit binary-of-fstar ml-snapshot-of-fstar binary-of-ml-snapshot check-fstar
    with-existing-fstar ocamlBuildInputs ocamlNativeBuildInputs;
}

/*
Provides derivations that operate on F* source trees.

Those derivations realizes F* bootstraping. F* is bootsrapped via
OCaml; F* source trees are assumed to provide an OCaml snapshot (in
[src/ocaml-output]).

 - [mlSnapshot-of-fstar]: given an F* source tree [src] and an
   existing F* binary [existing-fstar], [mlSnapshot-of-fstar {src,
   existing-fstar, ...}] extracts F* sources (written in F*) as an
   OCaml snapshot.

 - [binary-of-mlSnapshot]: given an F* source tree [src] and a bunch
   of build options¹ [opts], [binary-of-mlSnapshot {src, opts, ...}]
   builds the OCaml snapshot [${src}/src/ocaml-output].

 - [binary-of-fstar] is basically the composition
   [binary-of-mlSnapshot ∘ mlSnapshot-of-fstar ∘ binary-of-mlSnapshot],
   that is the full bootrapping of the compiler.

¹: Options are given as a set composed of the following keys:
 • [keepSources]     (defaults to [false])
      Whether the folder [src] is kept during [installPhase]
      (keep in mind OCaml snapshots live under [src])
 • [compileFStar]    (defaults to [true] )
      Wether [bin/fstar.exe] is built
 • [compileBytecode] (defaults to [false])
      Wether [bin/fstar.ocaml] is built
 • [compileTests]    (defaults to [false])
      Wether [bin/test.exe] is built
 • [compileCompLib]  (defaults to [true] )
      Wether F*'s compiler OCaml library is built & installed
 • [compileULib]     (defaults to [true] )
      Wether F*'s [ulib] OCaml library is built & installed
*/
{ stdenv, lib, makeWrapper, which, z3, ocamlPackages, sd, ... }:
let
  /* Following [https://github.com/FStarLang/FStar/blob/master/fstar.opam],
     [ocamlBuildInputs] is the list of OCaml packages necessary to build F* snapshots. */
  ocamlNativeBuildInputs = with ocamlPackages; [ ocaml ocamlbuild findlib menhir ];
  ocamlBuildInputs = with ocamlPackages; [
    batteries zarith stdint yojson fileutils
    menhirLib pprint sedlex ppxlib
    ppx_deriving ppx_deriving_yojson process
  ];
  preBuild = {pname,rev}:
  ''echo "echo ${lib.escapeShellArg pname}-${rev}" > src/tools/get_commit
    patchShebangs src/tools ulib/gen_mllib.sh bin
    substituteInPlace src/ocaml-output/Makefile --replace '$(COMMIT)' '${rev}'
  '';
  /* Default options */
  defaults = { keepSources     = false; compileFStar = true ;
               compileBytecode = false; compileTests = true ;
               compileCompLib  = true ; compileULib  = true ; };
  binary-of-mlSnapshot =
    { src, pname, rev, opts ? {} }: stdenv.mkDerivation (defaults // opts // {
      inherit src pname;
      version = rev;

      nativeBuildInputs = [ makeWrapper z3 ] ++ ocamlNativeBuildInputs;
      buildInputs = ocamlBuildInputs;

      preBuildPhases = ["preparePhase"];
      preparePhase = preBuild {inherit pname; inherit rev;};

      # Triggers [make] rules according to [opts] contents
      buildPhase = ''
        MAKE_FLAGS="-j$NIX_BUILD_CORES"
        [ -z "$compileFStar"    ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/fstar.exe
        [ -z "$compileBytecode" ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/fstar.ocaml
        [ -z "$compileTests"    ] || make $MAKE_FLAGS -C src/ocaml-output ../../bin/tests.exe
        [ -z "$compileCompLib"  ] || make $MAKE_FLAGS -C src/ocaml-output install-compiler-lib
        [ -z "$compileULib"     ] || { make $MAKE_FLAGS -C ulib/ml && make $MAKE_FLAGS -C ulib; }
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
        [ -z "$compileFStar"    ] || copyBin fstar.exe
        [ -z "$compileBytecode" ] || copyBin fstar.ocaml
        [ -z "$compileTests"    ] || copyBin tests.exe
        [ -z "$keepSources"     ] || cp -r ./src/ $out/
        [ -z "$compileULib"     ] || { instLib fstarlib
                                       instLib fstar-tactics-lib ; }
        [ -z "$compileCompLib"  ] || { instLib fstar-compiler-lib; }
      '';

      dontFixup = true;

      meta.mainProgram = "fstar.exe";
    });
  # Helper derivation that prepares an F* source tree with an existing F* binary/
  with-existing-fstar = {
    src, pname, rev, existing-fstar, patches ? [],
  }: stdenv.mkDerivation {
    inherit pname src patches;
    version = rev;
    EX_FSTAR = existing-fstar;
    nativeBuildInputs = [z3 which existing-fstar];
    preBuildPhases = ["preparePhase" "copyBinPhase"];
    preparePhase = preBuild {inherit pname rev;};
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
  mlSnapshot-of-fstar = opts: (with-existing-fstar opts).overrideAttrs (o: {
    buildFlags = [ "ocaml" "-C" "src" ];
    installPhase = ''cp -r . $out'';
  });
  /* F* tests are twofold:
     - the binary [tests.exe] runs "internal" tests;
     - the folder [tests] holds number of test cases under the shape of F* modules.
     [check-fstar] runs both.
  */
  check-fstar = opts: (with-existing-fstar opts).overrideAttrs (o: {
    buildPhase   = ''./bin/tests.exe
                     ${sd}/bin/sd -s "/bin/echo" "echo" tests/machine_integers/Makefile
                     # [OCAMLPATH] is already correctly set, disable override
                     ${sd}/bin/sd -s "OCAMLPATH=" "IGNOREME=" ./ulib/gmake/Makefile.tmpl ./ulib/ml/Makefile.include
                     make -j$NIX_BUILD_CORES -C tests
                   '';
    installPhase = ''touch $out'';
    nativeBuildInputs = o.nativeBuildInputs ++ ocamlNativeBuildInputs;
    buildInputs = ocamlBuildInputs;
  });
  binary-of-fstar =
    { src, pname, rev
    , patches ? []
    , existing-fstar ? binary-of-mlSnapshot { inherit src;
                                              pname = "${pname}-bootstrap";
                                              inherit rev;
                                              opts = {
                                                compileULib    = false;
                                                compileCompLib = false;
                                              };
                                            }
    , opts ? defaults
    }:
    binary-of-mlSnapshot {
      inherit pname rev opts;
      src = mlSnapshot-of-fstar {
        inherit src existing-fstar patches;
        pname = "${pname}-mlSnapshot";
        inherit rev;
      };
    };
in { inherit binary-of-fstar mlSnapshot-of-fstar binary-of-mlSnapshot check-fstar
             with-existing-fstar ocamlBuildInputs ocamlNativeBuildInputs;
   }

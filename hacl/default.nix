{ enableParallelBuilding ? true, dotnet-runtime, ocamlPackages, python3, stdenv
, which, writeTextFile, time, z3, fstar, karamel, vale, nodejs, nodePackages
, openssl, git, src }:

let

  hacl = stdenv.mkDerivation {
    name = "hacl-star";

    inherit src;

    postPatch = ''
      patchShebangs tools
      patchShebangs dist/configure
      substituteInPlace Makefile --replace "NOSHORTLOG=1" ""
      substituteInPlace Makefile --replace "test-wasm test-bindings-ocaml" "test-wasm"
      substituteInPlace Makefile --replace "doc-wasm doc-ocaml" "doc-wasm"
      echo "0.3.19" > vale/.vale_version
    '';

    nativeBuildInputs =
      [ z3 fstar python3 which dotnet-runtime time nodejs nodePackages.jsdoc ]
      ++ (with ocamlPackages; [
        ocaml
        findlib
        batteries
        pprint
        stdint
        yojson
        zarith
        ppxlib
        ppx_deriving
        ppx_deriving_yojson
        ctypes
      ]);

    buildInputs = [ openssl.dev ];

    VALE_HOME = vale;
    FSTAR_HOME = fstar;
    KRML_HOME = karamel;

    configurePhase = ''
      export HACL_HOME=$(pwd)
    '';

    inherit enableParallelBuilding;

    buildPhase = ''
      rm -rf dist/*/*
      make -j$NIX_BUILD_CORES ci 2>&1 | tee log.txt
    '';

    installPhase = ''
      cp -r ./. $out
    '';

    dontFixup = true;

    passthru = rec {
      info = writeTextFile {
        name = "INFO.txt";
        text = ''
          This code was generated with the following toolchain.
          F* version: ${fstar.version}
          Karamel version: ${karamel.version}
          Vale version: ${vale.version}
        '';
      };
      dist-compare = stdenv.mkDerivation {
        name = "hacl-diff-compare";
        src = "${hacl.build-products}/dist.tar";
        phases = [ "unpackPhase" "buildPhase" "installPhase" ];
        buildPhase = ''
          for file in ./*/*.c ./*/*.h
          do
            if ! diff $file ${hacl.src}/dist/$file 2>&1 > /dev/null
            then
              echo "*** $file"
              diff -y --suppress-common-lines $file ${hacl.src}/dist/$file || true
            fi
          done
        '';
        installPhase = ''
          touch $out
        '';
      };
      dist-list = stdenv.mkDerivation {
        name = "hacl-diff-list";
        src = "${hacl.build-products}/dist.tar";
        phases = [ "unpackPhase" "buildPhase" "installPhase" ];
        buildPhase = ''
          mkdir $out
          diff -rq . ${hacl.src}/dist 2>&1 \
            | sed 's/\/nix\/store\/[a-z0-9]\{32\}-//g' \
            | sed 's/^Files \([^ ]*\).*/\1/' \
            | sed 's/^Only in source\/dist\([^\:]*\)\: \(.*\)/\.\1\/\2/' \
            | sed 's/^Only in \.\([^\:]*\)\: \(.*\)/\.\1\/\2/' \
            | grep '\.\/[^\/]*\/' \
            | grep -v INFO.txt \
            | tee diff.txt || true
          ! [ -s diff.txt ]
        '';
        installPhase = ''
          touch $out
        '';
      };
      build-products = stdenv.mkDerivation {
        name = "hacl-build-products";
        src = hacl;
        buildInputs = [ git ];
        buildPhase = ''
          for target in c89-compatible election-guard gcc-compatible gcc64-only msvc-compatible portable-gcc-compatible
          do
            sed -i 's/\#\!.*/\#\!\/usr\/bin\/env bash/' dist/$target/configure
          done

          for target in c89-compatible election-guard gcc-compatible gcc64-only merkle-tree mozilla msvc-compatible portable-gcc-compatible wasm
          do
            cp ${info} dist/$target/INFO.txt
          done

          git init
          git config --local user.name "John Doe"
          git config --local user.email johndoe@example.com
          git add *
          git commit -m "initial commit"

          git archive HEAD hints > hints.tar
          git archive HEAD dist/*/ > dist.tar
          echo ${src.rev} > rev.txt
        '';
        installPhase = ''
          mkdir -p $out/nix-support
          cp hints.tar dist.tar rev.txt $out
          echo "file hints $out/hints.tar" >> $out/nix-support/hydra-build-products
          echo "file dist $out/dist.tar" >> $out/nix-support/hydra-build-products
          echo "file rev $out/rev.txt" >> $out/nix-support/hydra-build-products
        '';
      };
      stats = stdenv.mkDerivation {
        name = "hacl-stats";
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/nix-support
          echo "file stats $out/stats.txt" >> $out/nix-support/hydra-build-products
          cat ${hacl}/log.txt \
              | grep "^\[VERIFY\]" \
              | sed 's/\[VERIFY\] \(.*\), \(.*\)/\2 \1/' \
              | sort -rg - > $out/stats.txt
        '';
      };
    };

  };

in hacl

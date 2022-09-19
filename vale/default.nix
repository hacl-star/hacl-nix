{ dotnetPackages, fetchFromGitHub, fetchNuGet, fsharp, mono, scons, stdenv, }:

let
  FsLexYacc = fetchNuGet {
    pname = "FsLexYacc";
    version = "6.1.0";
    sha256 = "1v5myn62zqs431i046gscqw2v0c969fc7pdplx7z9cnpy0p2s4rv";
    outputFiles = [ "build/*" ];
  };
  FsLexYaccRuntime = fetchNuGet {
    pname = "FsLexYacc.Runtime";
    version = "6.1.0";
    sha256 = "18vrx4lxsn4hkfishg4abv0d4q21dsph0bm4mdq5z8afaypp5cr7";
    outputFiles = [ "lib/net40/*" ];
  };
  vale = stdenv.mkDerivation rec {
    pname = "vale";
    version = "0.3.19";

    src = fetchFromGitHub {
      owner = "project-everest";
      repo = "vale";
      rev = "v${version}";
      #sha256 = "sha256-S7i9znKfzk+4wqL0lSNB8r/sn0jN3Nt3Q29KwBjElcs="; # v0.3.16
      sha256 = "sha256-Y6BlLtX8o9gfJgk8FXymwsQ423+vt5QhHIfvGBiLGWE="; # v0.3.19
    };

    postPatch = ''
      substituteInPlace SConstruct --replace "common_env = Environment()" "common_env = Environment(ENV=os.environ)"
    '';

    preBuild = ''
      mkdir -p tools/FsLexYacc/{FsLexYacc.6.1.0/build,FsLexYacc.Runtime.6.1.0/lib/net40}
      cp -r ${FsLexYacc}/lib/dotnet/FsLexYacc/* tools/FsLexYacc/FsLexYacc.6.1.0/build/
      cp -r ${FsLexYaccRuntime}/lib/dotnet/FsLexYacc.Runtime/* tools/FsLexYacc/FsLexYacc.Runtime.6.1.0/lib/net40/
    '';

    buildInputs = [ FsLexYacc fsharp mono scons ];

    enableParallelBuilding = true;

    installPhase = ''
      mkdir -p $out/bin
      cp bin/* $out/bin

      cp -r . $out
      for target in vale importFStarTypes; do
        echo "$DOTNET_JSON_CONF" > $out/bin/$target.runtimeconfig.json
      done
    '';

    dontFixup = true;

    DOTNET_JSON_CONF = ''
      {
        "runtimeOptions": {
          "framework": {
            "name": "Microsoft.NETCore.App",
            "version": "6.0.0"
          }
        }
      }
    '';

    passthru = {
      binary-release = stdenv.mkDerivation {
        pname = "vale-release";
        inherit version;
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out
          cd ${vale}
          tar -cvf $out/vale-release-${version}.tar bin

          mkdir -p $out/nix-support
          echo "file vale $out/vale-release-${version}.tar" >> $out/nix-support/hydra-build-products
        '';
      };
    };
  };
in vale

{ ocamlPackages, openssl, perl, stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  name = "mlcrypto";

  src = fetchFromGitHub {
    owner = "project-everest";
    repo = "mlcrypto";
    fetchSubmodules = true;
    rev = "190250bbb8f16e7c3f6a8d443b13600ada4fbe79";
    sha256 = "JS01iYdNHltszxr/bxbX0qE+L9iwBDdTbn3aH2ji9I0=";
  };

  buildInputs = [ openssl.dev perl ] ++ (with ocamlPackages; [ ocaml findlib ]);

  enableParallelBuilding = true;

  installPhase = ''
    cp -r . $out
  '';
}

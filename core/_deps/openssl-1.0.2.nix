# Pinned OpenSSL 1.0.2u — required by old Bitcoin Core releases:
#  - 0.2.0–0.8.6: src/bignum.h uses the pre-1.1 non-opaque BIGNUM API.
#  - 0.9.0–0.12.1: configure's "Detected LibreSSL" heuristic fires on any
#    OpenSSL >= 1.1.0 (RAND_egd was removed in 1.1.0).
# nixpkgs of the era no longer ship openssl102, so it is vendored here.
{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } }:

with pkgs;
stdenv.mkDerivation rec {
  name = "openssl-${version}";
  pname = "openssl";
  version = "1.0.2u";

  src = fetchurl {
    url = "https://www.openssl.org/source/openssl-${version}.tar.gz";
    sha256 = "ecd0c6ffb493dd06707d38b14bb4d8c2288bb7033735606569d8f90f89669d16";
  };

  nativeBuildInputs = [ perl ];

  # OpenSSL has no ./configure; use ./config. Let it auto-detect the
  # target: passing linux-x86_64 explicitly aborts ("target already
  # defined") with the 1.0.2u Configure script.
  configurePhase = ''
    ./config --prefix=$out --libdir=lib
  '';

  enableParallelBuilding = true;

  # 1.0.2 has no install_ssldirs target (that is 1.1.x); install_sw
  # already creates the misc/certs/private dirs.
  installPhase = "make install_sw";

  meta = with lib; {
    description = "OpenSSL 1.0.2 (legacy) — dependency of Bitcoin Core ≤ 0.12.1";
    homepage = "https://www.openssl.org/";
    license = licenses.openssl;
    platforms = [ "x86_64-linux" ];
  };
}

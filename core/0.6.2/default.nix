{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
, boost ? (pkgs.boost.override { inherit stdenv; }), db48 ? (pkgs.db48.override { inherit stdenv; }), openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }, glib ? pkgs.glib, zlib ? pkgs.zlib
}:

with lib;
let
  version = "0.6.2";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.6.2.tar.gz"
    ];
    sha256 = "0f0c2f0b5cb1317720dbf0c4a62fa67dcf17b4bb229788e11530fa4b1c77b5f8";
  };
  sourceRoot = "bitcoin-0.6.2/src";

  buildInputs = [ boost db48 openssl glib zlib ];
  patchPhase = "
    runHook prePatch

  ";

  buildPhase = "
    runHook preBuild
    make -f makefile.unix bitcoind USE_UPNP=- CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive' LDFLAGS='-L${zlib}/lib -L${glib}/lib' BOOST_LIB_PATH=${boost}/lib BDB_LIB_PATH=${db48}/lib OPENSSL_LIB_PATH=${openssl}/lib BOOST_INCLUDE_PATH=${boost}/include BDB_INCLUDE_PATH=${db48}/include OPENSSL_INCLUDE_PATH=${openssl}/include BOOST_LIB_SUFFIX= BDB_LIB_SUFFIX=
  ";

  installPhase = "
    runHook preInstall
    install -Dm755 bitcoind $out/bin/bitcoind
  ";

  meta = {
    description = "Bitcoin Core 0.6.2";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

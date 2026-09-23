{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
, boost ? (pkgs.boost.override { inherit stdenv; }), db48 ? (pkgs.db48.override { inherit stdenv; }), openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }, glib ? pkgs.glib, zlib ? pkgs.zlib
}:

with lib;
let
  version = "0.8.4";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.8.4.tar.gz"
    ];
    sha256 = "6a3bbd259159b8a2b394c93676e3bf22136f9f1abbd9461018c1f5fd0c4ee8da";
  };
  sourceRoot = "bitcoin-0.8.4/src";

  buildInputs = [ boost db48 openssl glib zlib ];
  patchPhase = "
    runHook prePatch

  ";

  buildPhase = "
    runHook preBuild
    make -f makefile.unix bitcoind USE_UPNP=- CXX='${stdenv.cc}/bin/g++' CXXFLAGS='-std=gnu++03 -fpermissive' LDFLAGS='-L${zlib}/lib -L${glib}/lib' BOOST_LIB_PATH=${boost}/lib BDB_LIB_PATH=${db48}/lib OPENSSL_LIB_PATH=${openssl}/lib BOOST_INCLUDE_PATH=${boost}/include BDB_INCLUDE_PATH=${db48}/include OPENSSL_INCLUDE_PATH=${openssl}/include BOOST_LIB_SUFFIX= BDB_LIB_SUFFIX=
  ";

  installPhase = "
    runHook preInstall
    install -Dm755 bitcoind $out/bin/bitcoind
  ";

  meta = {
    description = "Bitcoin Core 0.8.4";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

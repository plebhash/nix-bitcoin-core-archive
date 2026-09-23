{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
, boost ? (pkgs.boost.override { inherit stdenv; }), db48 ? (pkgs.db48.override { inherit stdenv; }), openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }, glib ? pkgs.glib, zlib ? pkgs.zlib
}:

with lib;
let
  version = "0.5.1";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.5.1.tar.gz"
    ];
    sha256 = "4e1e674e6534a04974a8f64bb8f63e93867a07bd03d8e8af8bfe75fc1ea51971";
  };
  sourceRoot = "bitcoin-0.5.1/src";

  buildInputs = [ boost db48 openssl glib zlib ];
  patchPhase = "
    runHook prePatch

  ";

  buildPhase = "
    runHook preBuild
    make -f makefile.unix bitcoind USE_UPNP=- CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive' LDFLAGS='-L${boost}/lib -L${db48}/lib -L${openssl}/lib -L${glib}/lib -L${zlib}/lib' BOOST_INCLUDE_PATH=${boost}/include BDB_INCLUDE_PATH=${db48}/include OPENSSL_INCLUDE_PATH=${openssl}/include BOOST_LIB_SUFFIX= BDB_LIB_SUFFIX=
  ";

  installPhase = "
    runHook preInstall
    install -Dm755 bitcoind $out/bin/bitcoind
  ";

  meta = {
    description = "Bitcoin Core 0.5.1";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

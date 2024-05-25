{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, hexdump ? pkgs.hexdump
, boost ? pkgs.boost
, libevent ? pkgs.libevent
, miniupnpc ? pkgs.miniupnpc
, zeromq ? pkgs.zeromq
, zlib ? pkgs.zlib
, db48 ? pkgs.db48
, sqlite ? pkgs.sqlite
, qrencode ? pkgs.qrencode
, python3 ? pkgs.python3
, nixosTests ? pkgs.nixosTests
, libtool ? pkgs.libtool
, intltool ? pkgs.intltool
}:

with lib;
let
  version = "24.99.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind-mutinynet";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "benthecarman";
    repo = "bitcoin";
    rev = "custom-signet-blocktime";
    sha256 = "Y3PjlKcH5DpfT+d2YAwPylNDJExB8Z0C0E4SB/Lt3vY=";
  };

nativeBuildInputs =
  [ autoreconfHook pkg-config intltool ]
  ++ optionals stdenv.isLinux [ util-linux ]
  ++ optionals stdenv.isDarwin [ hexdump ];

  buildInputs = [ boost libevent miniupnpc zeromq zlib ];

  configureFlags = [
    "--disable-tests"
    "--disable-gui-tests"
  ];

  checkInputs = [ python3 ];

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;

  makeFlags = [ "-j8" ];

  meta = {
    description = "A custom Bitcoin Signet with ~30s block time. Maintained by Mutiny";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}


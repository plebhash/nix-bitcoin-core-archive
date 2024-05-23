{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } 
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchurl ? pkgs.fetchurl
, autoreconfHook ? pkgs.autoreconfHook
, pkg-config ? pkgs.pkg-config
, util-linux ? pkgs.util-linux
, hexdump ? pkgs.hexdump
, autoSignDarwinBinariesHook ? pkgs.autoSignDarwinBinariesHook
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
}:

with lib;
let
  version = "22.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://bitcoincore.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
      "https://bitcoin.org/bin/bitcoin-core-${version}/bitcoin-${version}.tar.gz"
    ];
    sha256 = "sha256-0OnQibVwSLFVXvp81aY6ftBCSCBF9vM0ArHfQlv5YTs=";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ]
    ++ optionals stdenv.isDarwin [ hexdump ]
    ++ optionals (stdenv.isDarwin && stdenv.isAarch64) [ autoSignDarwinBinariesHook ];

  buildInputs = [ boost libevent miniupnpc zeromq zlib ];

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-wallet"
    "--disable-tests"
    "--disable-gui-tests"
  ];

  checkInputs = [ python3 ];

  doCheck = true;

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;

  passthru.tests = {
    smoke-test = nixosTests.bitcoind;
  };

  meta = {
    description = "Peer-to-peer electronic cash system";
    longDescription = ''
      Bitcoin is a free open source peer-to-peer electronic cash system that is
      completely decentralized, without the need for a central server or trusted
      parties. Users hold the crypto keys to their own money and transact directly
      with each other, with the help of a P2P network to check for double-spending.
    '';
    homepage = "https://bitcoin.org/";
    downloadPage = "https://bitcoincore.org/bin/bitcoin-core-${version}/";
    changelog = "https://bitcoincore.org/en/releases/${version}/";
    maintainers = with maintainers; [ prusnak roconnor ];
    license = licenses.mit;
    platforms = platforms.unix;
  };
}

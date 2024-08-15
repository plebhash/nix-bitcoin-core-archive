{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
, fetchFromGitHub ? pkgs.fetchFromGitHub
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
}:

with lib;
let
  version = "v27.99.0";
  majorVersion = versions.major version;
in
stdenv.mkDerivation rec {
  pname = "bitcoind-cpunet-braidpool";
  inherit version;

  src = fetchFromGitHub {
    owner = "braidpool";
    repo = "bitcoin";
    rev = "53398930f7fb080473750f2774ab66470dee0aed";
    hash = "sha256-D69UKsHJF96rCu4WEag4xiB8V5rhUNPykSP9pm6nYGk=";
  };

  nativeBuildInputs =
    [ autoreconfHook pkg-config ]
    ++ optionals stdenv.isLinux [ util-linux ];

  buildInputs = [ boost libevent db48 sqlite miniupnpc zeromq zlib ];

  configureFlags = [
    "--with-boost-libdir=${boost.out}/lib"
    "--disable-bench"
    "--disable-tests"
    "--disable-gui-tests"
    "--disable-fuzz"
    "--disable-fuzz-binary"
    "--disable-bench"
  ];

  checkInputs = [ python3 ];

  doCheck = false;

  checkFlags = [ "LC_ALL=en_US.UTF-8" ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall

    # Install the binaries with proper permissions
    install -Dm755 src/bitcoind $out/bin/bitcoind
    install -Dm755 src/bitcoin-cli $out/bin/bitcoin-cli
    install -Dm755 src/bitcoin-tx $out/bin/bitcoin-tx

    # Install the entire contrib directory
    mkdir -p $out/contrib
    cp -r contrib/* $out/contrib/

    runHook postInstall
  '';

  meta = {
    description = "Bitcoin Core with a CPUnet braidpool patch";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}

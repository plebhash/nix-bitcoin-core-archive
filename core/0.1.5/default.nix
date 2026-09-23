{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
}:

with lib;

stdenv.mkDerivation rec {
  name = "bitcoin-src-${version}";
  pname = "bitcoin-src";
  version = "0.1.5";


  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.1.5.tar.gz"
    ];
    sha256 = "b0679fea68d65007f0c05c81cd9a296acfc299767cc7c46992fe8ea9928e6cb0";
  };
  # Source-only artifact — do not attempt to build the 2007-era makefile.
  dontBuild = true;
  dontConfigure = true;
  installPhase = ''
    cd $NIX_BUILD_TOP
    mkdir -p $out/src
    cp -r $sourceRoot/. $out/src/
  '';

  meta = {
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

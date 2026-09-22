{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } }:

# miniupnpc 2.2.2 — vendored because nixpkgs 24.05+ ships miniupnpc 2.3.x,
# whose UPNP_GetValidIGD() API (7 args) breaks Bitcoin Core <= 28.4, which
# uses the classic 5-arg signature. Bitcoin 29.0+ removed UPnP entirely.
with pkgs;
stdenv.mkDerivation rec {
  pname = "miniupnpc";
  version = "2.2.2";

  src = fetchurl {
    url = "https://codeload.github.com/miniupnp/miniupnp/tar.gz/refs/tags/miniupnpc_2_2_2";
    name = "miniupnpc-2.2.2.tar.gz";
    sha256 = "a598890cad635170dfce6281d71fc3052dee5c8220da0109281542156267c762";
  };
  sourceRoot = "miniupnp-miniupnpc_2_2_2/miniupnpc";

  # Plain Makefile (no autotools) since the 2.2.x series.
  buildPhase = "make";
  installPhase = "make install INSTALLPREFIX=$out";

  meta = with lib; {
    description = "Client that implements the UPnP Internet Gateway Device (IGD) specification";
    homepage = "https://miniupnp.tuxfamily.org/";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}

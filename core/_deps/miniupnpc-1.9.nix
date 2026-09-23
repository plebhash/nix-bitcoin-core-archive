# Pinned miniupnpc 1.9.20160209 (API version 16) — required by Bitcoin Core
# 22.1–24.2, whose mapport.cpp has
#   static_assert(MINIUPNPC_API_VERSION >= 10, …)
# and calls the 5-arg UPNP_GetValidIGD(). miniupnpc 2.x (API ≥ 18) dropped
# the 5-arg form; miniupnpc 1.7 (API 8) fails the static_assert.
{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } }:

with pkgs;
stdenv.mkDerivation rec {
  name = "miniupnpc-${version}";
  pname = "miniupnpc";
  version = "1.9.20160209";

  src = fetchurl {
    url = "http://miniupnp.free.fr/files/download.php?file=${pname}-${version}.tar.gz";
    sha256 = "0vsbv6a8by67alx4rxfsrxxsnmq74rqlavvvwiy56whxrkm728ap";
  };

  makeFlags = [ "PREFIX=$out" ];

  installPhase = "make install PREFIX=$out INSTALLPREFIX=$out";

  meta = with lib; {
    description = "UPnP Internet Gateway Device client library — dependency of Bitcoin Core 22.1–24.2";
    homepage = "https://miniupnpc.codelab.net/";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}

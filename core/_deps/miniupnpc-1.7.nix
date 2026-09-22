# Pinned miniupnpc 1.7 — required by Bitcoin Core 0.9.0–0.12.1, which call
# the 6-arg upnpDiscover() and 5-arg UPNP_GetValidIGD() (API level ≤ 8).
# Newer miniupnpc (≥ 1.9-dev) changed upnpDiscovery to 7 args and broke
# compilation of these releases.
{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; } }:

with pkgs;
stdenv.mkDerivation rec {
  name = "miniupnpc-${version}";
  pname = "miniupnpc";
  version = "1.7";

  src = fetchurl {
    url = "http://miniupnp.free.fr/files/download.php?file=${pname}-${version}.tar.gz";
    sha256 = "0dv3mz4yikngmlnrnmh747mlgbbpijryw03wcs8g4jwvprb29p8n";
  };

  makeFlags = [ "PREFIX=$out" ];

  # Makefile's install target derives dirs from INSTALLPREFIX, which
  # defaults to $(PREFIX)/usr — set it explicitly to install flat.
  installPhase = "make install PREFIX=$out INSTALLPREFIX=$out";

  meta = with lib; {
    description = "UPnP Internet Gateway Device client library (legacy API) — dependency of Bitcoin Core 0.9.x–0.12.1";
    homepage = "https://miniupnpc.codelab.net/";
    license = licenses.bsd3;
    platforms = platforms.linux;
  };
}

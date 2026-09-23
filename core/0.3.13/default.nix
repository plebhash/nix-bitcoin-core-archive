{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
, boost ? (pkgs.boost.override { inherit stdenv; }), db48 ? (pkgs.db48.override { inherit stdenv; }), openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }, glib ? pkgs.glib, zlib ? pkgs.zlib, wx29 ? (pkgs.wxGTK29.override { inherit stdenv; }), gtk2 ? pkgs.gtk2, libSM ? pkgs.xorg.libSM
}:

with lib;
let
  version = "0.3.13";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.3.13.tar.gz"
    ];
    sha256 = "c043abaff1fb750ea3ec42215a11937c99b5d365ab16554f7f60bd8611bb4bb7";
  };
  sourceRoot = "bitcoin-0.3.13";

  buildInputs = [ boost db48 openssl glib zlib wx29 gtk2 libSM ];
  patchPhase = "
    runHook prePatch
    sed -i 's/^\tg++ /\t$(CXX) /g' makefile.unix
    sed -i 's|-I\"/usr/local/include/wx-2.9\"|-I${wx29}/include -I${wx29}/lib/wx/include/gtk2-unicode-2.9|g' makefile.unix
    sed -i '/-I\\/usr\\/local\\/lib\\/wx/d' makefile.unix
    sed -i 's|-I\"/usr/include\"|-I${boost}/include -I${openssl}/include -I${db48}/include|g' makefile.unix
    sed -i 's|-L\"/usr/lib\"|-L${wx29}/lib -L${boost}/lib -L${db48}/lib -L${openssl}/lib -L${glib}/lib|g' makefile.unix
    sed -i '/-L\\/usr\\/local\\/lib/d' makefile.unix
    sed -i 's/-l wx_gtk2ud-2.9/-l wx_gtk2u_core-2.9/g' makefile.unix
  ";

  buildPhase = "
    runHook preBuild
    mkdir -p obj obj/nogui obj/test cryptopp/obj
    sed -i 's/= htons(\\([0-9]*\\))/= __builtin_bswap16(\\1)/g; s/= htonl(\\([0-9]*\\))/= __builtin_bswap32(\\1)/g; s/= ntohs(\\([0-9]*\\))/= __builtin_bswap16(\\1)/g; s/= ntohl(\\([0-9]*\\))/= __builtin_bswap32(\\1)/g' *.h
    sed -i 's|min(nSize - i, 1 + 4999999 / sizeof(T))|min(nSize - i, (unsigned int)(1 + 4999999 / sizeof(T)))|' serialize.h
    sed -i 's|-Wl,-Bstatic|-L${boost}/lib -L${db48}/lib -L${openssl}/lib -L${glib}/lib -L${zlib}/lib -l dl|' makefile.unix
    make -f makefile.unix bitcoind CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive'
  ";

  installPhase = "
    runHook preInstall
    install -Dm755 bitcoind $out/bin/bitcoind
  ";

  meta = {
    description = "Bitcoin Core 0.3.13";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

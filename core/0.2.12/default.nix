{ pkgs ? import <nixpkgs> { system = builtins.currentSystem; }
, lib ? pkgs.lib
, stdenv ? (pkgs.stdenv.override { cc = pkgs.gcc49; })
, fetchurl ? pkgs.fetchurl
, boost ? (pkgs.boost.override { inherit stdenv; }), db48 ? (pkgs.db48.override { inherit stdenv; }), openssl ? import ../_deps/openssl-1.0.2.nix { pkgs = pkgs; }, glib ? pkgs.glib, zlib ? pkgs.zlib, wx29 ? (pkgs.wxGTK29.override { inherit stdenv; }), gtk2 ? pkgs.gtk2, libSM ? pkgs.xorg.libSM
}:

with lib;
let
  version = "0.2.12";
in
stdenv.mkDerivation rec {
  name = "bitcoind-${version}";
  pname = "bitcoind";
  inherit version;

  src = fetchurl {
    urls = [
      "https://github.com/bitcoin/bitcoin/archive/refs/tags/v0.2.12.tar.gz"
    ];
    sha256 = "b14d3fc6810fe8423ac4c95b4f1be2ec862ecc726244784ecbe70304bd81d572";
  };
  sourceRoot = "bitcoin-0.2.12";

  buildInputs = [ boost db48 openssl glib zlib wx29 gtk2 libSM ];
  patchPhase = "
    runHook prePatch
    sed -i 's/^\tg++ /\t$(CXX) /g' makefile.unix
    sed -i 's/-l boost_\\([a-z]*\\)-mt/-l boost_\\1/g' makefile.unix
    sed -i 's|-I\"/usr/local/include/wx-2.9\"|-I${wx29}/include -I${wx29}/lib/wx/include/gtk2-unicode-2.9|g' makefile.unix
    sed -i '/-I\\/usr\\/local\\/lib\\/wx/d' makefile.unix
    sed -i 's|-I\"/usr/include\"|-I${boost}/include -I${openssl}/include -I${db48}/include|g' makefile.unix
    sed -i 's|-L\"/usr/lib\"|-L${wx29}/lib -L${boost}/lib -L${db48}/lib -L${openssl}/lib -L${glib}/lib|g' makefile.unix
    sed -i '/-L\\/usr\\/local\\/lib/d' makefile.unix
    sed -i 's/-l wx_gtk2ud-2.9/-lwx_gtk2u_xrc-2.9 -lwx_gtk2u_html-2.9 -lwx_gtk2u_richtext-2.9 -lwx_gtk2u_qa-2.9 -lwx_gtk2u_adv-2.9 -lwx_gtk2u_core-2.9 -lwx_baseu_xml-2.9 -lwx_baseu_net-2.9 -lwx_baseu-2.9/g' makefile.unix
    sed -i 's/-l wx_baseud-2.9/-l wx_baseu-2.9/g' makefile.unix
  ";

  buildPhase = "
    runHook preBuild
    mkdir -p obj obj/nogui obj/test cryptopp/obj
    sed -i 's/= htons(\\([0-9]*\\))/= __builtin_bswap16(\\1)/g; s/= htonl(\\([0-9]*\\))/= __builtin_bswap32(\\1)/g; s/= ntohs(\\([0-9]*\\))/= __builtin_bswap16(\\1)/g; s/= ntohl(\\([0-9]*\\))/= __builtin_bswap32(\\1)/g; s/htons(\\([0-9]*\\))/__builtin_bswap16(\\1)/g; s/htonl(\\([0-9]*\\))/__builtin_bswap32(\\1)/g; s/ntohs(\\([0-9]*\\))/__builtin_bswap16(\\1)/g; s/ntohl(\\([0-9]*\\))/__builtin_bswap32(\\1)/g' *.h
    sed -i 's|min(nSize - i, 1 + 4999999 / sizeof(T))|min(nSize - i, (unsigned int)(1 + 4999999 / sizeof(T)))|' serialize.h
    sed -i 's|-Wl,-Bstatic|-L${boost}/lib -L${db48}/lib -L${openssl}/lib -L${glib}/lib -L${zlib}/lib -l dl|' makefile.unix
    sed -i 's|pframeMain->GetEventHandler()->AddPendingEvent(\\([a-z0-9]*\\))|wxPostEvent(pframeMain, \\1)|g' ui.cpp
    sed -i 's|\\([a-zA-Z_][a-zA-Z_]*\\)->AddPendingEvent(\\([a-z0-9]*\\))|wxPostEvent(\\1, \\2)|g' ui.cpp
    sed -i 's|GetEventHandler()->AddPendingEvent(\\([a-z0-9]*\\))|wxPostEvent(this, \\1)|g' ui.cpp
    sed -i 's|AddPendingEvent(\\([a-z0-9]*\\))|wxPostEvent(this, \\1)|g' ui.cpp
    sed -i 's|mb_str())|mb_str().data())|g' ui.cpp
    make -f makefile.unix bitcoind CXX='${stdenv.cc}/bin/g++ -std=gnu++03 -fpermissive'
  ";

  installPhase = "
    runHook preInstall
    install -Dm755 bitcoind $out/bin/bitcoind
  ";

  meta = {
    description = "Bitcoin Core 0.2.12";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}

{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, util-linux
, boost
, libevent
, miniupnpc
, zeromq
, zlib
, sqlite
, capnproto ? null
, python3
}:

{
  pname
, description ? "Bitcoin Core-like fork"
, owner
, repo ? "bitcoin"
, coreRelease ? null
, releaseMetadata ? {}
, tag ? null
, rev ? null
, hash ? null
, enableWallet ? true
, extraNativeBuildInputs ? []
, extraBuildInputs ? []
, extraCmakeFlags ? []
, doCheck ? false
, checkInputs ? [ python3 ]
, checkFlags ? [ "LC_ALL=en_US.UTF-8" ]
, extraMeta ? {}
}:

let
  selected =
    if coreRelease == null then null
    else releaseMetadata.${coreRelease} or null;

  selectedTag =
    if selected == null then null
    else if selected ? tag then selected.tag
    else if selected ? fibreTag then selected.fibreTag
    else null;

  selectedRev =
    if selected == null then null
    else if selected ? rev then selected.rev
    else null;

  selectedHash =
    if selected == null then null
    else if selected ? hash then selected.hash
    else null;

  effectiveTag = if tag != null then tag else selectedTag;
  effectiveRev = if rev != null then rev else selectedRev;
  effectiveHash = if hash != null then hash else selectedHash;
in
assert lib.assertMsg (owner != null && owner != "") "mk-core-like-fork: `owner` is required.";
assert lib.assertMsg (pname != null && pname != "") "mk-core-like-fork: `pname` is required.";
assert lib.assertMsg (
  coreRelease == null || selected != null || (tag != null && rev != null && hash != null)
) ''
  mk-core-like-fork: missing metadata for coreRelease "${toString coreRelease}".
  Add an entry to `releaseMetadata` or provide explicit overrides: tag, rev, hash.
'';
assert lib.assertMsg (effectiveRev != null) "mk-core-like-fork: missing `rev`.";
assert lib.assertMsg (effectiveHash != null) "mk-core-like-fork: missing `hash`.";
stdenv.mkDerivation rec {
  inherit pname doCheck checkInputs checkFlags;
  version =
    if effectiveTag != null then effectiveTag
    else if coreRelease != null then "v${coreRelease}"
    else "custom";

  src = fetchFromGitHub {
    inherit owner repo;
    rev = effectiveRev;
    hash = effectiveHash;
  };

  nativeBuildInputs =
    [ cmake pkg-config ]
    ++ lib.optionals stdenv.isLinux [ util-linux ]
    ++ lib.optionals (capnproto != null) [ capnproto ]
    ++ extraNativeBuildInputs;

  buildInputs = [ boost libevent sqlite miniupnpc zeromq zlib ] ++ extraBuildInputs;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DBUILD_DAEMON=ON"
    "-DBUILD_CLI=ON"
    "-DENABLE_WALLET=${if enableWallet then "ON" else "OFF"}"
    "-DBUILD_TESTS=OFF"
    "-DBUILD_BENCH=OFF"
    "-DBUILD_FUZZ_BINARY=OFF"
    "-DSECP256K1_BUILD_TESTS=OFF"
  ] ++ extraCmakeFlags;

  enableParallelBuilding = true;

  passthru = {
    inherit coreRelease releaseMetadata effectiveTag effectiveRev effectiveHash;
  };

  meta = {
    inherit description;
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  } // extraMeta;
}

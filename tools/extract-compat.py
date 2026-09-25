#!/usr/bin/env python3
"""Per-release on-disk format fingerprints for the nix-bitcoin-core-archive.

Usage: python3 extract-compat.py <bitcoin-core-clone> [versions.txt] [compat.tsv]

The clone must contain the upstream tags for every version listed
(a full `git clone https://github.com/bitcoin/bitcoin` suffices).

Axes per version:
  engine     coin DB engine: bdb | ldb | ?
  coin_key   on-disk coin key prefix ('c' | 'C' | '-')
  obf        '1' if chainstate values are XOR-obfuscated (0.12.0+)
  coin_fp    sha1[:12] of normalized CCoins/Coin serialize bodies + CTxOutCompressor
  bidx_fp    sha1[:12] of CDiskBlockIndex serialize bodies
  btree      levelDB block-index dir ('blocks/index') or 'bdb:blocks'
  regtest    regtest genesis hash asserted in chainparams.cpp

Versions sharing a row fingerprint (engine, coin_key, obf, coin_fp,
bidx_fp, btree) are in the same on-disk format group: they can share
a data directory. The split is conservative — a fingerprint change
may still be byte-identical (e.g. VarIntMode, v0.17.0).

Source layouts (verified empirically against the tags):
  0.1.5-0.2.13  repo root (main.h, db.cpp)
  0.3.0-0.7.2   src/ (CCoins class absent until 0.8.0)
  0.8.0-0.8.6   CCoins in src/main.h, coin DB in src/txdb.cpp, blocktree in src/txdb.h
  0.9.0+        CCoins/Coin in src/coins.h, CDiskBlockIndex in src/chain.h
Serialization styles handled: plain 'void Serialize(...) const',
out-of-line 'CCoins::Serialize', SERIALIZE_METHODS, ADD_SERIALIZE_METHODS +
SerializationOp, and the legacy IMPLEMENT_SERIALIZE macro.
0.3.20.1 has no upstream tag; the archive builds v0.3.20.01_closest.
"""
import subprocess, re, hashlib, sys, os

REPO = sys.argv[1]
versions = [l.strip() for l in open(sys.argv[2]) if l.strip()]
OUT = sys.argv[3] if len(sys.argv) > 3 else "compat.tsv"

# 0.3.20.1: no upstream tag; archive builds from tag v0.3.20.01_closest
REV_OVERRIDES = {"0.3.20.1": "v0.3.20.01_closest"}

def ref(v):
    return REV_OVERRIDES.get(v, f"v{v}")

def show(v, path):
    r = subprocess.run(["git", "-C", REPO, "show", f"{ref(v)}:{path}"],
                       capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None

def exists(v, path):
    return subprocess.run(["git", "-C", REPO, "cat-file", "-e", f"{ref(v)}:{path}"],
                          capture_output=True).returncode == 0

def norm(text):
    out = []
    for line in text.splitlines():
        line = re.sub(r"//.*", "", line)
        line = line.replace('\\"', '"')
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            out.append(line)
    return "\n".join(out)

def serialize_bodies(text):
    pats = [
        r"template\s*<[^>]*>\s*(?:\w+::)?Serialize\([^)]*\)\s*const\s*\{",
        r"(?<!\w)(?:\w+::)?Serialize\([^)]*\)\s*const\s*\{",
        r"template\s*<[^>]*>\s*(?:\w+::)?Unserialize\([^)]*\)\s*\{",
        r"(?<!\w)(?:\w+::)?Unserialize\([^)]*\)\s*\{",
        r"(?<!\w)(?:\w+::)?SerializeImpl\([^)]*\)\s*\{",
        r"SERIALIZE_METHODS\([^)]*\)\s*\{",
        r"template\s*<[^>]*>\s*(?:inline\s+)?void\s+(?:\w+::)?SerializationOp\([^)]*\)\s*\{",
    ]
    chunks = []
    for pat in pats:
        for fm in re.finditer(pat, text):
            i, depth = fm.end(), 1
            while i < len(text) and depth > 0:
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                i += 1
            chunks.append(text[fm.start():i])
    # old-style: IMPLEMENT_SERIALIZE\n( ... ) — paren-matched
    for fm in re.finditer(r"IMPLEMENT_SERIALIZE\s*\(", text):
        i, depth = text.index("(", fm.end() - 1), 1
        while i < len(text) and depth > 0:
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
            i += 1
        chunks.append(text[fm.start():i])
    seen, uniq = set(), []
    for c in chunks:
        if c not in seen:
            seen.add(c)
            uniq.append(c)
    return "\n".join(uniq)

def class_body(text, name):
    """'class|struct NAME ... { ... }' — skips forward declarations."""
    for m in re.finditer(rf"(?:class|struct)\s+{name}\b(?!\s*View)", text):
        i = m.end()
        j = text.find("{", i)
        sem = text.find(";", i)
        if j != -1 and (sem == -1 or j < sem):
            depth, k = 1, j + 1
            while k < len(text) and depth > 0:
                if text[k] == "{":
                    depth += 1
                elif text[k] == "}":
                    depth -= 1
                k += 1
            return text[m.start():k]
    return ""

def fp(text):
    t = norm(text)
    return hashlib.sha1(t.encode()).hexdigest()[:12] if t.strip() else "-"

rows = []
for v in versions:
    r = {"engine": "-", "coin_key": "-", "obf": "0", "coin_fp": "-",
         "bidx_fp": "-", "btree": "-", "regtest": "-"}

    if not (exists(v, "src/coins.h") or exists(v, "src/main.h") or exists(v, "main.h")):
        rows.append([v] + [r[k] for k in ("engine","coin_key","obf","coin_fp","bidx_fp","btree","regtest")])
        continue

    txdb = show(v, "src/txdb.cpp")
    txdb_h = show(v, "src/txdb.h")
    main_h = show(v, "src/main.h") or show(v, "main.h")
    main_cpp = show(v, "src/main.cpp") or show(v, "main.cpp")
    dbcpp = show(v, "src/db.cpp") or show(v, "db.cpp")
    chainparams = show(v, "src/chainparams.cpp")

    # --- coin DB engine
    if txdb and ("CLevelDBBatch" in txdb or "CDBBatch" in txdb):
        r["engine"] = "ldb"
    elif main_cpp and "CTxDB" in main_cpp:
        r["engine"] = "bdb"
    else:
        r["engine"] = "?"

    # --- coin key prefix (first match wins; 22.0+ defines legacy DB_COINS after DB_COIN)
    for src in (txdb, show(v, "src/coins.h"), show(v, "src/chainstate/coindb.h"),
                show(v, "src/node/coinstore.cpp")):
        if not src:
            continue
        m = (re.search(r"DB_COIN\b[^;]*?['\"](?P<k>[A-Za-z])['\"]", src)
             or re.search(r"DB_COINS?\s*=\s*['\"](?P<k>[A-Za-z])['\"]", src)
             or re.search(r"make_pair\(\s*['\"](?P<k>[A-Za-z])['\"]\s*,\s*(?:txid|hash)\b", src))
        if m:
            r["coin_key"] = m.group("k")
            break
    r["obf"] = "1" if (txdb and ("CDBBatch" in txdb or "ObfuscateKey" in txdb)) else "0"

    # --- coin serialization fingerprint
    cbody = ""
    for c in ("src/coins.h", "src/main.h", "main.h"):
        text = show(v, c)
        if not text:
            continue
        for name in ("CCoins", "Coin"):
            cb = class_body(text, name)
            if cb and ("Serialize" in cb or "SerializationOp" in cb or "SERIALIZE" in cb):
                cbody = cb
                break
        if cbody:
            break
    comp = ""
    for c in ("src/compressor.h", "src/compress.h", "compressor.h", "compress.h"):
        text = show(v, c)
        if text:
            cb = class_body(text, "CTxOutCompressor")
            if cb:
                comp = cb
                break
    if cbody:
        r["coin_fp"] = fp(serialize_bodies(cbody) + comp)

    # --- block index fingerprint
    for c in ("src/chain.h", "src/main.h", "main.h", "src/txdb.cpp"):
        text = show(v, c)
        if text:
            cb = class_body(text, "CDiskBlockIndex")
            if cb:
                bodies = serialize_bodies(cb)
                if bodies:
                    r["bidx_fp"] = fp(bodies)
                    break

    # --- block tree location
    for c in ("src/txdb.h", "src/txdb.cpp", "src/main.cpp", "main.cpp",
              "src/chainstate/blockstorage.cpp", "src/node/chainstate.cpp",
              "src/node/blockstorage.cpp", "src/bitcoin-chainstate.cpp",
              "src/kernel/bitcoinkernel.cpp"):
        text = show(v, c)
        if text and re.search(r'"blocks"\s*/\s*"index"', text):
            r["btree"] = "blocks/index"
            break
    if r["engine"] == "bdb":
        r["btree"] = "bdb:blocks"
    # --- regtest genesis (asserted hash, or CreateGenesisBlock call)
    for cp in (show(v, "src/chainparams.cpp"), show(v, "src/kernel/chainparams.cpp")):
        if not cp:
            continue
        m = re.search(r"RegTest\w*Params?\b|class CRegTestParams|RegTest\(\)", cp)
        i = m.start() if m else cp.find("regtest")
        if i < 0:
            continue
        seg = cp[i:i + 8000]
        m = re.search(r"hashGenesisBlock\s*==\s*uint256\{?S?\}?\s*\(?\s*\"0x?(?P<h>[0-9a-fA-F]{64})\"", seg)
        if m:
            r["regtest"] = m.group("h")
            break
        m = re.search(r"CreateGenesisBlock\(([^;]{20,1200})\)", seg)
        if m:
            call = re.sub(r"\s+", " ", m.group(1)).strip()
            # canonical regtest genesis (identical bytes in every era)
            r["regtest"] = ("0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206"
                            if call == "1296688602, 2, 0x207fffff, 1, 50 * COIN" else call)
            break

    rows.append([v, r["engine"], r["coin_key"], r["obf"], r["coin_fp"],
                 r["bidx_fp"], r["btree"], r["regtest"]])

hdr = ["version","engine","coin_key","obf","coin_fp","bidx_fp","btree","regtest"]
with open(OUT, "w") as out:
    out.write("\t".join(hdr) + "\n")
    for row in rows:
        out.write("\t".join(str(x) for x in row) + "\n")
print(f"wrote {OUT} ({len(rows)} rows)")

# --- format groups (versions sharing the on-disk format)
gi = {h: i for i, h in enumerate(hdr)}
def key(row):
    return tuple(row[gi[c]] for c in ("engine","coin_key","obf","coin_fp","bidx_fp","btree"))
groups = []
for row in rows:
    k = key(row)
    if groups and groups[-1][0] == k:
        groups[-1][1].append(row[0])
    else:
        groups.append([k, [row[0]]])
print(f"{len(rows)} versions -> {len(groups)} format groups")
for k, vs in groups:
    print(f"  {vs[0]}..{vs[-1]}  n={len(vs)}  eng={k[0]} key={k[1]} obf={k[2]} "
          f"coin={k[3]} bidx={k[4]} btree={k[5]}")

#!/usr/bin/env bash
# Air-gap bundle mode (AIRGAP-INSTALLER D36): install.sh --bundle is the dist
# root, so the same verification runs. This covers the bundle-specific helpers:
# safe extraction (C22), locating the root, the version used for file names,
# and where a wheel is read from. The full chain is proven by release-airgap
# CI, which verifies every KMS-signed bundle with verify_release_manifest.py.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
HEAD="$(mktemp)"
trap 'rm -rf "$WORK"; rm -f "$HEAD"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

awk '/^VERSION=""/{exit} {print}' "$ROOT_DIR/install.sh" > "$HEAD"
# shellcheck source=/dev/null
source "$HEAD"
print_info() { :; }

# A bundle packed with a top-level folder, as release-airgap.yml packs it.
mkdir -p "$WORK/src/reachable-airgap-linux-x86_64/wheelhouse"
B="$WORK/src/reachable-airgap-linux-x86_64"
printf '{"schema":"reachable.release-manifest.v1","scope":"reachable-airgap-bundle","version":"1.0.0b240","artifacts":[]}' \
  > "$B/reachable-signed-manifest.json"
printf 'wheel' > "$B/wheelhouse/reachable-1.0.0b240-cp312-cp312-linux_x86_64.whl"
tar -C "$WORK/src" -czf "$WORK/good.tgz" reachable-airgap-linux-x86_64

# 1. A well-formed archive extracts, and the root is found under its folder.
mkdir "$WORK/x"
extract_bundle_archive "$WORK/good.tgz" "$WORK/x" || fail "a good bundle archive was refused"
root="$(locate_bundle_root "$WORK/x")" || fail "the bundle root was not found"
[[ "$root" == "$WORK/x/reachable-airgap-linux-x86_64" ]] || fail "wrong root: $root"

# 2. The version for file names comes from the bundle manifest.
REACHABLE_AIRGAP_BUNDLE_ROOT="$root"
[[ "$(resolve_version_from_candidate_dist)" == "1.0.0b240" ]] || fail "version not read from the bundle manifest"

# 3. Wheels are read from the wheelhouse; everything else from the root.
[[ "$(dist_artifact_source reachable-1.0.0b240-cp312-cp312-linux_x86_64.whl)" == "$root/wheelhouse/reachable-1.0.0b240-cp312-cp312-linux_x86_64.whl" ]] \
  || fail "wheel source is not the wheelhouse"
REACHABLE_DIST_ROOT="$root"
[[ "$(dist_artifact_source key-list.json)" == "$root/key-list.json" ]] || fail "key list source is not the root"

# 4. Unsafe archives are refused before anything lands (C22).
python3 - "$WORK" <<'PY'
import io, sys, tarfile, pathlib
w = pathlib.Path(sys.argv[1])
def make(name, add):
    with tarfile.open(w / name, "w:gz") as t:
        add(t)
def member(t, n, data=b"x"):
    i = tarfile.TarInfo(n); i.size = len(data); t.addfile(i, io.BytesIO(data))
make("abs.tgz", lambda t: member(t, "/etc/evil"))
make("dotdot.tgz", lambda t: member(t, "../evil"))
def link(t):
    i = tarfile.TarInfo("bundle/link"); i.type = tarfile.SYMTYPE; i.linkname = "/etc/passwd"; t.addfile(i)
make("symlink.tgz", link)
PY
for bad in abs dotdot symlink; do
  mkdir "$WORK/out-$bad"
  if extract_bundle_archive "$WORK/$bad.tgz" "$WORK/out-$bad" 2>/dev/null; then
    fail "the $bad archive was extracted"
  fi
  [[ -z "$(ls -A "$WORK/out-$bad")" ]] || fail "the $bad archive left files behind"
done
[[ ! -e /etc/evil && ! -e "$WORK/evil" ]] || fail "an unsafe member escaped"

# 5. A directory without the release-chain manifest is not a bundle.
mkdir -p "$WORK/old/wheelhouse"
printf '{}' > "$WORK/old/reachable-airgap-manifest.json"
if locate_bundle_root "$WORK/old" >/dev/null; then
  fail "a pre-D36 bundle (no reachable-signed-manifest.json) was accepted"
fi

echo "PASS: install.sh bundle mode helpers"

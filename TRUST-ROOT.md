# REACHABLE trust root


Everything REACHABLE ships is verified against one value. Pin it once:

```
kvQtc1UxbGgVbWqY9c2LJhmu1LPkiZrUToBo2rhf3/LWnMFn7UIZuI0HilEmrvIC
```

SHA-384 over the enrolled root public keys, base64. The roots sign
`key-list.json`, which names the per-release signing keys, the pinned
transparency-log keys and any revocations; those keys sign the release
manifest, which binds every artifact by SHA-384.

So rotating a signing key, adding a log or revoking a key is a key-list
version and changes nothing you pinned. **This value changes only if the root
set itself changes** — a changed fingerprint is never routine, and should be
treated as a compromise until proven otherwise.

### Check it against a second source

First-use trust rests on comparing two sources obtained independently. Any two
of these that agree is a real check; one on its own is not:

- https://sthenosec.com/trust
- `ROOT-FINGERPRINT.txt` in github.com/sthenos-security/reach-dist
- `ROOT-FINGERPRINT.txt` in github.com/sthenos-security/reachable-agent-plugin-installer
- `dig +short TXT _reachable-root.sthenosec.com`
- `scripts/root-fingerprint.txt` inside any REACHABLE plugin package
- `python -c "from reachable.artifacts.root_trust import ROOT_FINGERPRINT as f; print(f)"`
- the product documentation

If two disagree, **do not install.** One of those sources is compromised, and
which one is not something any of them can tell you.

### Enrolled roots

| role | holder | protection |
|---|---|---|
| `root-ecdsa-p384` | YubiKey 37610824 (5C Nano), PIV slot 9C | non-exportable |
| `root-ecdsa-p384` | YubiKey 37505073 (5C NFC), PIV slot 9C | non-exportable |
| `root-mldsa-87` | offline encrypted file (FIPS 204, ML-DSA-87) | passphrase |

The key-list policy is `all_of[root-ecdsa-p384, root-mldsa-87]`, so a P-384
token **and** the ML-DSA root must both sign. Two P-384 tokens exist because a
non-exportable key cannot be backed up: the second token is the backup, and
either satisfies that half of the policy.

---
name: gen-ssh-key
description: 'Generate SSH keys per team standards and return the public key. Ed25519 by default, RSA 4096 as fallback (RSA 2048 is never allowed). Prefers puttygen (produces .ppk/.pem/.pub); falls back to ssh-keygen (private key + .pub) when puttygen is absent. Filenames are prefixed with the service name/purpose; the private key is chmod 600. Use for: "generate ssh key", "generate ssh public/private key", "create an ssh keypair", "make a login key for service xxx". Generated keys default to the current directory (or the directory set in .env); what to do next (import into a platform / append to authorized_keys) is left to the caller.'
tags: [ssh, keygen, ed25519, rsa, puttygen, security]
---

# Generate SSH Keys (Team Standard)

One command produces a standards-compliant SSH key. Pure bash; depends on puttygen or ssh-keygen.

## Team Rules (baked into the script)

- Key type: **Ed25519** by default; `--rsa` uses **RSA 4096**; **RSA 2048 is never generated**.
- Tool: prefers **puttygen** (produces `.ppk/.pem/.pub`); falls back to **ssh-keygen** (private key + `.pub`, no `.ppk`) when puttygen is absent.
- Filename: `<name>.ppk / .pem / .pub`, where `<name>` = service name/purpose.
- Comment `-C`: defaults to `<name>`.
- Passphrase: none by default, with a strong reminder; `--passphrase-file` encrypts the key.
- Overwrite: existing keys with the same name are refused by default; use `--force`.
- Permissions: private key is `chmod 600`.

## Configuration

Output directory precedence: `--out-dir` > `SSH_KEY_OUTPUT_DIR` in `.env` (at the skill root, one level above `scripts/`) > current directory.
When neither `--out-dir` nor `SSH_KEY_OUTPUT_DIR` is set, keys land in the current directory and a notice is printed to stderr.
For first use, `cp .env.example .env` at the skill root and point it at a central directory (e.g. `~/.ssh/team-keys`).

## Usage

```bash
./scripts/gen-ssh-key.sh jumpserver                       # Ed25519 -> jumpserver.{ppk,pem,pub}
./scripts/gen-ssh-key.sh jumpserver --rsa                 # RSA 4096
./scripts/gen-ssh-key.sh jumpserver --comment "you@example.com"
./scripts/gen-ssh-key.sh jumpserver --passphrase-file ./pp.txt   # encrypt the private key
./scripts/gen-ssh-key.sh jumpserver --out-dir ~/.ssh/team-keys
./scripts/gen-ssh-key.sh jumpserver --force               # overwrite same-name keys
./scripts/gen-ssh-key.sh jumpserver --json                # machine-readable output (pure JSON on stdout)
./scripts/gen-ssh-key.sh jumpserver --dry-run             # show the plan only
./scripts/gen-ssh-key.sh jumpserver -v                    # verbose diagnostics on stderr
./scripts/gen-ssh-key.sh --tool ssh-keygen jumpserver     # force ssh-keygen (skip puttygen)
./scripts/gen-ssh-key.sh -h                               # help
```

## Artifacts

| File | Purpose |
|------|---------|
| `<name>.ppk` | PuTTY-native key (puttygen path only) |
| `<name>.pem` | OpenSSH private key (chmod 600, keep secret) |
| `<name>.pub` | OpenSSH public key (copy to import / append to authorized_keys) |

## Exit Codes

`0` success; `1` bad argument / target already exists / generation failed (the underlying tool's own non-zero code when it errors); `2` no usable tool (neither puttygen nor ssh-keygen found).

## Self-test

```bash
bash test.sh
```

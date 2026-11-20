# AGENTS.md — SSOT (Joe's Personal Command Center)

Bash/Zsh dual-shell repo, no CI. Multi-env: `TERMUX` · `MUMU` · `OPPO` · `WSL` · `WSL2` · `GIT-BASH` · `ACODEX` · `USERLAND`.
Canonical per-file rules: [.github/instructions/bash-standards.instructions.md](.github/instructions/bash-standards.instructions.md).
Node/SSH workflows: `.github/skills/ssot-node-onboard/`, `.github/skills/mesh-repair/`.

## Directory Layout

- `install.sh` / `bootstrap/install.sh` — Single one-command installer for fresh devices.
- `joe.sh` — Main runtime entry point (loaded once per RC init).
- `profiles/<device>/{.bashrc,.zshrc}` — Thin device wrappers delegating shared startup logic to `profiles/_common/{bashrc.sh,zshrc.sh}`.
- `core/` — Core engine (`runtime/{helper.sh,checker.sh,zsh-compat.sh}`, `01-colors.sh`, `00-env.sh`, `aliases.sh`, `loader.sh`, `profiles.sh`, `node-mesh.sh`, `ssh-config.sh`, `ssh_toolkit.sh`, `3worlds.sh`).
- `modules/` — Auto-sourced feature modules grouped by category (`system/`, `dev/`, `file-manager/`, `personal/`). Note: `modules/file-manager/bash-manager.sh` is lazy-loaded by `00-fm-loader.sh`.
- `bin/` — Standalone executable CLI tools (`dashboard.sh`, `env-manager.sh`, `mesh-sync.sh`, `dist-tui.sh`), symlinked into `~/.local/bin/`.
- `plugins/` — Bundled `ez_colors/` (guarantees V3 colors work on fresh clones) and `joe_theme/`.
- `bootstrap/` — `nodes/` (`*.node.env`, `loader.sh`, `node-register.sh`, `node-status.sh`, `pubkey-corrector.sh`), `vault/` (`ssot-vault.sh`, `secret-setup.sh`, `.env.enc`, `pubkeys.enc`), `scripts/` (`mesh-regen.sh`, `ssh_audit.sh`, `tailscale-separate.sh`), `templates/env`.

## Load Order (never reorder)

`profiles/<device>/.bashrc|.zshrc` → `profiles/_common/bashrc.sh|zshrc.sh` → (`core/runtime/zsh-compat.zsh` on zsh) → `core/runtime/helper.sh` → `~/.local/bin/env` (`~/.env` + `~/.env.secret`) → `joe.sh` → `ssot_load()`:
`core/01-colors.sh` → `core/00-env.sh` → `core/ssh-config.sh` → `core/ssh_toolkit.sh` → `core/3worlds.sh` → `core/aliases.sh` → `core/profiles.sh` → `core/loader.sh` → `plugins/joe_theme/plugin.sh` → `modules/system/*.sh` → `modules/dev/*.sh` → `modules/file-manager/*.sh` (except `bash-manager.sh`) → `modules/personal/*.sh` → any custom `modules/<subdir>/*.sh`.

## Verify (run these, no CI)

```bash
bash -n <file>                                                # required after every edit
grep -cE '\\033\[|\\e\[' <file>                               # must be 0 (except core/01-colors.sh & plugins/ez_colors/)
bash bootstrap/scripts/mesh-regen.sh [--localhost-wsl]        # regen ~/.ssh/config mesh block only (safe)
bash bootstrap/scripts/ssh_audit.sh [--fix|--test]            # SSH audit (--fix rewrites ~/.ssh/config)
node-status [--ssh|--json|--this|<name>]                      # node health
bash install.sh <device>                                      # fresh-device onboard
node-register --auto [<name>]                                 # (re-)register this device as node member
vault status | pubkey-fix | pubkey-sync                       # secret audit | repair authorized_keys | install vault keys
```

## Rules

- **Colors:** only `c`/`cn`/`color`/`rc`/`rc1`/`rc2`/`ctab`/`hline` from [core/01-colors.sh](core/01-colors.sh) (backed by bundled `plugins/ez_colors/`). Never hardcode `\033[`, `\e[38;5` outside `core/01-colors.sh` and `plugins/ez_colors/`.
- **Standalone scripts:** preamble `set -uo pipefail`, never `set -e`. Never `source joe.sh` fully — mirror the `JOE_ENV` path setup from `joe.sh`/`ssh_audit.sh`. Init output to stderr only (p10k-safe).
- **Ports:** `wsl=2222`, `wsl2=2223`, `termux=8022`, `mumu=8020`, `oppo=8023`, `redmi=8024`, `acodex=8021`, `window=22`. Read from `NODE_*_PORT` / `SSH_*_PORT`, never hardcode.
- **Secrets:** never commit `~/.env` or `~/.env.secret` (gitignored, `600`). Template = `.env.example`. Encrypted = `bootstrap/vault/.env.enc` (+ `bootstrap/vault/pubkeys.enc`) via `vault`.

# Project Mango Setup

## New VPS Setup

Simple Debian 13 LTS cloud-init based setup script:

- Copy & Paste the following: [`debian-cloud-init-desktop.yaml`](debian-cloud-init-desktop.yaml)

### Setup Shortcuts Manually With Copy-Paste

```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/debian-cloud-init-desktop-shortcuts.sh | sudo bash
```

## Codex/Claude Code Setup

Simple Ubuntu 24.04 LTS / Debian 13 LTS setup scripts for both Claude Code and Codex:

- Codex via [`Layer2Setup/codex_setup.sh`](Layer2Setup/codex_setup.sh)
- Claude Code via [`Layer2Setup/ccode-setup.sh`](Layer2Setup/ccode-setup.sh)

### Codex

```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/codex_setup.sh | sudo bash
```
in case the codex_setup.sh does not auto starts the next phase..
also can be used to manage Codex 3P APIs ANYTIME.
```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/codex-3papi-setup.sh | sudo bash
```

### Claude Code

```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/ccode-setup.sh | bash
```


## What the scripts do

- Update and upgrade the system
- Install required packages and dependencies
- Install either Claude Code or Codex CLI
- Optionally guide API or provider configuration

## Notes

- Claude Code setup is designed to run as your normal user and will ask for `sudo` when needed
- Codex setup currently expects `root` or `sudo`

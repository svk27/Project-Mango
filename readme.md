# Project Mango Setup

Simple Ubuntu 24.04 LTS setup scripts for both Claude Code and Codex:

- Codex via [`Layer2Setup/codex_setup.sh`](Layer2Setup/codex_setup.sh)
- Claude Code via [`Layer2Setup/ccode-setup.sh`](Layer2Setup/ccode-setup.sh)

## Run from GitHub Raw

### Codex

```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/codex_setup.sh | sudo bash
```
```bash
# in case the codex_setup.sh does not auto starts the next phase..
# also can be used to manage Codex 3P APIs ANYTIME.
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

# Codex CLI Setup

This repository includes an interactive Ubuntu 24.04 LTS setup script for Codex CLI at `Layer2Setup/codex-setup.sh`.

## Quick Install

Download the script from GitHub and run it on the target VPS:

```bash
curl -fsSL -o codex-setup.sh https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/codex-setup.sh && chmod +x codex-setup.sh && ./codex-setup.sh
```

## What the script does

- Updates and upgrades the system
- Installs required dependencies for Codex CLI
- Installs Codex CLI
- Interactively configures `~/.codex/config.toml`
- Exports and persists the provider API key
- Runs a websocket debug verification with:

```bash
RUST_LOG=debug codex exec "Reply with OK only."
```

## Interactive prompts included

The script asks for:

- Model selection: `gpt-5.4` or `gpt-5.3-codex`
- Reasoning effort: `medium`, `high`, or `xhigh`
- Provider identifier
- Provider display name
- Provider `base_url`
- Provider API key

## Existing Codex setup handling

If Codex CLI is already installed and `~/.codex/config.toml` already contains a `model_provider = "..."` entry, the script shows the current line and offers to open the file in `nano` for manual editing. If accepted, `nano` opens and the script exits.

## Notes

- Intended for a fresh Ubuntu 24.04 LTS VPS
- Uses `sudo` for package installation
- Saves websocket debug output under `~/.codex/logs/`
- Server-side `codex-lb` log inspection is still required for full websocket validation

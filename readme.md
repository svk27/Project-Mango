# Claude Code CLI Setup

Simple installer for Ubuntu 24.04 LTS using [`Layer2Setup/ccode-setup.sh`](Layer2Setup/ccode-setup.sh).

## Run from GitHub Raw

```bash
curl -fsSL https://raw.githubusercontent.com/svk27/Project-Mango/refs/heads/main/Layer2Setup/ccode-setup.sh | bash
```

## What it does

- Updates and upgrades the system
- Installs required packages
- Installs the Claude Code CLI
- Optionally configures a third-party API provider

## Notes

- Run it as your normal user, not as root
- The script will ask for `sudo` when needed
- Internet access is required

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="codex-setup.sh"
CONFIG_DIR="$HOME/.codex"
CONFIG_FILE="$CONFIG_DIR/config.toml"
LOG_DIR="$HOME/.codex/logs"
REQUIRED_UBUNTU_VERSION="24.04"

print_divider() {
  printf '\n%s\n' "============================================================"
}

print_step() {
  print_divider
  printf '%s\n' "$1"
  print_divider
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

confirm() {
  local prompt="$1"
  local answer

  while true; do
    read -r -p "$prompt [y/n]: " answer
    case "${answer,,}" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
      *)
        printf '%s\n' "Please answer y or n."
        ;;
    esac
  done
}

choose_option() {
  local prompt="$1"
  shift
  local options=("$@")
  local i choice

  printf '%s\n' "$prompt"
  for i in "${!options[@]}"; do
    printf '  %s) %s\n' "$((i + 1))" "${options[$i]}"
  done

  while true; do
    read -r -p "Enter choice [1-${#options[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      printf '%s' "${options[$((choice - 1))]}"
      return 0
    fi
    printf '%s\n' "Invalid choice. Try again."
  done
}

read_required() {
  local prompt="$1"
  local value

  while true; do
    read -r -p "$prompt: " value
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    printf '%s\n' "This value is required."
  done
}

read_secret_required() {
  local prompt="$1"
  local value

  while true; do
    read -r -s -p "$prompt: " value
    printf '\n'
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
    printf '%s\n' "This value is required."
  done
}

toml_escape() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  printf '%s' "$input"
}

validate_provider_id() {
  local provider_id="$1"
  [[ "$provider_id" =~ ^[A-Za-z0-9_-]+$ ]]
}

check_platform() {
  print_step "Checking platform"

  if [[ ! -f /etc/os-release ]]; then
    printf '%s\n' "Unable to identify the operating system because /etc/os-release was not found."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release

  printf 'Detected OS: %s %s\n' "${NAME:-Unknown}" "${VERSION_ID:-Unknown}"

  if [[ "${ID:-}" != "ubuntu" ]]; then
    printf '%s\n' "This script is intended for Ubuntu systems."
    if ! confirm "Continue anyway"; then
      exit 1
    fi
    return 0
  fi

  if [[ "${VERSION_ID:-}" != "$REQUIRED_UBUNTU_VERSION" ]]; then
    printf 'Expected Ubuntu %s but found Ubuntu %s.\n' "$REQUIRED_UBUNTU_VERSION" "${VERSION_ID:-unknown}"
    if ! confirm "Continue anyway"; then
      exit 1
    fi
  fi
}

handle_existing_codex_config() {
  if ! command_exists codex; then
    return 0
  fi

  print_step "Detected existing Codex CLI installation"
  codex --version || true

  if [[ -f "$CONFIG_FILE" ]]; then
    local current_provider_line
    current_provider_line="$(grep -nE '^[[:space:]]*model_provider[[:space:]]*=' "$CONFIG_FILE" || true)"

    if [[ -n "$current_provider_line" ]]; then
      printf '%s\n' "Existing model provider configuration found in $CONFIG_FILE:"
      printf '%s\n' "$current_provider_line"
      printf '%s\n' "If you choose to edit it now, the script will open nano and then exit."

      if confirm "Open $CONFIG_FILE in nano now"; then
        nano "$CONFIG_FILE"
        printf '%s\n' "Nano was opened for manual configuration. Exiting $SCRIPT_NAME."
        exit 0
      fi
    fi
  fi
}

collect_inputs() {
  print_step "Collecting Codex provider settings"

  MODEL="$(choose_option "Choose the default Codex model" "gpt-5.4" "gpt-5.3-codex")"
  printf 'Selected model: %s\n' "$MODEL"

  MODEL_REASONING_EFFORT="$(choose_option "Choose the reasoning effort" "medium" "high" "xhigh")"
  printf 'Selected reasoning effort: %s\n' "$MODEL_REASONING_EFFORT"

  while true; do
    PROVIDER_ID="$(read_required "Enter the provider identifier (no spaces; letters, numbers, _ and - only)")"
    if validate_provider_id "$PROVIDER_ID"; then
      break
    fi
    printf '%s\n' "Invalid provider identifier. Use only letters, numbers, underscore, and hyphen."
  done

  PROVIDER_NAME="$(read_required "Enter the provider display name (example: OpenAI)")"
  BASE_URL="$(read_required "Enter the provider base_url")"
  API_KEY="$(read_secret_required "Enter the provider API key")"

  ENV_KEY="$(printf '%s' "$PROVIDER_ID" | tr '[:lower:]-' '[:upper:]_' )_API_KEY"

  print_step "Configuration summary"
  printf 'model = %s\n' "$MODEL"
  printf 'model_reasoning_effort = %s\n' "$MODEL_REASONING_EFFORT"
  printf 'model_provider = %s\n' "$PROVIDER_ID"
  printf 'provider name = %s\n' "$PROVIDER_NAME"
  printf 'base_url = %s\n' "$BASE_URL"
  printf 'env_key = %s\n' "$ENV_KEY"

  if ! confirm "Continue with these values"; then
    printf '%s\n' "Setup cancelled by user."
    exit 1
  fi
}

update_and_upgrade_system() {
  print_step "Updating and upgrading Ubuntu packages"
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

install_dependencies() {
  print_step "Installing required dependencies for Codex CLI"
  sudo apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    libssl-dev \
    nano \
    pkg-config \
    tar \
    unzip \
    xz-utils
}

install_nodejs_if_needed() {
  local install_node="false"

  if command_exists node; then
    printf 'Detected Node.js version: %s\n' "$(node --version)"
  else
    install_node="true"
  fi

  if command_exists npm; then
    printf 'Detected npm version: %s\n' "$(npm --version)"
  else
    install_node="true"
  fi

  if [[ "$install_node" == "true" ]]; then
    print_step "Installing Node.js 22.x and npm"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
  fi
}

install_codex_cli() {
  print_step "Installing Codex CLI"

  if command_exists codex; then
    printf 'Codex CLI already installed: %s\n' "$(codex --version || printf 'version unavailable')"
    return 0
  fi

  sudo npm install -g @openai/codex
  printf 'Installed Codex CLI version: %s\n' "$(codex --version || printf 'version unavailable')"
}

backup_existing_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    local backup_file
    backup_file="$CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    printf 'Backed up existing config to %s\n' "$backup_file"
  fi
}

write_codex_config() {
  print_step "Writing Codex configuration"
  mkdir -p "$CONFIG_DIR"
  backup_existing_config

  local escaped_model escaped_reasoning escaped_provider_id escaped_provider_name escaped_base_url escaped_env_key
  escaped_model="$(toml_escape "$MODEL")"
  escaped_reasoning="$(toml_escape "$MODEL_REASONING_EFFORT")"
  escaped_provider_id="$(toml_escape "$PROVIDER_ID")"
  escaped_provider_name="$(toml_escape "$PROVIDER_NAME")"
  escaped_base_url="$(toml_escape "$BASE_URL")"
  escaped_env_key="$(toml_escape "$ENV_KEY")"

  cat > "$CONFIG_FILE" <<EOF
model = "$escaped_model"
model_reasoning_effort = "$escaped_reasoning"
model_provider = "$escaped_provider_id"

[model_providers.$escaped_provider_id]
name = "$escaped_provider_name"
base_url = "$escaped_base_url"
wire_api = "responses"
env_key = "$escaped_env_key"
supports_websockets = true
requires_openai_auth = true
EOF

  printf 'Wrote %s\n' "$CONFIG_FILE"
}

persist_api_key() {
  print_step "Exporting API key"
  export "$ENV_KEY=$API_KEY"

  local bash_escaped_api_key profile_file
  printf -v bash_escaped_api_key '%q' "$API_KEY"

  for profile_file in "$HOME/.bashrc" "$HOME/.profile"; do
    touch "$profile_file"
    sed -i "/^export ${ENV_KEY}=.*/d" "$profile_file"
    printf 'export %s=%s\n' "$ENV_KEY" "$bash_escaped_api_key" >> "$profile_file"
    printf 'Saved export to %s\n' "$profile_file"
  done

  printf 'Current shell export applied: export %s="***hidden***"\n' "$ENV_KEY"
}

verify_websocket_transport() {
  print_step "Running one-off websocket verification"
  mkdir -p "$LOG_DIR"

  local log_file
  log_file="$LOG_DIR/websocket-check-$(date +%Y%m%d%H%M%S).log"

  printf '%s\n' "Running: RUST_LOG=debug codex exec \"Reply with OK only.\""
  printf '%s\n' "Debug log will be saved to: $log_file"

  set +e
  timeout 120s bash -lc 'RUST_LOG=debug codex exec "Reply with OK only."' 2>&1 | tee "$log_file"
  local cmd_status=${PIPESTATUS[0]}
  set -e

  if [[ $cmd_status -eq 124 ]]; then
    printf '%s\n' "The verification command timed out after 120 seconds. Review the log file above."
  elif [[ $cmd_status -ne 0 ]]; then
    printf 'The verification command exited with status %s. Review the log file above.\n' "$cmd_status"
  fi

  local websocket_connecting websocket_connected fallback_post
  websocket_connecting="false"
  websocket_connected="false"
  fallback_post="false"

  if grep -qi 'connecting to websocket' "$log_file"; then
    websocket_connecting="true"
  fi

  if grep -qi 'successfully connected to websocket' "$log_file"; then
    websocket_connected="true"
  fi

  if grep -qiE 'fallback.*POST /backend-api/codex/responses|POST /backend-api/codex/responses' "$log_file"; then
    fallback_post="true"
  fi

  print_step "Websocket verification result"
  printf 'connecting to websocket found: %s\n' "$websocket_connecting"
  printf 'successfully connected to websocket found: %s\n' "$websocket_connected"
  printf 'fallback POST /backend-api/codex/responses found in CLI log: %s\n' "$fallback_post"

  if [[ "$websocket_connecting" == "true" && "$websocket_connected" == "true" && "$fallback_post" == "false" ]]; then
    printf '%s\n' "Local Codex CLI websocket indicators look healthy."
  else
    printf '%s\n' "Local Codex CLI websocket indicators need review."
  fi

  printf '\nManual server-side checks to complete:\n'
  printf '  - Inspect your codex-lb logs for WebSocket /backend-api/codex/responses\n'
  printf '  - Confirm there is no fallback POST /backend-api/codex/responses for the same run\n'
  printf '  - Keep the saved log at %s for troubleshooting\n' "$log_file"
}

main() {
  check_platform
  handle_existing_codex_config
  collect_inputs
  update_and_upgrade_system
  install_dependencies
  install_nodejs_if_needed
  install_codex_cli
  write_codex_config
  persist_api_key
  verify_websocket_transport

  print_step "Setup complete"
  printf '%s\n' "Codex CLI has been installed and configured."
  printf 'Config file: %s\n' "$CONFIG_FILE"
  printf 'Provider env key: %s\n' "$ENV_KEY"
  printf '%s\n' "Open a new shell session or run: source ~/.bashrc"
}

main "$@"

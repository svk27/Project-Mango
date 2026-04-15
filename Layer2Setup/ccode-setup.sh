#!/bin/bash

# ==============================================================================
# Claude Code CLI - Ubuntu 24.04 LTS Setup & Configuration Script
# ==============================================================================

# Define colors for friendly UI
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure we're not running as root directly (we will use sudo when needed)
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}Please do not run this script as root. Run it as your normal user.${NC}"
  echo -e "The script will automatically request 'sudo' privileges when required."
  exit 1
fi

# Utility functions for UI
print_stage() { echo -e "\n${BLUE}====================================================${NC}"; echo -e "${BLUE}▶ ${YELLOW}$1${NC}"; echo -e "${BLUE}====================================================${NC}"; }
print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗ Error:${NC} $1"; }

# Helper to read input even when the script is piped via `curl ... | bash`
prompt_input() {
    local message="$1"
    local var_name="$2"
    local default_val="$3"
    local input
    if [ -n "$default_val" ]; then
        read -p "$(echo -e "${YELLOW}❓ $message [${default_val}]: ${NC}")" input < /dev/tty
        input=${input:-$default_val}
    else
        read -p "$(echo -e "${YELLOW}❓ $message: ${NC}")" input < /dev/tty
    fi
    eval $var_name=\"\$input\"
}

prompt_yes_no() {
    local message="$1"
    local var_name="$2"
    local input
    read -p "$(echo -e "${YELLOW}❓ $message [Y/n]: ${NC}")" input < /dev/tty
    input=${input:-Y}
    if [[ "$input" =~ ^[Yy]$ ]]; then
        eval $var_name="true"
    else
        eval $var_name="false"
    fi
}

echo -e "${GREEN}"
echo "   ____ _                 _         ____ _     ___   ____       _               "
echo "  / ___| | __ _ _   _  __| | ___   / ___| |   |_ _| / ___|  ___| |_ _   _ _ __  "
echo " | |   | |/ _\` | | | |/ _\` |/ _ \ | |   | |    | |  \___ \ / _ \ __| | | | '_ \ "
echo " | |___| | (_| | |_| | (_| |  __/ | |___| |___ | |   ___) |  __/ |_| |_| | |_) |"
echo "  \____|_|\__,_|\__,_|\__,_|\___|  \____|_____|___| |____/ \___|\__|\__,_| .__/ "
echo "                                                                         |_|    "
echo -e "${NC}Welcome! Let's get your Ubuntu 24.04 ready for the Claude Code CLI.\n"

# ------------------------------------------------------------------------------
# STAGE 1: Update & Upgrade
# ------------------------------------------------------------------------------
print_stage "Stage 1: Updating and Upgrading System"
print_step "Running apt update..."
sudo apt-get update -y
print_step "Running apt upgrade (this might take a moment)..."
sudo apt-get upgrade -y
print_success "System is fully updated!"

# ------------------------------------------------------------------------------
# STAGE 2: Install Dependencies
# ------------------------------------------------------------------------------
print_stage "Stage 2: Installing Dependencies"
print_step "Installing curl, wget, jq, and build-essential..."
sudo apt-get install -y curl wget jq build-essential software-properties-common git unzip
print_success "Dependencies installed successfully!"

# ------------------------------------------------------------------------------
# STAGE 3: Install Claude Code CLI
# ------------------------------------------------------------------------------
print_stage "Stage 3: Installing Claude Code CLI"
print_step "Running the official Anthropic native installation script..."
curl -fsSL https://claude.ai/install.sh | bash
if [ $? -eq 0 ]; then
    print_success "Claude Code CLI installed successfully!"
else
    print_error "Failed to install Claude Code CLI. Please check your internet connection."
    exit 1
fi

# ------------------------------------------------------------------------------
# STAGE 4: 3rd Party API Provider Setup
# ------------------------------------------------------------------------------
print_stage "Stage 4: Configuration & 3rd Party API Setup"
prompt_yes_no "Do you want to configure a 3rd Party API Provider? (Ollama, LM Studio, vLLM, etc.)" USE_CUSTOM_API

if [ "$USE_CUSTOM_API" = "true" ]; then
    echo ""
    print_step "Let's configure your custom API settings."
    prompt_input "Enter your Auth Token (e.g., 'lmstudio', 'ollama', or 'sk-xxx')" AUTH_TOKEN "ollama"
    
    # Strip any trailing slashes from the base URL to prevent "//models" issues
    prompt_input "Enter your API Base URL (e.g., http://localhost:11434/v1)" BASE_URL "http://localhost:11434/v1"
    BASE_URL="${BASE_URL%/}" 

    # --------------------------------------------------------------------------
    # STAGE 5: Fetch Models and Map Equivalents
    # --------------------------------------------------------------------------
    print_stage "Stage 5: Fetching Models & Mapping Equivalents"
    print_step "Connecting to ${BASE_URL}/models..."
    
    MODELS_JSON=$(curl -s -H "Authorization: Bearer $AUTH_TOKEN" "${BASE_URL}/models")
    CURL_STATUS=$?

    if [ $CURL_STATUS -ne 0 ] || [ -z "$MODELS_JSON" ]; then
        print_error "Failed to reach the API endpoint. Will fallback to manual entry."
        FETCHED=false
    else
        # Try to parse standard OpenAI schema: { "data": [ { "id": "model-name" } ] }
        # Or direct array: [ { "id": "model-name" } ]
        MODEL_LIST=$(echo "$MODELS_JSON" | jq -r 'if type == "object" and has("data") then .data[].id elif type == "array" then .[].id else empty end' 2>/dev/null)
        
        if [ -n "$MODEL_LIST" ]; then
            FETCHED=true
            mapfile -t MODELS_ARRAY <<< "$MODEL_LIST"
            
            echo -e "\n${GREEN}Successfully fetched ${#MODELS_ARRAY[@]} models:${NC}"
            for i in "${!MODELS_ARRAY[@]}"; do
                echo -e "  $((i+1))) ${YELLOW}${MODELS_ARRAY[$i]}${NC}"
            done
            echo ""
            
            # Helper to map numerical selection
            get_model_choice() {
                local target=$1
                local choice
                while true; do
                    prompt_input "Enter the NUMBER corresponding to the $target equivalent model" choice ""
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#MODELS_ARRAY[@]}" ]; then
                        echo "${MODELS_ARRAY[$((choice-1))]}"
                        break
                    else
                        echo -e "${RED}Invalid selection. Please enter a valid number.${NC}"
                    fi
                done
            }

            HAIKU_MODEL=$(get_model_choice "HAIKU")
            SONNET_MODEL=$(get_model_choice "SONNET")
            OPUS_MODEL=$(get_model_choice "OPUS")
            
        else
            print_error "Could not parse JSON models payload correctly. Falling back to manual entry."
            FETCHED=false
        fi
    fi

    # Fallback if curl or parsing failed
    if [ "$FETCHED" = "false" ]; then
        echo -e "\nPlease enter your target model names manually:"
        prompt_input "Enter HAIKU equivalent model name" HAIKU_MODEL "qwen2.5-coder:latest"
        prompt_input "Enter SONNET equivalent model name" SONNET_MODEL "qwen2.5-coder:latest"
        prompt_input "Enter OPUS equivalent model name" OPUS_MODEL "qwen2.5-coder:latest"
    fi

    # --------------------------------------------------------------------------
    # STAGE 6: Apply Configuration to ~/.claude/settings.json
    # --------------------------------------------------------------------------
    print_stage "Stage 6: Saving Configuration"
    
    CLAUDE_DIR="$HOME/.claude"
    CONFIG_FILE="$CLAUDE_DIR/settings.json"
    
    print_step "Ensuring $CLAUDE_DIR directory exists..."
    mkdir -p "$CLAUDE_DIR"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "{}" > "$CONFIG_FILE"
    fi

    print_step "Writing configuration to $CONFIG_FILE..."
    
    # Use jq to cleanly merge/inject the "env" object while preserving other settings
    jq --arg token "$AUTH_TOKEN" \
       --arg url "$BASE_URL" \
       --arg haiku "$HAIKU_MODEL" \
       --arg sonnet "$SONNET_MODEL" \
       --arg opus "$OPUS_MODEL" \
       '.env = (.env // {}) + {
           "ANTHROPIC_AUTH_TOKEN": $token,
           "ANTHROPIC_BASE_URL": $url,
           "ANTHROPIC_DEFAULT_HAIKU_MODEL": $haiku,
           "ANTHROPIC_DEFAULT_SONNET_MODEL": $sonnet,
           "ANTHROPIC_DEFAULT_OPUS_MODEL": $opus
       }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

    print_success "Settings successfully saved!"
    
else
    print_step "Skipping 3rd Party API Provider Setup."
fi

print_stage "Setup Complete!"
echo -e "${GREEN}Claude Code CLI is installed and ready to go!${NC}"
if [ "$USE_CUSTOM_API" = "true" ]; then
    echo -e "Your local/custom API models have been configured in ${YELLOW}~/.claude/settings.json${NC}."
    echo -e "You can now run ${BLUE}claude${NC} in any project directory to start coding."
else
    echo -e "Run ${BLUE}claude${NC} in any project directory to authenticate and start coding."
fi
echo ""
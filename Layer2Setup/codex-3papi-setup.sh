#!/usr/bin/env bash

# Exit on unexpected errors
set -e

# Override 'read' to always read from /dev/tty.
# This prevents the script from instantly skipping prompts and exiting 
# when it is executed via a pipe (e.g., curl ... | bash).
read() {
    command read "$@" < /dev/tty
}

# ==========================================
# UI Helpers & Colors
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${CYAN}             Codex CLI - 3rd Party API Configuration            ${NC}"
    echo -e "${BLUE}================================================================${NC}\n"
}

print_success() { echo -e "${GREEN}✔ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✖ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

# ==========================================
# Environment & Dependency Checks
# ==========================================

# 1. Check for jq and python3 (required for JSON parsing and TOML management)
if ! command -v jq &> /dev/null; then
    print_warning "jq is missing. Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not installed. Please install Python 3."
    exit 1
fi

# 2. Check for Codex CLI and fix PATH if needed
check_codex_installation() {
    print_info "Checking Codex CLI installation..."
    if command -v codex &> /dev/null; then
        print_success "Codex CLI found in PATH."
        return 0
    fi

    print_warning "Codex CLI not found in current PATH. Searching common directories..."
    
    POSSIBLE_PATHS=(
        "$HOME/.npm-global/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/opt/node/bin"
        "$HOME/.nvm/versions/node/$(node -v 2>/dev/null)/bin"
    )
    
    FOUND=0
    for p in "${POSSIBLE_PATHS[@]}"; do
        if [ -x "$p/codex" ]; then
            export PATH="$p:$PATH"
            if ! grep -q "export PATH=\"$p:\$PATH\"" "$HOME/.bashrc"; then
                echo "export PATH=\"$p:\$PATH\"" >> "$HOME/.bashrc"
            fi
            print_success "Found Codex at $p/codex. PATH temporarily updated."
            print_info "(PATH was also appended to ~/.bashrc for future sessions)"
            FOUND=1
            break
        fi
    done
    
    if [ $FOUND -eq 0 ]; then
        print_error "Codex CLI could not be found anywhere."
        echo -e "Please ensure you have installed it using: ${YELLOW}npm install -g @openai/codex${NC}"
        exit 1
    fi
}

check_codex_installation

# ==========================================
# Python TOML Manager Setup & Cleanup Trap
# ==========================================
PYTHON_HELPER="/tmp/codex_toml_helper.py"

cleanup_on_exit() {
    rm -f "$PYTHON_HELPER"
    echo -e "\n${YELLOW}================================================================${NC}"
    echo -e "${CYAN} IMPORTANT: To apply any API key changes to your current session,${NC}"
    echo -e "${CYAN} please run the following command now:${NC}"
    echo -e "${GREEN} source ~/.bashrc${NC}"
    echo -e "${YELLOW}================================================================${NC}\n"
}

# This trap ensures the message and cleanup happen on ANY exit (normal or Ctrl+C)
trap cleanup_on_exit EXIT

cat << 'EOF' > "$PYTHON_HELPER"
import sys, json, os

try:
    import tomllib
except ImportError:
    print(json.dumps({"error": "Python 3.11+ is required for native tomllib."}))
    sys.exit(1)

CONFIG_PATH = os.path.expanduser("~/.codex/config.toml")

def load_config():
    if not os.path.exists(CONFIG_PATH):
        return {"model_providers": {}, "profiles": {}}
    with open(CONFIG_PATH, "rb") as f:
        try:
            data = tomllib.load(f)
            
            # Migration: convert old Array of Tables `[[model_providers]]` to Nested Tables `[model_providers.id]`
            if isinstance(data.get("model_providers"), list):
                new_mp = {}
                for item in data["model_providers"]:
                    if "id" in item:
                        pid = item.pop("id")
                        new_mp[pid] = item
                data["model_providers"] = new_mp
                
            if isinstance(data.get("profiles"), list):
                new_prof = {}
                for item in data["profiles"]:
                    if "id" in item:
                        pid = item.pop("id")
                        new_prof[pid] = item
                data["profiles"] = new_prof
                
            if "model_providers" not in data: data["model_providers"] = {}
            if "profiles" not in data: data["profiles"] = {}
            return data
        except Exception:
            return {"model_providers": {}, "profiles": {}}

def save_config(data):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, "w") as f:
        # Write Model Providers
        for pid, pdata in data.get("model_providers", {}).items():
            f.write(f"[model_providers.{pid}]\n")
            for k, v in pdata.items():
                f.write(f'{k} = "{v}"\n')
            f.write("\n")
            
        # Write Profiles
        for pid, pdata in data.get("profiles", {}).items():
            f.write(f"[profiles.{pid}]\n")
            for k, v in pdata.items():
                f.write(f'{k} = "{v}"\n')
            f.write("\n")

if len(sys.argv) < 2: sys.exit(1)
cmd = sys.argv[1]
data = load_config()

if cmd == "get_providers":
    out = []
    for k, v in data.get("model_providers", {}).items():
        v["id"] = k
        out.append(v)
    print(json.dumps(out))
elif cmd == "get_profiles":
    out = []
    for k, v in data.get("profiles", {}).items():
        v["id"] = k
        out.append(v)
    print(json.dumps(out))
elif cmd == "add_provider":
    new_p = json.loads(sys.argv[2])
    pid = new_p.pop("id")
    data["model_providers"][pid] = new_p
    save_config(data)
elif cmd == "update_provider":
    pid, updates = sys.argv[2], json.loads(sys.argv[3])
    if pid in data.get("model_providers", {}):
        data["model_providers"][pid].update(updates)
    save_config(data)
elif cmd == "add_profile":
    new_p = json.loads(sys.argv[2])
    pid = new_p.pop("id")
    data["profiles"][pid] = new_p
    save_config(data)
elif cmd == "update_profile":
    pid, updates = sys.argv[2], json.loads(sys.argv[3])
    if pid in data.get("profiles", {}):
        data["profiles"][pid].update(updates)
    save_config(data)
EOF

# ==========================================
# Application Logic Functions
# ==========================================

ensure_v1_url() {
    local url="$1"
    if [[ ! "$url" =~ /v1/?$ ]]; then
        if [[ "$url" == */ ]]; then
            url="${url}v1"
        else
            url="${url}/v1"
        fi
        print_info "Auto-corrected Base URL to end with /v1 -> $url"
    fi
    echo "$url"
}

fetch_models() {
    local base_url="$1"
    local env_key="$2"
    local actual_key=""

    # 1. Check if it's a valid bash variable name (to avoid the bad substitution error)
    if [[ "$env_key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        actual_key="${!env_key}"
    fi

    # 2. If it wasn't a valid variable or was empty, see if they passed the raw API Key
    if [ -z "$actual_key" ]; then
        if [[ "$env_key" == sk-* ]] || [[ ! "$env_key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            actual_key="$env_key" # They entered the raw key directly
        else
            print_warning "Environment variable $env_key is not currently set."
            read -s -p "Enter your API key temporarily just to fetch the model list (it won't be saved): " temp_key
            echo
            actual_key="$temp_key"
        fi
    fi

    print_info "Attempting to fetch models from $base_url/models..."
    
    local response
    response=$(curl -s --max-time 10 -H "Authorization: Bearer $actual_key" "$base_url/models" 2>/dev/null || echo "")
    
    local count
    count=$(echo "$response" | jq '.data | length' 2>/dev/null || echo 0)

    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}Successfully retrieved models!${NC}"
        echo "$response" | jq -r '.data[].id'
    else
        print_error "Failed to retrieve models automatically."
    fi
}

save_api_key_securely() {
    local key_name="$1"
    local raw_key="$2"
    
    if [ -n "$raw_key" ]; then
        # Remove old key if it exists to avoid duplicating lines
        sed -i "/export ${key_name}=/d" ~/.bashrc
        
        # Append new key
        echo "export ${key_name}=\"${raw_key}\"" >> ~/.bashrc
        
        # Export for current session execution
        export "${key_name}=${raw_key}"
        print_success "API Key securely saved to ~/.bashrc (Env: $key_name)"
    fi
}

# --- MODEL PROVIDER FLOWS ---

add_provider() {
    print_header
    echo -e "${MAGENTA}--- Add New Model Provider ---${NC}\n"
    
    read -p "ID (e.g. sambanova): " p_id
    
    # Auto-generate Env Key (replace hyphens with underscores for bash compatibility)
    p_env=$(echo "${p_id}_api" | sed 's/-/_/g')
    print_info "Auto-generated Environment Key Name: $p_env"
    
    read -p "Name (e.g. SambaNova): " p_name
    read -p "Base URL (e.g. https://api.sambanova.ai/v1): " p_url
    p_url=$(ensure_v1_url "$p_url")
    
    read -s -p "Enter actual API Key for $p_name: " raw_api_key
    echo
    
    save_api_key_securely "$p_env" "$raw_api_key"
    
    local json_data
    json_data=$(jq -n --arg id "$p_id" --arg name "$p_name" --arg url "$p_url" --arg env "$p_env" \
        '{id: $id, name: $name, base_url: $url, env_key: $env}')
    
    python3 "$PYTHON_HELPER" add_provider "$json_data"
    print_success "Model Provider '$p_id' added successfully!"
    sleep 2
}

edit_provider() {
    print_header
    echo -e "${MAGENTA}--- Edit Existing Model Provider ---${NC}\n"
    
    local providers=$(python3 "$PYTHON_HELPER" get_providers)
    local len=$(echo "$providers" | jq '. | length')
    
    if [ "$len" -eq 0 ]; then 
        print_warning "No model providers found. Add one first."
        sleep 2
        return
    fi
    
    for i in $(seq 0 $((len-1))); do
        local name=$(echo "$providers" | jq -r ".[$i].name")
        local id=$(echo "$providers" | jq -r ".[$i].id")
        echo "$((i+1))) $name ($id)"
    done
    echo "0) Cancel"
    
    read -p "Select a provider to edit: " sel
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -eq 0 ] || [ "$sel" -gt "$len" ]; then return; fi
    
    local idx=$((sel-1))
    local target_id=$(echo "$providers" | jq -r ".[$idx].id")
    local old_name=$(echo "$providers" | jq -r ".[$idx].name")
    local old_url=$(echo "$providers" | jq -r ".[$idx].base_url")
    local old_env=$(echo "$providers" | jq -r ".[$idx].env_key")
    
    echo -e "\n${CYAN}Leave fields blank to keep current values.${NC}"
    
    read -p "Name [$old_name]: " new_name
    new_name=${new_name:-$old_name}
    
    read -p "Base URL [$old_url]: " new_url
    new_url=${new_url:-$old_url}
    if [ "$new_url" != "$old_url" ]; then
        new_url=$(ensure_v1_url "$new_url")
    fi
    
    # Auto-generate / enforce naming convention for env_key during edits as well
    new_env=$(echo "${target_id}_api" | sed 's/-/_/g')
    
    read -s -p "New API Key [Leave blank to keep existing key]: " raw_api_key
    echo
    
    if [ -n "$raw_api_key" ]; then
        save_api_key_securely "$new_env" "$raw_api_key"
    fi
    
    local json_data
    json_data=$(jq -n --arg name "$new_name" --arg url "$new_url" --arg env "$new_env" \
        '{name: $name, base_url: $url, env_key: $env}')
    
    python3 "$PYTHON_HELPER" update_provider "$target_id" "$json_data"
    print_success "Model Provider updated successfully!"
    sleep 2
}

# --- PROFILE FLOWS ---

add_profile() {
    print_header
    echo -e "${MAGENTA}--- Add New Profile ---${NC}\n"
    
    local providers=$(python3 "$PYTHON_HELPER" get_providers)
    local len=$(echo "$providers" | jq '. | length')
    
    if [ "$len" -eq 0 ]; then 
        print_error "You must add a Model Provider before creating a Profile."
        sleep 2
        return
    fi
    
    read -p "Profile ID (e.g. my_coder): " prof_id
    echo -e "\n${CYAN}Select Model Provider for this profile:${NC}"
    
    for i in $(seq 0 $((len-1))); do
        local name=$(echo "$providers" | jq -r ".[$i].name")
        local p_id=$(echo "$providers" | jq -r ".[$i].id")
        echo "$((i+1))) $name ($p_id)"
    done
    
    read -p "Selection: " prov_sel
    if [[ ! "$prov_sel" =~ ^[0-9]+$ ]] || [ "$prov_sel" -le 0 ] || [ "$prov_sel" -gt "$len" ]; then
        print_error "Invalid selection."
        sleep 2
        return
    fi

    local idx=$((prov_sel-1))
    local prov_id=$(echo "$providers" | jq -r ".[$idx].id")
    local prov_url=$(echo "$providers" | jq -r ".[$idx].base_url")
    local prov_env=$(echo "$providers" | jq -r ".[$idx].env_key")
    
    echo -e "\n${CYAN}Fetching models for Provider: $prov_id${NC}"
    local models_list=$(fetch_models "$prov_url" "$prov_env")
    
    echo -e "\n$models_list\n"
    echo -e "${YELLOW}Hint: Copy a model name from above or type your own if fetch failed.${NC}"
    read -p "Enter Model Name: " model_name
    
    local json_data
    json_data=$(jq -n --arg id "$prof_id" --arg p "$prov_id" --arg m "$model_name" \
        '{id: $id, model_provider: $p, model: $m}')
    
    python3 "$PYTHON_HELPER" add_profile "$json_data"
    print_success "Profile '$prof_id' created successfully!"
    sleep 2
}

edit_profile() {
    print_header
    echo -e "${MAGENTA}--- Edit Existing Profile ---${NC}\n"
    
    local profiles=$(python3 "$PYTHON_HELPER" get_profiles)
    local len=$(echo "$profiles" | jq '. | length')
    
    if [ "$len" -eq 0 ]; then 
        print_warning "No profiles found. Add one first."
        sleep 2
        return
    fi
    
    for i in $(seq 0 $((len-1))); do
        local id=$(echo "$profiles" | jq -r ".[$i].id")
        local p_prov=$(echo "$profiles" | jq -r ".[$i].model_provider")
        echo "$((i+1))) $id (Provider: $p_prov)"
    done
    echo "0) Cancel"
    
    read -p "Select a profile to edit: " sel
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -eq 0 ] || [ "$sel" -gt "$len" ]; then return; fi
    
    local idx=$((sel-1))
    local target_id=$(echo "$profiles" | jq -r ".[$idx].id")
    local old_prov=$(echo "$profiles" | jq -r ".[$idx].model_provider")
    local old_model=$(echo "$profiles" | jq -r ".[$idx].model")
    
    echo -e "\n${CYAN}Leave fields blank to keep current values.${NC}"
    echo -e "Current Provider: ${YELLOW}$old_prov${NC}"
    
    local providers=$(python3 "$PYTHON_HELPER" get_providers)
    local p_len=$(echo "$providers" | jq '. | length')
    for i in $(seq 0 $((p_len-1))); do
        local p_id=$(echo "$providers" | jq -r ".[$i].id")
        echo "  - $p_id"
    done
    read -p "New Provider ID (or enter to keep): " new_prov
    new_prov=${new_prov:-$old_prov}
    
    echo -e "\nCurrent Model: ${YELLOW}$old_model${NC}"
    read -p "Do you want to fetch the model list from Provider '$new_prov'? [y/N]: " fetch_m
    if [[ "$fetch_m" =~ ^[Yy]$ ]]; then
        local p_url=$(echo "$providers" | jq -r ".[] | select(.id==\"$new_prov\") | .base_url")
        local p_env=$(echo "$providers" | jq -r ".[] | select(.id==\"$new_prov\") | .env_key")
        if [ -n "$p_url" ] && [ "$p_url" != "null" ]; then
             local models_list=$(fetch_models "$p_url" "$p_env")
             echo -e "\n$models_list\n"
        else
             print_error "Provider '$new_prov' not found in config."
        fi
    fi
    
    read -p "New Model Name (or enter to keep): " new_model
    new_model=${new_model:-$old_model}
    
    local json_data
    json_data=$(jq -n --arg p "$new_prov" --arg m "$new_model" \
        '{model_provider: $p, model: $m}')
    
    python3 "$PYTHON_HELPER" update_profile "$target_id" "$json_data"
    print_success "Profile updated successfully!"
    sleep 2
}

# ==========================================
# Main Menus
# ==========================================

menu_providers() {
    while true; do
        print_header
        echo -e "${MAGENTA}--- Manage Model Providers ---${NC}"
        echo "1) Add a Provider"
        echo "2) Edit a Provider"
        echo "3) Back to Main Menu"
        read -p "Select an option: " opt
        case $opt in
            1) add_provider ;;
            2) edit_provider ;;
            3) break ;;
            *) print_warning "Invalid option" ; sleep 1 ;;
        esac
    done
}

menu_profiles() {
    while true; do
        print_header
        echo -e "${MAGENTA}--- Manage Profiles ---${NC}"
        echo "1) Add a Profile"
        echo "2) Edit a Profile"
        echo "3) Back to Main Menu"
        read -p "Select an option: " opt
        case $opt in
            1) add_profile ;;
            2) edit_profile ;;
            3) break ;;
            *) print_warning "Invalid option" ; sleep 1 ;;
        esac
    done
}

# Entry Point
while true; do
    print_header
    echo -e "${MAGENTA}--- Main Menu ---${NC}"
    echo "1) Manage Model Providers (URLs, API Keys)"
    echo "2) Manage Profiles (Model Selection)"
    echo "3) Exit"
    read -p "Select an option: " main_opt
    case $main_opt in
        1) menu_providers ;;
        2) menu_profiles ;;
        3) 
            print_success "Setup complete. Configuration saved to ~/.codex/config.toml"
            exit 0 
            ;;
        *) 
            print_warning "Invalid option" ; sleep 1 
            ;;
    esac
done
#!/bin/bash

# automate_ai.sh
# Creates Home Assistant automations from natural language commands using Gemini.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# --- Helper Functions ---

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
}

check_dependencies() {
  local missing=0
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      log "ERROR: Required command '$cmd' is not installed. Please install it."
      missing=1
    fi
  done
  [ "$missing" -eq 0 ]
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Configuration file not found. Please copy 'config.sh.example' to 'config.sh' and fill in your details."
    return 1
  fi
  # shellcheck source=config.sh
  source "$CONFIG_FILE"
  if [ -z "$GEMINI_API_KEY" ] || [ "$GEMINI_API_KEY" == "YOUR_GEMINI_API_KEY" ] || \
     [ -z "$AUTOMATIONS_YAML" ] || [ "$AUTOMATIONS_YAML" == "/path/to/your/automations.yaml" ]; then
    log "ERROR: GEMINI_API_KEY or AUTOMATIONS_YAML is not set correctly in $CONFIG_FILE."
    return 1
  fi
}

# --- Core Functions ---

# @param {string} prompt_template_file The path to the prompt template.
# @param {string} user_command The user's command.
# @returns {string} The raw text response from the API.
call_gemini_api() {
  local prompt_template_file="$1"
  local user_command="$2"
  
  local prompt_template
  if ! prompt_template=$(cat "$prompt_template_file"); then
    log "ERROR: Could not read prompt template file at '$prompt_template_file'."
    exit 1
  fi

  local prompt="${prompt_template//\{USER_COMMAND\}/$user_command}"

  # Preferred model (can be overridden)
  local MODEL="gemini-1.5-flash-latest"

  # List available models for this API key
  local list_url="https://generativelanguage.googleapis.com/v1/models?key=$GEMINI_API_KEY"
  local list_resp
  list_resp=$(curl -sS "$list_url" 2>/dev/null) || {
    log "ERROR: Failed to list available models from Gemini API."
    log "Hint: check GEMINI_API_KEY and network connectivity."
    exit 1
  }

  # Try to find the requested model in the returned list
  if ! echo "$list_resp" | jq -e --arg m "$MODEL" '.models[]?.name | select(contains($m))' >/dev/null 2>&1; then
    log "WARN: Requested model '$MODEL' not found or not available for this key. Attempting automatic selection..."
    # Pick the first reasonable 'gemini' model from the list
    local candidate
    candidate=$(echo "$list_resp" | jq -r '.models[]?.name' | grep -Ei 'gemini-1\.5|gemini-1\.0|gemini' | head -n1 || true)
    if [ -n "$candidate" ]; then
      log "INFO: Using available model: $candidate"
      # candidate is like "models/gemini-1.5-flash"; use full path in API URL
      local model_path="$candidate"
      local api_url="https://generativelanguage.googleapis.com/v1/${model_path}:generateContent?key=$GEMINI_API_KEY"
      local json_payload
      json_payload=$(jq -n --arg prompt "$prompt" '{ "contents": [ { "parts": [ { "text": $prompt } ] } ] }')

      local response_body
      if ! response_body=$(curl -sS -X POST -H "Content-Type: application/json" -d "$json_payload" "$api_url"); then
        log "ERROR: Failed to connect to Gemini API."
        exit 1
      fi

      local generated_text
      generated_text=$(echo "$response_body" | jq -r '.candidates[0].content.parts[0].text // ""')

      if [ -z "$generated_text" ]; then
        log "ERROR: Received an empty or invalid response from the Gemini API."
        log "Response: $response_body"
        exit 1
      fi

      echo "$generated_text"
      return 0
    else
      log "ERROR: No suitable Gemini model found for this API key."
      log "INFO: Available models (first 40):"
      echo "$list_resp" | jq -r '.models[]?.name' | sed -n '1,40p'
      log "INFO: Set MODEL to one of the names above (or update your API key/permissions)."
      exit 1
    fi
  fi

  # If requested model is present, call it using the short MODEL name
  local api_url="https://generativelanguage.googleapis.com/v1/models/$MODEL:generateContent?key=$GEMINI_API_KEY"
  local json_payload
  json_payload=$(jq -n --arg prompt "$prompt" '{ "contents": [ { "parts": [ { "text": $prompt } ] } ] }')

  local response_body
  if ! response_body=$(curl -sS -X POST -H "Content-Type: application/json" -d "$json_payload" "$api_url"); then
    log "ERROR: Failed to connect to Gemini API."
    exit 1
  fi

  local generated_text
  generated_text=$(echo "$response_body" | jq -r '.candidates[0].content.parts[0].text // ""')

  if [ -z "$generated_text" ]; then
    log "ERROR: Received an empty or invalid response from the Gemini API."
    log "Response: $response_body"
    exit 1
  fi

  echo "$generated_text"
}

validate_yaml() {
  local yaml_content="$1"
  if ! command -v yamllint &>/dev/null; then
    log "INFO: 'yamllint' not found. Skipping YAML validation."
    return 0
  fi
  local tmp_file
  tmp_file=$(mktemp)
  trap 'rm -f "$tmp_file"' EXIT
  echo "$yaml_content" >"$tmp_file"
  
  # Run yamllint and capture both output and exit code
  local yamllint_output
  local yamllint_exit_code
  yamllint_output=$(yamllint "$tmp_file" 2>&1)
  yamllint_exit_code=$?
  
  # Filter out document-start warnings but preserve other output
  local filtered_output
  filtered_output=$(echo "$yamllint_output" | grep -v "document-start" || true)
  
  # If there's any remaining output after filtering, show it
  if [ -n "$filtered_output" ]; then
    echo "$filtered_output"
  fi
  
  # Check if yamllint succeeded (exit code 0) or only had document-start warnings
  if [ "$yamllint_exit_code" -eq 0 ] || [ -z "$filtered_output" ]; then
    log "SUCCESS: Generated YAML syntax is valid."
    return 0
  else
    log "ERROR: Generated YAML has syntax errors."
    return 1
  fi
}

append_to_automations() {
  local yaml_output="$1"
  if [ ! -f "$AUTOMATIONS_YAML" ]; then
    log "ERROR: Automations file not found at '$AUTOMATIONS_YAML'."
    return 1
  fi
  # Clean the YAML output and add a single newline before the automation
  local cleaned_yaml
  cleaned_yaml=$(echo "$yaml_output" | sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d')
  echo -e "\n$cleaned_yaml" >>"$AUTOMATIONS_YAML"
  log "SUCCESS: Automation appended to $AUTOMATIONS_YAML."
}

reload_ha_automations() {
  if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ] || [ "$HA_URL" == "http://your-home-assistant.local:8123" ]; then
    log "INFO: HA_URL or HA_TOKEN not configured. Skipping automation reload."
    return 0
  fi
  local reload_url="$HA_URL/api/services/automation/reload"
  log "INFO: Reloading Home Assistant automations..."
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$reload_url")
  if [ "$status_code" -eq 200 ]; then
    log "SUCCESS: Home Assistant automations reloaded successfully."
  else
    log "ERROR: Failed to reload automations. Status: $status_code"
    return 1
  fi
}

# --- Main Execution ---
main() {
  check_dependencies
  load_config

  local user_command
  
  # Check if a command was provided as a parameter
  if [ $# -gt 0 ]; then
    user_command="$*"
    log "INFO: Using command line parameter: $user_command"
  else
    echo "Please enter your automation command:"
    read -r user_command
  fi

  if [ -z "$user_command" ]; then
    log "INFO: No command entered. Exiting."
    exit 0
  fi

  # Step 1: Detect Intent
  log "INFO: Detecting user intent..."
  local intent_prompt="$SCRIPT_DIR/prompts/intent_detection_prompt.txt"
  local automation_type
  automation_type=$(call_gemini_api "$intent_prompt" "$user_command")
  log "INFO: Detected intent: $automation_type"

  local temporary_mode=false
  local prompt_to_use="$SCRIPT_DIR/prompts/automation_prompt.txt"

  # Step 2: Automatic Temporary Mode Detection
  if [[ "$automation_type" == "TEMPORARY" ]]; then
    log "INFO: Detected temporary automation intent. Creating temporary automation."
    temporary_mode=true
    prompt_to_use="$SCRIPT_DIR/prompts/temporary_automation_prompt.txt"
  fi

  # Step 3: Generate YAML
  log "INFO: Generating automation YAML..."
  local yaml_output
  yaml_output=$(call_gemini_api "$prompt_to_use" "$user_command")
  
  yaml_output=$(echo "$yaml_output" | sed -e 's/^```yaml//' -e 's/^```//' -e '/^```$/d')
  
  local timestamp
  timestamp=$(date +%s%3N)
  yaml_output=$(echo "$yaml_output" | sed "s|TIMESTAMP_PLACEHOLDER|$timestamp|g")
  
  # Clean up common YAML formatting issues
  yaml_output=$(echo "$yaml_output" | sed -e 's/,\([^ ]\)/, \1/g' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d')

  if [[ "$yaml_output" == "AMBIGUOUS" ]]; then
    log "ERROR: The command was ambiguous. Please be more specific."
    exit 1
  fi

  log "INFO: Received YAML from Gemini:"
  echo "---"
  echo "$yaml_output"
  echo "---"

  if validate_yaml "$yaml_output"; then
    if append_to_automations "$yaml_output"; then
      reload_ha_automations
      if [ "$temporary_mode" = true ]; then
        log "INFO: Temporary automation created. The automation will trigger its own deletion upon completion."
      fi
    fi
  else
    log "ERROR: Aborting due to YAML syntax errors."
    exit 1
  fi

  log "INFO: Process completed successfully."
}

main "$@"
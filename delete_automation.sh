#!/bin/bash

# delete_automation.sh
# Finds and deletes a specific automation by its ID from the automations.yaml file.
# This script is intended to be called via SSH from Home Assistant.

set -e

# --- Configuration & Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Log a message to a dedicated log file for the deletion script.
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >>"$SCRIPT_DIR/delete_automation.log"
}

# Load configuration from the main config file.
load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Configuration file not found at $CONFIG_FILE."
    exit 1
  fi
  # shellcheck source=config.sh
  source "$CONFIG_FILE"
}

# Delete automation via Home Assistant REST API
delete_automation_via_api() {
  local automation_id="$1"
  
  if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
    log "INFO: HA_URL or HA_TOKEN not configured. Skipping API deletion."
    return 0
  fi
  
  # Try the newer API endpoint first
  local delete_url="$HA_URL/api/config/automation/config/$automation_id"
  log "INFO: Deleting automation '$automation_id' via REST API..."
  
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$delete_url")
  
  if [ "$status_code" -eq 200 ]; then
    log "SUCCESS: Automation '$automation_id' deleted via REST API."
    return 0
  else
    # Try the older API endpoint as fallback
    local old_delete_url="$HA_URL/api/config/automation/$automation_id"
    log "INFO: Trying alternative API endpoint..."
    status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$old_delete_url")
    
    if [ "$status_code" -eq 200 ]; then
      log "SUCCESS: Automation '$automation_id' deleted via REST API (fallback endpoint)."
      return 0
    else
      log "WARNING: Failed to delete automation via API. Status: $status_code. Falling back to YAML removal."
      return 1
    fi
  fi
}

# Reload Home Assistant automations via the API.
reload_ha_automations() {
  if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
    log "INFO: HA_URL or HA_TOKEN not configured. Skipping reload."
    return 0
  fi
  local reload_url="$HA_URL/api/services/automation/reload"
  log "INFO: Reloading Home Assistant automations..."
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$reload_url")
  if [ "$status_code" -eq 200 ]; then
    log "SUCCESS: Home Assistant automations reloaded."
  else
    log "ERROR: Failed to reload automations. Status: $status_code"
    return 1
  fi
}

# Remove automation from YAML file (fallback method)
remove_from_yaml() {
  local automation_id="$1"
  
  if [ ! -f "$AUTOMATIONS_YAML" ]; then
    log "ERROR: Automations file not found at '$AUTOMATIONS_YAML'."
    return 1
  fi

  # Use awk to find the block with the matching ID and delete it.
  local temp_file
  temp_file=$(mktemp)
  # This awk script treats each automation (starting with "- id:") as a separate record.
  # It prints every record that does NOT contain the target ID.
  awk -v id="'$automation_id'" '
    BEGIN { RS = "\n- id:" }
    $0 !~ id {
      if (NR > 1) {
        printf "\n- id:%s", $0
      } else if ($0 != "") {
        printf "%s", $0
      }
    }
  ' "$AUTOMATIONS_YAML" > "$temp_file"

  # Verify the temp file is not empty before overwriting
  if [ ! -s "$temp_file" ] && [ -s "$AUTOMATIONS_YAML" ]; then
      log "WARNING: Temporary file is empty after processing. This could mean all automations were deleted or the target was the only one. Proceeding cautiously."
  fi

  # Replace the original file with the modified content
  mv "$temp_file" "$AUTOMATIONS_YAML"
  log "SUCCESS: Removed automation with ID '$automation_id' from $AUTOMATIONS_YAML."
}

# --- Main Execution ---
main() {
  log "---"
  log "INFO: Deletion script triggered via SSH."
  load_config

  # The automation ID is passed as the first argument from the SSH command.
  local automation_id="$1"

  if [ -z "$automation_id" ]; then
    log "ERROR: No automation ID provided."
    exit 1
  fi

  log "INFO: Received automation ID to delete: $automation_id"

  # Try to delete via REST API first (preferred method)
  if delete_automation_via_api "$automation_id"; then
    log "INFO: Automation deleted successfully via REST API."
  else
    # Fallback to YAML removal and reload
    log "INFO: Using fallback method - removing from YAML and reloading."
    remove_from_yaml "$automation_id"
    reload_ha_automations
  fi
  
  log "INFO: Deletion process complete."
}

# Pass the first command-line argument to main
main "$1"
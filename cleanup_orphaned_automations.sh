#!/bin/bash

# cleanup_orphaned_automations.sh
# Removes automations from Home Assistant that are no longer in the YAML file.
# This helps clean up automations that appear greyed out in the UI.

set -e

# --- Configuration & Setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Configuration file not found at $CONFIG_FILE."
    exit 1
  fi
  # shellcheck source=config.sh
  source "$CONFIG_FILE"
}

# Get list of automation IDs from YAML file
get_yaml_automation_ids() {
  if [ ! -f "$AUTOMATIONS_YAML" ]; then
    log "ERROR: Automations file not found at '$AUTOMATIONS_YAML'."
    return 1
  fi
  
  # Extract automation IDs from YAML file
  grep "^[[:space:]]*- id:" "$AUTOMATIONS_YAML" | sed "s/.*id:[[:space:]]*'//" | sed "s/'.*//"
}

# Get list of automation IDs from Home Assistant API
get_ha_automation_ids() {
  if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
    log "ERROR: HA_URL or HA_TOKEN not configured."
    return 1
  fi
  
  # Try the newer API endpoint first
  local list_url="$HA_URL/api/config/automation/config"
  local response
  response=$(curl -s -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$list_url")
  
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to get automation list from Home Assistant."
    return 1
  fi
  
  # Extract automation IDs from JSON response
  local ids
  ids=$(echo "$response" | jq -r '.[] | .id // empty' 2>/dev/null)
  
  if [ $? -ne 0 ] || [ -z "$ids" ]; then
    # Try the older API endpoint as fallback
    log "INFO: Trying alternative API endpoint for automation list..."
    local old_list_url="$HA_URL/api/config/automation"
    response=$(curl -s -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$old_list_url")
    
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to get automation list from Home Assistant (fallback endpoint)."
      return 1
    fi
    
    ids=$(echo "$response" | jq -r '.[] | .id // empty' 2>/dev/null)
    if [ $? -ne 0 ]; then
      log "ERROR: Failed to parse automation list response."
      return 1
    fi
  fi
  
  echo "$ids"
}

# Delete automation via Home Assistant REST API
delete_automation_via_api() {
  local automation_id="$1"
  
  # Try the newer API endpoint first
  local delete_url="$HA_URL/api/config/automation/config/$automation_id"
  log "INFO: Deleting orphaned automation '$automation_id' via REST API..."
  
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$delete_url")
  
  if [ "$status_code" -eq 200 ]; then
    log "SUCCESS: Orphaned automation '$automation_id' deleted."
    return 0
  else
    # Try the older API endpoint as fallback
    local old_delete_url="$HA_URL/api/config/automation/$automation_id"
    log "INFO: Trying alternative API endpoint..."
    status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$old_delete_url")
    
    if [ "$status_code" -eq 200 ]; then
      log "SUCCESS: Orphaned automation '$automation_id' deleted (fallback endpoint)."
      return 0
    else
      log "ERROR: Failed to delete automation '$automation_id'. Status: $status_code"
      return 1
    fi
  fi
}

main() {
  log "INFO: Starting cleanup of orphaned automations..."
  load_config
  
  # Check dependencies
  if ! command -v jq &>/dev/null; then
    log "ERROR: 'jq' is required but not installed."
    exit 1
  fi
  
  # Get automation IDs from YAML
  log "INFO: Reading automation IDs from YAML file..."
  local yaml_ids
  yaml_ids=$(get_yaml_automation_ids)
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to read automation IDs from YAML."
    exit 1
  fi
  
  # Get automation IDs from Home Assistant
  log "INFO: Reading automation IDs from Home Assistant..."
  local ha_ids
  ha_ids=$(get_ha_automation_ids)
  if [ $? -ne 0 ]; then
    log "ERROR: Failed to read automation IDs from Home Assistant."
    exit 1
  fi
  
  # Find orphaned automations (in HA but not in YAML)
  local orphaned_count=0
  local deleted_count=0
  
  while IFS= read -r ha_id; do
    if [ -n "$ha_id" ]; then
      # Check if this automation ID exists in YAML
      if ! echo "$yaml_ids" | grep -q "^$ha_id$"; then
        log "INFO: Found orphaned automation: $ha_id"
        orphaned_count=$((orphaned_count + 1))
        
        # Ask for confirmation before deleting
        read -p "Delete orphaned automation '$ha_id'? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          if delete_automation_via_api "$ha_id"; then
            deleted_count=$((deleted_count + 1))
          fi
        else
          log "INFO: Skipped deletion of automation '$ha_id'"
        fi
      fi
    fi
  done <<< "$ha_ids"
  
  if [ "$orphaned_count" -eq 0 ]; then
    log "SUCCESS: No orphaned automations found."
  else
    log "SUCCESS: Cleanup complete. Found $orphaned_count orphaned automations, deleted $deleted_count."
  fi
}

main "$@"

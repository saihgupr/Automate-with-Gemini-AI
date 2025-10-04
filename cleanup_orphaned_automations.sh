#!/bin/bash

# cleanup_orphaned_automations.sh
# Removes automations from Home Assistant that are no longer in the YAML file.
# This helps clean up automations that appear greyed out in the Home Assistant UI.

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

  # Prefer /api/automations (returns entity_id/id/unique_id depending on HA version)
  local url="$HA_URL/api/automations"
  local response
  response=$(curl -s -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$url") || true

  # If empty, fall back to config endpoints
  if [ -z "$response" ] || [ "$response" = "null" ]; then
    log "INFO: /api/automations returned empty, trying /api/config/automation/config ..."
    url="$HA_URL/api/config/automation/config"
    response=$(curl -s -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$url") || true
  fi

  if [ -z "$response" ] || [ "$response" = "null" ]; then
    log "ERROR: No automation list returned from HA."
    return 1
  fi

  # Emit tab-separated lines: id<TAB>entity_id<TAB>unique_id<TAB>alias (any can be empty)
  echo "$response" | jq -r '.[] | [(.id // ""), (.entity_id // ""), (.unique_id // ""), (.alias // "")] | @tsv' 2>/dev/null || true
}

# Reload Home Assistant automations via the API.
reload_ha_automations() {
  if [ -z "$HA_URL" ] || [ -z "$HA_TOKEN" ]; then
    log "INFO: HA_URL or HA_TOKEN not configured. Skipping automation reload."
    return 0
  fi
  local reload_url="$HA_URL/api/services/automation/reload"
  log "INFO: Reloading Home Assistant automations..."
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X POST -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$reload_url")
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 204 ]; then
    log "SUCCESS: Home Assistant automations reloaded."
    return 0
  else
    log "ERROR: Failed to reload automations. Status: $status_code"
    return 1
  fi
}

# Delete automation via Home Assistant REST API
delete_automation_via_api() {
  local automation_id="$1"
  
  # Try the newer API endpoint first
  local delete_url="$HA_URL/api/config/automation/config/$automation_id"
  log "INFO: Deleting orphaned automation '$automation_id' via REST API..."
  
  local status_code
  status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$delete_url")
  
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 204 ]; then
    log "SUCCESS: Orphaned automation '$automation_id' deleted."
    reload_ha_automations
    return 0
  else
    # Try the older API endpoint as fallback
    local old_delete_url="$HA_URL/api/config/automation/$automation_id"
    log "INFO: Trying alternative API endpoint..."
    status_code=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$old_delete_url")
    
    if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 204 ]; then
      log "SUCCESS: Orphaned automation '$automation_id' deleted (fallback endpoint)."
      reload_ha_automations
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

  if ! command -v jq &>/dev/null; then
    log "ERROR: 'jq' is required but not installed."
    exit 1
  fi

  log "INFO: Reading automation IDs from YAML file..."
  mapfile -t yaml_ids < <(grep "^[[:space:]]*- id:" "$AUTOMATIONS_YAML" 2>/dev/null | sed "s/.*id:[[:space:]]*'//" | sed "s/'.*//" || true)

  log "INFO: Reading automation records from Home Assistant..."
  mapfile -t ha_lines < <(get_ha_automation_ids)
  if [ "${#ha_lines[@]}" -eq 0 ]; then
    log "ERROR: Failed to read automation list from Home Assistant."
    exit 1
  fi

  local orphaned_count=0 deleted_count=0

  for line in "${ha_lines[@]}"; do
    IFS=$'\t' read -r ha_id ha_entity ha_unique ha_alias <<< "$line"
    # Skip records that match any YAML id
    match=false
    for y in "${yaml_ids[@]}"; do
      if [ -n "$y" ] && { [ "$y" = "$ha_id" ] || [ "$y" = "$ha_unique" ] || [ "$y" = "$ha_entity" ]; }; then
        match=true
        break
      fi
    done

    if [ "$match" = false ]; then
      orphaned_count=$((orphaned_count+1))
      log "INFO: Orphaned automation found — id='$ha_id' entity_id='$ha_entity' unique_id='$ha_unique' alias='$ha_alias'"

      read -p "Delete orphaned automation (id='$ha_id' entity_id='$ha_entity')? (y/n): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Try delete by config id first (if present)
        deleted=false
        if [ -n "$ha_id" ]; then
          log "INFO: Attempting delete via /api/config/automation/config/$ha_id"
          resp=$(curl -s -w "\n%{http_code}" -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$HA_URL/api/config/automation/config/$ha_id" || true)
          body=$(echo "$resp" | sed '$d')
          code=$(echo "$resp" | tail -n1)
          log "DEBUG: Response code=$code body=${body}"
          if [ "$code" = "200" ] || [ "$code" = "204" ]; then
            log "SUCCESS: Deleted by config id."
            reload_ha_automations || true
            deleted=true
          fi
        fi

        # If not deleted and entity_id present, try deleting by entity endpoint as fallback
        if [ "$deleted" = false ] && [ -n "$ha_entity" ]; then
          log "INFO: Attempting delete via /api/automations/$ha_entity"
          resp=$(curl -s -w "\n%{http_code}" -X DELETE -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$HA_URL/api/automations/$ha_entity" || true)
          body=$(echo "$resp" | sed '$d')
          code=$(echo "$resp" | tail -n1)
          log "DEBUG: Response code=$code body=${body}"
          if [ "$code" = "200" ] || [ "$code" = "204" ]; then
            log "SUCCESS: Deleted by entity_id."
            reload_ha_automations || true
            deleted=true
          fi
        fi

        if [ "$deleted" = true ]; then
          deleted_count=$((deleted_count+1))
        else
          log "ERROR: Could not delete automation (tried config id and entity_id)."
          log "INFO: Check API response above and try manual deletion via Home Assistant UI."
        fi
      else
        log "INFO: Skipped deletion of automation (user chose no)."
      fi
    fi
  done

  if [ "$orphaned_count" -eq 0 ]; then
    log "SUCCESS: No orphaned automations found."
  else
    log "SUCCESS: Found $orphaned_count orphaned automations, deleted $deleted_count."
  fi
}

main "$@"

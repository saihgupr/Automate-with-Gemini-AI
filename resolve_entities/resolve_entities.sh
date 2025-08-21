#!/bin/bash

# resolve_entities.sh
# Resolves natural language phrases in a command to Home Assistant entity IDs.
# Domain-first approach using automatic domain detection and entity filtering.

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

# --- Helper Functions ---
log() {
  # Logs messages to stderr (now suppressed)
  # echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >&2
  :
}

check_dependencies() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then log "ERROR: '$cmd' not found."; exit 1; fi
  done
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ]; then log "ERROR: config.sh not found."; exit 1; fi
  # shellcheck source=config.sh
  source "$CONFIG_FILE"
  if [[ -z "$HA_URL" || "$HA_URL" == "http://your-home-assistant-ip:8123" || -z "$HA_TOKEN" ]]; then
    log "ERROR: HA_URL or HA_TOKEN not set in $CONFIG_FILE."
    exit 1
  fi
}

# --- Entity Resolution Functions ---

# Special function to handle notify commands
resolve_notify_command() {
  local command="$1"
  local temp_command
  temp_command=$(echo "$command" | tr '[:upper:]' '[:lower:]')
  
  # Define notify patterns and their corresponding services
  local notify_patterns=(
    "notify iphone|notify.mobile_app_iphone"
    "notify my iphone|notify.mobile_app_iphone"
    "notify the iphone|notify.mobile_app_iphone"
    "notify ipad|notify.mobile_app_ipad"
    "notify my ipad|notify.mobile_app_ipad"
    "notify the ipad|notify.mobile_app_ipad"
    "notify mac|notify.mac_mini"
    "notify my mac|notify.mac_mini"
    "notify the mac|notify.mac_mini"
    "notify mac mini|notify.mac_mini"
    "notify my mac mini|notify.mac_mini"
    "notify the mac mini|notify.mac_mini"
    "notify all devices|notify.all_devices"
    "notify all|notify.all_devices"
  )
  
  for pattern in "${notify_patterns[@]}"; do
    local search_pattern="${pattern%|*}"
    local replacement="${pattern#*|}"
    
    if [[ "$temp_command" == *"$search_pattern"* ]]; then
      command="${command//$search_pattern/$replacement}"
      log "INFO: Resolved notify pattern '$search_pattern' to '$replacement'"
      break
    fi
  done
  
  echo "$command"
}

get_entities() {
  local cache_file="$SCRIPT_DIR/.entity_cache"
  if [ "$1" == "--update" ]; then rm -f "$cache_file"; log "INFO: Forcing entity cache refresh."; fi
  if [ -f "$cache_file" ]; then log "INFO: Using cached entities."; cat "$cache_file"; return 0; fi
  
  log "INFO: Fetching entities from Home Assistant..."
  local response
  response=$(curl -s -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" "$HA_URL/api/states")
  if [ $? -ne 0 ]; then log "ERROR: Failed to fetch entities."; return 1; fi
  
  local entities
  entities=$(echo "$response" | jq -r '.[] | "\(.entity_id)|\(.attributes.friendly_name // .entity_id)"' 2>/dev/null)
  
  if [ -n "$entities" ]; then
    echo "$entities" > "$cache_file"
    log "INFO: Cached $(echo "$entities" | wc -l | xargs) entities."
    echo "$entities"
  else
    log "ERROR: Failed to parse entity response."; return 1
  fi
}

# Domain detection function
detect_domain() {
  local search_term="$1"
  local search_lower
  search_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
  
  # Define domain keywords and their corresponding domains
  local domain_keywords=(
    "light|lights|bulb|bulbs|lamp|lamps|led|leds|lighting"
    "switch|switches|outlet|outlets|plug|plugs"
    "climate|thermostat|heater|heating|cooling|fan|fans|ac|air conditioner|air conditioning"
    "sensor|sensors|temperature|temp|humidity|pressure|motion|presence|occupancy"
    "binary_sensor|binary sensors|motion sensor|presence sensor|door sensor|window sensor"
    "device_tracker|tracker|trackers|phone|iphone|ipad|mac|location"
    "media_player|media|player|tv|television|speaker|speakers|audio"
    "camera|cameras|video|security"
    "cover|covers|garage|door|doors|window|windows|blind|blinds|shade|shades"
    "lock|locks|deadbolt"
    "fan|fans|ventilation"
    "vacuum|robot|cleaner"
    "alarm|alarm_control_panel|security"
  )
  
  local domain_mappings=(
    "light"
    "switch"
    "climate"
    "sensor"
    "binary_sensor"
    "device_tracker"
    "media_player"
    "camera"
    "cover"
    "lock"
    "fan"
    "vacuum"
    "alarm_control_panel"
  )
  
  for i in "${!domain_keywords[@]}"; do
    if [[ "$search_lower" =~ ${domain_keywords[$i]} ]]; then
      echo "${domain_mappings[$i]}"
      return 0
    fi
  done
  
  # No domain detected
  echo ""
  return 1
}

# Domain-aware fuzzy search
fuzzy_search_entity_domain() {
  local search_term="$1"
  local entities="$2"
  local detected_domain="$3"
  
  if [ -z "$search_term" ] || [ -z "$entities" ]; then return 1; fi
  
  local search_lower
  search_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
  
  local best_match=""
  local best_score=0
  
  while IFS='|' read -r entity_id friendly_name; do
    # If domain is detected, only consider entities from that domain
    if [ -n "$detected_domain" ] && [[ "$entity_id" != "$detected_domain".* ]]; then
      continue
    fi
    
    local score=0
    local entity_lower
    entity_lower=$(echo "$entity_id" | tr '[:upper:]' '[:lower:]')
    local friendly_lower
    friendly_lower=$(echo "$friendly_name" | tr '[:upper:]' '[:lower:]')
    
    # Exact match
    if [[ "$friendly_lower" == "$search_lower" ]] || [[ "$entity_lower" == "$search_lower" ]]; then 
      score=100;
    # Starts with match
    elif [[ "$friendly_lower" == "$search_lower"* ]] || [[ "$entity_lower" == "$search_lower"* ]]; then 
      score=80;
    # Word boundary match
    elif [[ "$friendly_lower" =~ (^|[^a-z])$search_lower([^a-z]|$) ]] || [[ "$entity_lower" =~ (^|[^a-z])$search_lower([^a-z]|$) ]]; then 
      score=60;
    # Contains match
    elif [[ "$friendly_lower" == *"$search_lower"* ]] || [[ "$entity_lower" == *"$search_lower"* ]]; then 
      score=40;
    fi
    
    # For multi-word patterns, check if all words are present
    if [ "$score" -eq 0 ] && [[ "$search_lower" == *" "* ]]; then
      local all_words_present=1
      local word_score=0
      for word in $search_lower; do
        local word_found=0
        if [[ "$friendly_lower" == *"$word"* ]] || [[ "$entity_lower" == *"$word"* ]]; then
          word_found=1
          word_score=$((word_score + 20))
        fi
        if [ "$word_found" -eq 0 ]; then
          all_words_present=0
          break
        fi
      done
      if [ "$all_words_present" -eq 1 ]; then
        score=$word_score
      fi
    fi
    
    if [ "$score" -eq 0 ]; then continue; fi

    # --- Scoring Penalty for Length Difference ---
    local len_diff=$(( ${#friendly_lower} - ${#search_lower} ))
    len_diff=${len_diff#-}
    score=$(( score - len_diff ))

    # --- Domain Bonus (if domain was detected) ---
    if [ -n "$detected_domain" ] && [[ "$entity_id" == "$detected_domain".* ]]; then
      score=$((score + 20))
    fi

    if [ "$score" -gt "$best_score" ]; then
      best_score=$score
      best_match="$entity_id"
    fi
  done <<< "$entities"
  
  # Lowered threshold to be more permissive
  if [ "$best_score" -ge 30 ]; then
    echo "$best_match"
    return 0
  elif [[ "$search_term" == *" "* ]] && [ "$best_score" -ge 20 ]; then
    # Lower threshold for multi-word patterns
    echo "$best_match"
    return 0
  else
    return 1
  fi
}

# The domain-first entity resolution implementation
resolve_entities() {
  local command="$1"
  local entities="$2"
  
  # First, handle notify commands
  command=$(resolve_notify_command "$command")
  
  local temp_command
  temp_command=$(echo "$command" | tr '[:upper:]' '[:lower:]')
  
  # Continue processing until no more matches are found
  local continue_processing=true
  while [ "$continue_processing" = true ]; do
    continue_processing=false
    
    # Find potential entity phrases (2-4 word combinations)
    local words=($temp_command)
    local word_count=${#words[@]}
    
    # Process phrases from longest to shortest (4 words, then 3, then 2)
    for phrase_length in 4 3 2; do
      for ((i=0; i<=word_count-phrase_length; i++)); do
        local phrase=""
        for ((j=0; j<phrase_length; j++)); do
          if [ $j -gt 0 ]; then phrase="$phrase "; fi
          phrase="$phrase${words[$((i+j))]}"
        done
        
        # Detect domain for this phrase
        local detected_domain
        detected_domain=$(detect_domain "$phrase")
        
        # Only try to resolve if we detected a domain
        if [ -n "$detected_domain" ]; then
          # Try to resolve the phrase
          local entity_id
          if [ -n "$detected_domain" ]; then
            entity_id=$(fuzzy_search_entity_domain "$phrase" "$entities" "$detected_domain")
          else
            # Fallback to searching all entities if no domain detected
            entity_id=$(fuzzy_search_entity_domain "$phrase" "$entities" "")
          fi
          
          if [ $? -eq 0 ] && [ -n "$entity_id" ]; then
            log "INFO: Resolved '$phrase' to '$entity_id' (domain: ${detected_domain:-none})"
            
            # Replace the phrase with the entity ID
            command="${command//$phrase/$entity_id}"
            temp_command="${temp_command//$phrase/$entity_id}"
            
            # Mark that we found a match and should continue processing
            continue_processing=true
            
            # Break out of inner loop since we found a match
            break
          fi
        fi
      done
      
      # If we found a match, break out of phrase length loop
      if [ "$continue_processing" = true ]; then
        break
      fi
    done
  done
  
  echo "$command"
}

# --- Main Execution ---
main() {
  check_dependencies
  load_config

  local user_command
  if [ -z "$1" ]; then
    echo "Usage: $0 [--update] \"<your command string>\"" >&2
    exit 1
  fi

  local entities
  if [ "$1" == "--update" ]; then
      entities=$(get_entities "--update")
      if [ -n "$2" ]; then user_command="$2"; else exit 0; fi
  else
      user_command="$1"
      entities=$(get_entities)
  fi

  if [ -z "$entities" ]; then log "ERROR: Could not load entities."; exit 1; fi

  local resolved_command
  resolved_command=$(resolve_entities "$user_command" "$entities")
  
  echo "$resolved_command"
}

main "$@"
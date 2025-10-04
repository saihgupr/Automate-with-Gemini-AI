# Resolve Entities

A sophisticated Bash script that resolves natural language phrases to Home Assistant entity IDs using domain-first fuzzy matching. Designed to work with [Automate with Gemini AI](https://github.com/saihgupr/Automate-with-Gemini-AI).

## Features

- **Domain Detection**: Automatically detects the appropriate Home Assistant domain (light, switch, climate, etc.) based on keywords
- **Fuzzy Matching**: Uses intelligent scoring to find the best entity matches
- **Multi-word Support**: Handles complex phrases like "living room ceiling light"
- **Notify Commands**: Special handling for notification services
- **Caching**: Caches entity data for improved performance
- **Configurable**: Easy configuration via `config.sh`

## Usage

### Basic Usage
```bash
./resolve_entities.sh "turn on the living room light when shelf motion is on"
```

### Use With [Automate with Gemini AI](https://github.com/saihgupr/Automate-with-Gemini-AI)
```bash
./send_to_automate_ai_script.sh "turn on the living room light when shelf motion is on"
```

### Update Entity Cache
```bash
./resolve_entities.sh --update "turn on the living room light when shelf motion on"
```

### Examples
```bash
# Lights
./resolve_entities.sh "turn on the living room light when shelf motion is on"
# Output: turn on light.living_room_ceiling_light when binary_sensor.shelf_motion is on

# Switches
./resolve_entities.sh "turn off the coffee maker at noon"
# Output: turn off switch.coffee_maker at noon

# Climate
./resolve_entities.sh "set thermostat to 72 degrees when occupancy is on"
# Output: set climate.thermostat to 72 degrees when input_boolean.occupancy is on

# Notifications
./resolve_entities.sh "notify my iphone that dinner is ready when kitchen button pressed"
# Output: notify.mobile_app_iphone that dinner is ready when button.kitchen pressed

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/saihgupr/resolve_entities.git
   cd resolve_entities
   ```

2. Copy the example configuration:
   ```bash
   cp config.sh.example config.sh
   ```

3. Edit `config.sh` with your Home Assistant details:
   ```bash
   # Your Home Assistant URL (use your actual Home Assistant IP or hostname)
   HA_URL="http://192.168.1.100:8123"
   
   # Your Home Assistant Long-Lived Access Token
   # Generate this in Home Assistant: Profile > Long-Lived Access Tokens
   HA_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
   ```

4. Test the configuration:
   ```bash
   ./resolve_entities.sh "test kitchen light"
   ```

## How It Works

1. **Domain Detection**: The script analyzes your command to detect the appropriate Home Assistant domain
2. **Entity Fetching**: Retrieves all entities from your Home Assistant instance
3. **Fuzzy Matching**: Uses a scoring system to find the best entity match:
   - Exact matches: 100 points
   - Starts with: 80 points
   - Word boundary: 60 points
   - Contains: 40 points
   - Domain bonus: +20 points
4. **Replacement**: Replaces natural language phrases with entity IDs

## Integration with Automate AI

This script is designed to work with the [Automate With Gemini AI](https://github.com/saihgupr/Automate-with-Gemini-AI) project, which handles the actual Home Assistant automation creation.

### Setting Up the Bridge Script

1. Replace config.sh.example with config.sh and fill in your info.

2. Update the script (send_to_automate_ai_script.sh) with your actual paths and hostname:
   - Replace `/path/to/resolve_entities/` with the actual path to this repository
   - Replace `your-homeassistant.local` with your Home Assistant's hostname or IP
   - Replace `/path/to/automate_ai` with the path to this the automate_ai.sh script

Once configured, you can use the bridge script to send natural language commands directly to your Home Assistant system:

```bash
./send_to_automate_ai.sh "turn on the living room light when shelf motion is on"
```

This will:
1. Resolve "living room light" and "shelf motion" to the appropriate entity ID
2. Send the resolved command to your Gemini AI API
3. Create the automation via the automate_ai script

## Dependencies

- `curl`: For API requests to Home Assistant
- `jq`: For JSON parsing

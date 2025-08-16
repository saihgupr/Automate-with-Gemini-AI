# 🤖 Automate_AI

Create Home Assistant automations using plain English, powered by Google’s Gemini AI. Describe what you want, and it turns your ideas into working code without writing YAML. Automations are saved directly to your automations.yaml file and reloaded right away.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Enabled-green.svg)](https://www.home-assistant.io/)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Powered-orange.svg)](https://ai.google.dev/)

---

## Features

- **Natural Language Processing**: Convert plain English to Home Assistant automations
- **Smart Intent Detection**: Automatically detects temporary vs permanent automations
- **Self-Cleaning**: Temporary automations delete themselves after running
- **YAML Validation**: Ensures generated code is syntactically correct
- **Direct Integration**: Automatically adds to your `automations.yaml` and reloads HA
- **Cleanup Tools**: Remove orphaned automations from the UI
- **Command Line Ready**: Use interactively or with command line arguments

## Quick Start

### Prerequisites

- Home Assistant instance
- Google Gemini API key
- Bash shell environment
- `curl`, `jq` (for JSON processing)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/saihgupr/automate_ai.git
   cd automate_ai
   ```

2. **Set up configuration:**
   ```bash
   cp config.sh.example config.sh
   ```

3. **Edit `config.sh` with your details:**
   ```bash
   GEMINI_API_KEY="your_gemini_api_key_here"
   AUTOMATIONS_YAML="/config/automations.yaml"
   HA_URL="http://your-home-assistant.local:8123"
   HA_TOKEN="your_ha_long_lived_token"
   ```

4. **Make scripts executable:**
   ```bash
   chmod +x automate_ai.sh
   chmod +x delete_automation.sh
   chmod +x cleanup_orphaned_automations.sh
   ```

5. **Add shell command to Home Assistant** (in `configuration.yaml`):
   ```yaml
   shell_command:
     delete_temporary_automation: /share/scripts/automate_ai/delete_automation.sh '{{ id }}'
   ```

## Usage

### Interactive Mode

```bash
./automate_ai.sh
```

Then enter your automation command when prompted.

### Command Line Mode

```bash
./automate_ai.sh "Turn on light.living_room_ceiling when binary_sensor.motion_detected is on"
./automate_ai.sh "Turn off light.all_lights at 23:00"
./automate_ai.sh "Make light.bedroom_lights red when binary_sensor.bedroom_door is open for 5 minutes when input_boolean.sleep_mode on"
```

### Examples

| Command | Result |
|---------|--------|
| `"Turn on light.porch_light when binary_sensor.motion == 'on'"` | Creates a permanent automation |
| `"Only once, make light.bedroom_lights blue when binary_sensor.bedroom_door is open"` | Creates a temporary automation that deletes itself |
| `"Turn off light.all_lights at 23:00"` | Creates a time-based automation |

**Note**: These examples require exact entity IDs. For natural language commands, use the "Enhanced Natural Language with Resolve Entities" section below.

## Enhanced Natural Language with Resolve Entities

For even more natural language automation creation, integrate with [resolve_entities](https://github.com/saihgupr/resolve_entities) to automatically convert natural language entity names to Home Assistant entity IDs.


### Examples with Resolve Entities

| Natural Command | Resolved Command | Result |
|-----------------|------------------|--------|
| `"turn on living room ceiling light when motion detected"` | `"turn on light.living_room_ceiling_light when binary_sensor.motion_detected == 'on'"` | More natural input |
| `"turn off the coffee maker at 10 PM"` | `"turn off switch.coffee_maker at 22:00"` | No need to know entity IDs |
| `"set thermostat to 72 degrees when I'm home"` | `"set climate.thermostat to 72 degrees when device_tracker.my_phone == 'home'"` | Automatic domain detection |
| `"notify my iphone that dinner is ready"` | `"notify.mobile_app_iphone that dinner is ready"` | Smart notification handling |

### Setup Integration

1. **Clone the resolve_entities repository:**
   ```bash
   git clone https://github.com/saihgupr/resolve_entities.git
   cd resolve_entities
   cp config.sh.example config.sh
   # Edit config.sh with your Home Assistant details
   chmod +x resolve_entities.sh
   ```

2. **Use resolve_entities to preprocess your commands:**
   ```bash
   # Instead of: ./automate_ai.sh "turn on light.living_room_ceiling_light"
   # Use: ./automate_ai.sh "$(./resolve_entities.sh 'turn on living room ceiling light')"
   ```

### Complete Workflow Example

Here's a real-world example showing the entire process:

**Original Command:**
```bash
when bedroom temperature goes above 75, notify iphone, only once
```

**Conversion after Resolve Entities:**
```bash
when sensor.nodemcu_temperature goes above 75, notify.mobile_app_iphone, only once
```

**Final Automation Added to Home Assistant:**
```yaml
- id: '1755258945'
  alias: One-time temperature notification
  trigger:
    - platform: numeric_state
      entity_id: sensor.nodemcu_temperature
      above: '75'
  condition: []
  action:
    - service: notify.mobile_app_iphone
      data:
        message: "Temperature above 75!"
    - service: shell_command.delete_temporary_automation
      data:
        id: '1755258945'
```

This example demonstrates how resolve_entities intelligently:
- Converts "bedroom temperature" to the actual sensor entity `sensor.nodemcu_temperature`
- Resolves "notify iphone" to the proper notification service `notify.mobile_app_iphone`
- Preserves the "only once" intent for temporary automation creation

### Automated Integration

Create a wrapper script for seamless integration:

```bash
#!/bin/bash
# automate_ai_natural.sh

RESOLVE_ENTITIES_PATH="/path/to/resolve_entities/resolve_entities.sh"
AUTOMATE_AI_PATH="/path/to/automate_ai/automate_ai.sh"

if [ $# -eq 0 ]; then
    echo "Please enter your automation command:"
    read -r user_command
else
    user_command="$*"
fi

# Resolve entities first, then pass to automate_ai
resolved_command=$("$RESOLVE_ENTITIES_PATH" "$user_command")
echo "Resolved command: $resolved_command"
"$AUTOMATE_AI_PATH" "$resolved_command"
```

### Benefits

- **No Entity ID Memorization**: Use natural names like "living room light" instead of "light.living_room_ceiling_light"
- **Smart Domain Detection**: Automatically detects the correct Home Assistant domain
- **Notification Support**: Special handling for mobile app notifications
- **Performance**: Caches entity data for faster resolution
- **Fuzzy Matching**: Handles typos and variations in entity names

### Examples

| Command | Result |
|---------|--------|
| `"Turn on porch light when motion detected"` | Creates a permanent automation |
| `"Turn the light blue for 5 minutes"` | Creates a temporary automation that deletes itself |
| `"Turn off all lights at 11 PM"` | Creates a time-based automation |

## Scripts

- **`automate_ai.sh`** - Main script for creating automations
- **`delete_automation.sh`** - Deletes automations via REST API (called by temporary automations)
- **`cleanup_orphaned_automations.sh`** - Removes orphaned automations from HA UI

## Troubleshooting

### Greyed-out Automations in UI

If you see greyed-out automations after temporary automations run:

```bash
# Run the cleanup script
./cleanup_orphaned_automations.sh
```

### API Errors

1. **Check your HA_TOKEN**: Ensure it's a long-lived access token with appropriate permissions
2. **Verify HA_URL**: Make sure the URL is accessible from your script's location
3. **Check network connectivity**: Ensure the script can reach your Home Assistant instance

### YAML Validation Errors

1. Check the generated YAML in the script output
2. Ensure your `AUTOMATIONS_YAML` path is correct
3. Verify the YAML file is writable

## Security

- Keep your `config.sh` file secure and don't commit it to version control
- Use long-lived access tokens with minimal required permissions
- Consider using SSH keys for the shell command instead of passwords

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Google Gemini AI](https://ai.google.dev/)
- Designed for [Home Assistant](https://www.home-assistant.io/)
- Inspired by the need for simpler automation creation

---

**Made with ❤️ for the Home Assistant community**


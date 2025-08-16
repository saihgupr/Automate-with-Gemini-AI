# 🤖 Automate_AI

Create Home Assistant automations using natural language, powered by Google’s Gemini AI.
Describe your automation in plain English—no YAML required. Automations are saved directly to your automations.yaml file and reloaded instantly.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Enabled-green.svg)](https://www.home-assistant.io/)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Powered-orange.svg)](https://ai.google.dev/)

---

### Example Workflow

Original Command:
```bash
when bedroom temperature goes above 75, notify iphone, only once
```

Conversion after Resolve Entities:
```bash
when sensor.nodemcu_temperature goes above 75, notify.mobile_app_iphone, only once
```

Final Automation Added to Home Assistant:
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


## ✨ Features

- **Natural Language Processing**: Convert plain English to Home Assistant automations
- **Smart Intent Detection**: Automatically detects temporary vs permanent automations
- **Self-Cleaning**: Temporary automations delete themselves after running
- **YAML Validation**: Ensures generated code is syntactically correct
- **Direct Integration**: Automatically adds to your `automations.yaml` and reloads HA
- **Cleanup Tools**: Remove orphaned automations from the UI
- **Command Line Ready**: Use interactively or with command line arguments

## 🚀 Quick Start

### Prerequisites

- Home Assistant instance
- [Free Google Gemini API key](https://ai.google.dev/)
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

5. **Add shell command to Home Assistant** (for temporary automations):
   ```yaml
   shell_command:
     delete_temporary_automation: /share/scripts/automate_ai/delete_automation.sh '{{ id }}'
   ```

## 📖 Usage

### Without Resolve Entities

```bash
./automate_ai.sh "Turn on light.living_room_ceiling when binary_sensor.motion_detected is on"
./automate_ai.sh "Turn off light.bed_lamp at 23:00 if input_boolean.sleep_mode is on"
./automate_ai.sh "Make light.bedroom_lights red when binary_sensor.bedroom_door is open for 5 minutes"
```

### With Resolve Entities

For even more natural language automation creation, integrate with [Resolve Entities](https://github.com/saihgupr/resolve_entities) to automatically convert natural language entity names to Home Assistant entity IDs.


```bash
./send_to_automate_ai.sh "Turn on living room ceiling light when motion detected is on"
./send_to_automate_ai.sh "Turn off the bed lamp at 23:00 if sleep mode is on"
./send_to_automate_ai.sh "Make bedroom lights red when bedroom door is open for 5 minutes"
```

### Make Temporary Automations

Temporary automations are a powerful feature that automatically delete themselves after running once. Perfect for one-time tasks, testing, or situations where you don't want the automation to persist.

#### How Temporary Automations Work

1. **Automatic Detection**: The AI detects when you want a "one-time" or "temporary" automation based on keywords like:
   - "only once"
   - "temporary"
   - "one time"
   - "just this time"

2. **Self-Cleaning**: After the automation triggers and runs, it automatically calls a cleanup service to delete itself from Home Assistant

3. **No Manual Cleanup**: No need to remember to remove the automation later - it handles itself

#### Examples

```bash
# One-time notifications
./send_to_automate_ai.sh "notify my iphone when the laundry is done, only once"

# Temporary lighting effects
./send_to_automate_ai.sh "turn the bedroom light blue for 5 minutes, then turn it off"

# One-time temperature alerts
./send_to_automate_ai.sh "notify me if the temperature goes above 80 degrees, only once"

# Temporary door monitoring
./send_to_automate_ai.sh "notify me if the garage door opens in the next hour"
```

#### What Gets Created

When you create a temporary automation, it includes:
- **Unique ID**: Automatically generated timestamp-based ID
- **Self-delete action**: Calls `shell_command.delete_temporary_automation` after running
- **Normal automation logic**: All your specified triggers, conditions, and actions

#### Example Temporary Automation Output

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

#### Use Cases

- **Testing**: Try out automation ideas without cluttering your automations list
- **One-time alerts**: Get notified about something specific just once
- **Temporary monitoring**: Watch for an event over a limited time period
- **Quick fixes**: Create temporary solutions without permanent changes
- **Guests**: Set up temporary automations for visitors

#### Setup Required

Make sure you have the shell command configured in your `configuration.yaml`:

```yaml
shell_command:
  delete_temporary_automation: /share/scripts/automate_ai/delete_automation.sh '{{ id }}'
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Google Gemini AI](https://ai.google.dev/)
- Designed for [Home Assistant](https://www.home-assistant.io/)
- Inspired by the need for simpler automation creation

---

**Made with ❤️ for the Home Assistant community**


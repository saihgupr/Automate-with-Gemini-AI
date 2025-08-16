# 🤖 Automate_AI

**Transform your words into Home Assistant automations instantly**

Turn natural language into powerful Home Assistant automations using Google's Gemini AI. Just describe what you want in plain English – no YAML knowledge required!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Enabled-green.svg)](https://www.home-assistant.io/)
[![Gemini AI](https://img.shields.io/badge/Gemini%20AI-Powered-orange.svg)](https://ai.google.dev/)

---

## ✨ What Makes This Special

**Before Automate_AI:**
```yaml
# You had to write this complex YAML...
- id: '1755258945'
  alias: Temperature notification
  trigger:
    - platform: numeric_state
      entity_id: sensor.bedroom_temperature
      above: '75'
  condition: []
  action:
    - service: notify.mobile_app_iphone
      data:
        message: "Temperature is too high!"
```

**With Automate_AI:**
```bash
# Just say what you want!
./automate_ai.sh "when bedroom temperature goes above 75, notify my iPhone"
```

## 🚀 Key Features

### 🧠 **Smart Natural Language Processing**
Convert everyday language into perfect Home Assistant automations using Google's Gemini AI.

### 🎯 **Intelligent Intent Detection**
Automatically detects whether you want a one-time action or permanent automation:
- *"Turn the lights blue for 5 minutes"* → Creates temporary automation that self-destructs
- *"Turn on porch light when motion detected"* → Creates permanent automation

### 🧹 **Self-Cleaning Automations**
Temporary automations automatically delete themselves after running – no clutter in your HA interface.

### ✅ **Built-in Validation**
- YAML syntax validation before saving
- Entity ID verification
- Automatic error handling and suggestions

### ⚡ **Instant Integration**
- Saves directly to your `automations.yaml`
- Automatically reloads Home Assistant
- Ready to use immediately

## 📋 Quick Start

### Prerequisites

- Home Assistant instance with REST API enabled
- [Free Google Gemini API key](https://ai.google.dev/) (takes 2 minutes to get)
- Basic command line tools: `curl`, `jq`

### Installation

**1. Clone and setup:**
```bash
git clone https://github.com/saihgupr/automate_ai.git
cd automate_ai
cp config.sh.example config.sh
chmod +x *.sh
```

**2. Configure your settings:**
Edit `config.sh` with your details:
```bash
GEMINI_API_KEY="your_gemini_api_key_here"
AUTOMATIONS_YAML="/config/automations.yaml"
HA_URL="http://your-home-assistant.local:8123"
HA_TOKEN="your_ha_long_lived_token"
```

**3. Add cleanup capability to Home Assistant:**
Add this to your `configuration.yaml`:
```yaml
shell_command:
  delete_temporary_automation: /share/scripts/automate_ai/delete_automation.sh '{{ id }}'
```

**4. Test it out:**
```bash
./automate_ai.sh "turn on living room lights at sunset"
```

## 💡 Usage Examples

### Basic Usage

**Interactive mode:**
```bash
./automate_ai.sh
# Enter: "turn off all lights at 11 PM"
```

**Command line:**
```bash
./automate_ai.sh "notify my phone when garage door opens"
```

### Real-World Examples

| What You Say | What It Creates |
|-------------|-----------------|
| `"turn on porch light when motion detected"` | Motion-triggered lighting |
| `"set thermostat to 68 when I leave home"` | Location-based temperature control |
| `"flash living room lights red when smoke detected"` | Emergency alert system |
| `"turn off coffee maker in 30 minutes"` | Temporary timer automation |
| `"dim bedroom lights to 20% at 10 PM"` | Scheduled ambient lighting |

## 🌟 Enhanced Natural Language (Advanced Setup)

For even more natural commands, integrate with [resolve_entities](https://github.com/saihgupr/resolve_entities) to use friendly names instead of entity IDs.

### Before resolve_entities:
```bash
./automate_ai.sh "turn on light.living_room_ceiling when binary_sensor.motion_detected is on"
```

### After resolve_entities:
```bash
./automate_ai.sh "turn on living room ceiling light when motion is detected"
```

### Setup Integration

**1. Install resolve_entities:**
```bash
git clone https://github.com/saihgupr/resolve_entities.git
cd resolve_entities
cp config.sh.example config.sh
# Edit config.sh with your HA details
chmod +x resolve_entities.sh
```

**2. Create a wrapper script** (`automate_natural.sh`):
```bash
#!/bin/bash
RESOLVE_PATH="/path/to/resolve_entities/resolve_entities.sh"
AUTOMATE_PATH="/path/to/automate_ai/automate_ai.sh"

user_command="$*"
resolved_command=$("$RESOLVE_PATH" "$user_command")
echo "✅ Resolved: $resolved_command"
"$AUTOMATE_PATH" "$resolved_command"
```

**3. Use natural language:**
```bash
./automate_natural.sh "turn on porch light when front door opens"
```

### Natural Language Examples

| Natural Command | Auto-Resolved To | Result |
|----------------|------------------|---------|
| `"turn on living room light"` | `"turn on light.living_room_main"` | ✅ Works perfectly |
| `"notify my iPhone dinner ready"` | `"notify.mobile_app_johns_iphone dinner ready"` | ✅ Smart notification |
| `"set bedroom temp to 72"` | `"set climate.bedroom_thermostat to 72"` | ✅ Climate control |

## 🛠️ Troubleshooting

### Common Issues

**❌ Greyed-out automations in UI:**
```bash
# Clean up orphaned automations
./cleanup_orphaned_automations.sh
```

**❌ "Entity not found" errors:**
- Use the resolve_entities integration for natural names
- Check entity IDs in Home Assistant's Developer Tools

**❌ API connection errors:**
- Verify your `HA_TOKEN` has proper permissions
- Check that `HA_URL` is accessible
- Test with: `curl -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/"`

**❌ YAML syntax errors:**
- Check the generated YAML in script output
- Ensure `AUTOMATIONS_YAML` path is correct and writable

### Getting Help

1. **Check the logs:** Look at the script output for detailed error messages
2. **Test connectivity:** Verify your HA instance is reachable
3. **Validate config:** Double-check your `config.sh` settings
4. **Try simple commands first:** Start with basic automations before complex ones

## 📚 Advanced Features

### Automation Types

**Permanent Automations:**
- Triggered by events, schedules, or conditions
- Remain active until manually disabled
- Example: *"turn on lights when motion detected"*

**Temporary Automations:**
- Execute once and self-destruct
- Perfect for timers and one-off tasks
- Example: *"turn off TV in 30 minutes"*

### Command Patterns

The AI understands various command structures:
- **Time-based:** *"at 6 AM"*, *"every weekday at sunrise"*, *"in 2 hours"*
- **Event-based:** *"when door opens"*, *"if temperature above 75"*
- **Conditional:** *"only when home"*, *"if lights are off"*
- **Actions:** *"turn on/off"*, *"set to"*, *"notify"*, *"toggle"*

## 🔧 Utility Scripts

- **`automate_ai.sh`** - Main automation creator
- **`delete_automation.sh`** - Removes automations via REST API
- **`cleanup_orphaned_automations.sh`** - Cleans up UI orphans

## 🔒 Security Best Practices

- Store `config.sh` securely and add it to `.gitignore`
- Use Home Assistant long-lived tokens with minimal required permissions
- Consider running scripts from a dedicated service account
- Regularly rotate your API keys and tokens

## 🤝 Contributing

We love contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b amazing-feature`
3. **Make your changes and test thoroughly**
4. **Submit a pull request with a clear description**

### Ideas for contributions:
- Support for additional AI models
- Web interface for easier usage
- Integration with other home automation platforms
- Enhanced error handling and validation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **[Google Gemini AI](https://ai.google.dev/)** - Powers the natural language processing
- **[Home Assistant](https://www.home-assistant.io/)** - The amazing home automation platform
- **The Home Assistant Community** - For endless inspiration and support

---


**Made with ❤️ for the Home Assistant community**

[⭐ Star this repo](https://github.com/saihgupr/automate_ai) • [🐛 Report issues](https://github.com/saihgupr/automate_ai/issues) • [💡 Request features](https://github.com/saihgupr/automate_ai/discussions)

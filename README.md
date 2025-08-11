# Automate_AI 🤖

> Create Home Assistant automations using natural language commands powered by Google's Gemini AI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell%20Script-Bash-blue.svg)](https://www.gnu.org/software/bash/)

Transform your automation ideas into working Home Assistant code with simple English commands. No more YAML syntax headaches!

## ✨ Features

- **🎯 Natural Language Processing**: Convert plain English to Home Assistant automations
- **⚡ Smart Intent Detection**: Automatically detects temporary vs permanent automations
- **🔄 Self-Cleaning**: Temporary automations delete themselves after running
- **✅ YAML Validation**: Ensures generated code is syntactically correct
- **🔗 Direct Integration**: Automatically adds to your `automations.yaml` and reloads HA
- **🧹 Cleanup Tools**: Remove orphaned automations from the UI
- **🚀 Command Line Ready**: Use interactively or with command line arguments

## 🚀 Quick Start

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
     delete_temporary_automation: "/share/scripts/automate_ai/delete_automation.sh '{{ id }}'"
   ```

## 📖 Usage

### Interactive Mode

```bash
./automate_ai.sh
```

Then enter your automation command when prompted.

### Command Line Mode

```bash
./automate_ai.sh "Turn on the living room lights when motion is detected"
./automate_ai.sh "Turn off all lights at 11 PM"
./automate_ai.sh "Turn the bedroom light blue for 5 minutes"
```

### Examples

| Command | Result |
|---------|--------|
| `"Turn on porch light when motion detected"` | Creates a permanent automation |
| `"Turn the light blue for 5 minutes"` | Creates a temporary automation that deletes itself |
| `"Turn off all lights at 11 PM"` | Creates a time-based automation |

## 🛠️ Scripts

- **`automate_ai.sh`** - Main script for creating automations
- **`delete_automation.sh`** - Deletes automations via REST API (called by temporary automations)
- **`cleanup_orphaned_automations.sh`** - Removes orphaned automations from HA UI

## 🔧 Troubleshooting

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

## 🔒 Security

- Keep your `config.sh` file secure and don't commit it to version control
- Use long-lived access tokens with minimal required permissions
- Consider using SSH keys for the shell command instead of passwords

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


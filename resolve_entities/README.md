# Resolve Entities

A sophisticated Bash script that resolves natural language phrases to Home Assistant entity IDs using domain-first fuzzy matching. Designed to work with [Automate with Gemini AI](https://github.com/saihgupr/Automate-with-Gemini-AI).

## Features

- **Domain Detection**: Automatically detects the appropriate Home Assistant domain (light, switch, climate, etc.) based on keywords
- **Fuzzy Matching**: Uses intelligent scoring to find the best entity matches
- **Multi-word Support**: Handles complex phrases like "living room ceiling light"
- **Notify Commands**: Special handling for notification services
- **Caching**: Caches entity data for improved performance
- **Configurable**: Easy configuration via `config.sh`

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

4. Make the script executable:
   ```bash
   chmod +x resolve_entities.sh
   ```

5. Test the configuration:
   ```bash
   ./resolve_entities.sh "test light"
   ```

## Usage

### Basic Usage
```bash
./resolve_entities.sh "turn on the living room light"
```

### Update Entity Cache
```bash
./resolve_entities.sh --update "turn on the living room light"
```

### Examples
```bash
# Lights
./resolve_entities.sh "turn on living room ceiling light"
# Output: turn on light.living_room_ceiling_light

# Switches
./resolve_entities.sh "turn off the coffee maker"
# Output: turn off switch.coffee_maker

# Climate
./resolve_entities.sh "set thermostat to 72 degrees"
# Output: set climate.thermostat to 72 degrees

# Notifications
./resolve_entities.sh "notify my iphone that dinner is ready"
# Output: notify.mobile_app_iphone that dinner is ready
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

This script is designed to work with the [automate_ai](https://github.com/saihgupr/automate_ai) project, which handles the actual Home Assistant automation execution.

### Setting Up the Bridge Script

1. Create a bridge script to connect to your Home Assistant system:
   ```bash
   # Create send_to_automate_ai.sh
   cat > send_to_automate_ai.sh << 'EOF'
   #!/bin/bash
   
   resolved="$(/path/to/resolve_entities/resolve_entities.sh "$*")"
   
   ssh root@your-homeassistant.local "cd /share/scripts/automate_ai && ./automate_ai.sh \"$resolved\""
   EOF
   
   chmod +x send_to_automate_ai.sh
   ```

2. Configure SSH access to your Home Assistant system:
   ```bash
   # Generate SSH key if you don't have one
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
   
   # Copy your public key to Home Assistant
   ssh-copy-id root@your-homeassistant.local
   ```

3. Update the bridge script with your actual paths and hostname:
   - Replace `/path/to/resolve_entities/` with the actual path to this repository
   - Replace `your-homeassistant.local` with your Home Assistant's hostname or IP
   - Ensure the remote path `/share/scripts/automate_ai` exists on your Home Assistant system

### Using the Bridge Script

Once configured, you can use the bridge script to send natural language commands directly to your Home Assistant system:

```bash
./send_to_automate_ai.sh "turn on the living room light"
```

This will:
1. Resolve "living room light" to the appropriate entity ID
2. Send the resolved command to your Home Assistant system
3. Execute the automation via the automate_ai script

## Dependencies

- `curl`: For API requests to Home Assistant
- `jq`: For JSON parsing
- `bash`: Shell environment

## Configuration

### Local Configuration (`config.sh`)

The `config.sh` file contains your Home Assistant connection details:

- `HA_URL`: Your Home Assistant URL (e.g., `http://192.168.1.100:8123`)
- `HA_TOKEN`: Your long-lived access token for API access

**Important:** The `config.sh` file is excluded from Git for security reasons. Always use the `config.sh.example` as a template.

### Bridge Script Configuration

The bridge script (`send_to_automate_ai.sh`) needs to be configured with:

- **Local path**: Path to this repository on your local machine
- **Remote hostname**: Your Home Assistant system's hostname or IP
- **Remote path**: Path to the automate_ai scripts on your Home Assistant system
- **SSH access**: Key-based authentication to your Home Assistant system

## Security Notes

- **Never commit `config.sh`** to version control (it's in `.gitignore`)
- **Use long-lived access tokens**, not your main Home Assistant password
- **Secure SSH access** to your Home Assistant system with key-based authentication
- **Consider using environment variables** for sensitive data in production
- **Keep your Home Assistant system updated** and behind a firewall
- **Monitor SSH access logs** for any unauthorized attempts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Please check the LICENSE file for details.

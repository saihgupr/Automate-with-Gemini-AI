#!/bin/bash

#Send to Resolve Entities
resolved="$(/path/to/resolve_entities.sh "$*")"

#Send to Automate_AI
ssh root@homeassistant.local "cd /path/to/automate_ai && ./automate_ai.sh \"$resolved\""
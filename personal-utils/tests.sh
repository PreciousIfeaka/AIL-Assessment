#!/bin/bash

# Set your target webhook URL here
WEBHOOK_URL="https://zuri.prexx.online/webhook/900e6470-4e45-4b07-a686-2fff9ef8d8ee/whatsapp"
SECRET="S8FmkX5ttfC9RaswpmjvkZbeAHJRIiuf"

# Check if a file argument was provided
if [ -z "$1" ]; then
    echo "Error: No JSON file specified."
    echo "Usage: ./tests.sh <json-file>"
    exit 1
fi

JSON_FILE="$1"

# Check if the specified file actually exists
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File '$JSON_FILE' not found in the current directory."
    exit 1
fi

echo "Sending payload from: $JSON_FILE to $WEBHOOK_URL..."
echo "------------------------------------------------------"

SIG=$(openssl dgst -sha256 -hmac "$SECRET" -r < "$JSON_FILE" | cut -d' ' -f1)

# Execute the POST request using curl
curl -s -S -w "\nHTTP Status: %{http_code}\n" \
     -X POST \
     -H "Content-Type: application/json" \
     -H "X-Hub-Signature-256: sha256=$SIG" \
     --data-binary @"$JSON_FILE" \
     "$WEBHOOK_URL"

echo "------------------------------------------------------"
echo "Done!"
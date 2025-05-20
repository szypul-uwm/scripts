#!/bin/bash

CONFIG_URL_FILE="../config_curl.txt"
SCRIPT_DIR="./toRun"

cd /scripts

LOG_DIR="./toRun/logs"

mkdir -p "$LOG_DIR"

echo "=== Autostart begin: $(date) ==="

# 1. Sprawdź, czy istnieje plik z URL-em
if [[ -f "$CONFIG_URL_FILE" ]]; then
  CURL_TEXT=$(<"$CONFIG_URL_FILE")

  echo "Config URL found: $CURL_TEXT"

  # 2. Pobierz konfigurację z URL (lista skryptów oddzielona średnikami)
  SCRIPT_LIST=$(bash -c "$CURL_TEXT")

  if [[ -z "$SCRIPT_LIST" ]]; then
    echo "Config is empty or could not be downloaded"
  else
    echo "Downloaded script list: $SCRIPT_LIST"

    # 3. Rozdziel po średnikach i uruchom każdy skrypt
    IFS=';' read -ra SCRIPTS <<< "$SCRIPT_LIST"
    for script_name in "${SCRIPTS[@]}"; do
      SCRIPT_PATH="$SCRIPT_DIR/$script_name"

      if [[ -f "$SCRIPT_PATH" ]]; then
        chmod +x "$SCRIPT_PATH"
        echo "Starting $script_name..."
        sudo -u wamasoft DISPLAY=:1 xfce4-terminal --hold --command="$SCRIPT_PATH"
        # lub do logu:
        # sudo "$SCRIPT_PATH" > "$LOG_DIR/${script_name}.log" 2>&1 &
      else
        echo "Script not found: $SCRIPT_PATH"
      fi
    done
  fi
else
  echo "No config file found at $CONFIG_URL_FILE"
fi

echo "=== Autostart end: $(date) ==="

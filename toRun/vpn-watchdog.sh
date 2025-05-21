#!/bin/bash

CONFIG="/etc/openfortivpn/config"

echo "=== VPN watchdog started ===" 

while true; do
  echo "$(date): Starting VPN..." 
  
  sudo openfortivpn >&1
  

  echo "$(date): VPN disconnected. Reconnecting in 10 seconds..."
  sleep 10
done
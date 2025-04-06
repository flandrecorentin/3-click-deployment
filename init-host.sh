#!/bin/bash

path_logs='/3-click-deployment/logs/'
path_repositories='/3-click-deployment/repositories/'
path_nginx_sites='/etc/nginx/sites-enabled'
path_3_click_deployment_default_nginx_conf='/3-click-deployment/3-click-deployment-default.nginx.conf'
debug="true"

# Argument treatment (validation and initialization)
if [ "$#" -eq 2 ]; then
    echo "[INFO] Executing init-host.sh with |$1| id: |$2|"
    config_file="$1"
    id="$2"
elif [ "$#" -eq 1 ]; then
  echo "[INFO] Executing init-host.sh with config.json id: |$1|"
  config_file="config.json"
  id="$1"
else
  echo "[ERROR] Incorrect number of argument"
  exit 1
fi

# Use jq to filter and retrieve the block with id "portfolio"
json_block=$(jq --arg id "$id" '.[] | select(.id == $id)' "$config_file")
# Check if the string is empty
if [ -z "$json_block" ]; then
  echo "[ERROR] No json block with id |$id| into |$config_file|"; exit 1;
fi

if [ "$debug" = "true" ]; then echo "[DEBUG] json_block: |$json_block|"; fi
port=$(echo $json_block| jq -r '.port_1')
dns=$(echo $json_block| jq -r '.dns')

# Validate json

# Validate the input size
# init nginx config (with dns and host)

# Nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
path_nginx_file="$path_nginx_sites/$id"
cat "$path_3_click_deployment_default_nginx_conf" > "$path_nginx_file"
echo "[INFO] Create nginx file |$path_nginx_file| using template |$path_3_click_deployment_default_nginx_conf|"
sed -i "s|<DNS>|$dns|g" "$path_nginx_file"
echo "[INFO] Edit <DNS> with |$dns|"
sed -i "s|<PORT>|$port|g" "$path_nginx_file"
echo "[INFO] Edit <PORT> with |$port|"
echo "[INFO] -----------------------------------------------------"; echo ""

# Restart nginx service
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx start at $now"
sudo systemctl restart nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx finished at $now"
echo "[INFO] -----------------------------------------------------"; echo ""

# Certbot
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Run certbot for ngin for following dns: |$dns|"
sudo certbot --nginx --non-interactive --agree-tos -d "$dns"
echo "[INFO] -----------------------------------------------------"; echo ""

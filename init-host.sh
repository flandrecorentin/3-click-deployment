#!/bin/bash

path_logs='/3-click-deployment/logs/'
path_repositories='/3-click-deployment/repositories/'
path_nginx_sites='/etc/nginx/sites-enabled'
path_3_click_deployment_default_nginx_conf='/3-click-deployment/3-click-deployment-default.nginx.conf'
debug="true"

# Argument treatment (validation and initialization)
if [ "$#" -eq 2 ]; then
    echo "[INFO] Executing init-host.sh with $0 <argument> id: $1 <argument>"
    config_file="$0"
    id="$1"
elif [ "$#" -eq 1 ]; then
  echo "[INFO] Executing init-host.sh with  config.json id: $0 <argument>"
  config_file="config.json"
  id="$0"
else
  echo "[ERROR] Incorrect number of argument"
  exit 1
fi

# Use jq to filter and retrieve the block with id "portfolio"
json_block=$(jq '.[] | select(.id == "$id")' "$json_file")
if [ "$debug" = "true" ]; then echo "[DEBUG] json_block: |$path_repositories|"; fi

# Validate json

# Validate the input size
# init nginx config (with dns and host)

# Nginx
cat "$path_3_click_deployment_default_nginx_conf" > "$path_nginx_sites/$id"
# TODO Replace nginx values

# Certbot
sudo certbot certonly --nginx --non-interactive --agree-tos -d "$dns"

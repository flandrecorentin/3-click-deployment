#!/bin/bash

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

# Init
base_logs='/3-click-deployment/logs/'
base_repositories='/3-click-deployment/repositories/'
base_nginx_sites='/etc/nginx/sites-enabled'
debug="true"

sudo mkdir "$base_logs"
sudo mkdir "$base_repositories"

if [ "$debug" = "true" ]; then
  echo "[DEBUG] base_logs: |$base_logs|"
fi
if [ "$debug" = "true" ]; then
  echo "[DEBUG] base_repositories: |$base_repositories|"
fi

# Prerequisites
# sudo apt install jq
# install jq, nginx, certbot, (use template nginx)


# Read JSON file
json_data=$(cat config.json)

# Loop through each object in the array
json_block=$(jq --arg id "$id" '.[] | select(.id == $id)' "$config_file")
if [ -z "$json_block" ]; then echo "[ERROR] No json block find with id |$id| into |$config_file|"; exit 1; fi

# TODO : default value
# Retrieve 3-click-development config file values
github_url=$(echo $json_block | jq -r '.github_url')
github_owner=$(echo $json_block | jq -r '.github_owner')
github_repository=$(echo $json_block | jq -r '.github_repository')
branch=$(echo $json_block | jq -r '.github_branch')
dns=$(echo $json_block | jq -r '.dns')
port_1=$(echo $json_block | jq -r '.port_1')
port_2=$(echo $json_block | jq -r '.port_2')
docker_port=$(echo $json_block | jq -r '.docker_port')

# Print extracted values
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Id of config: $id"
echo "[INFO] Github URL : |$github_url|"
echo "[INFO] GitHub : repository |$github_repository| owned by |$github_url| with branch |$branch|"
echo "[INFO] DNS used: |$dns|"
echo "[INFO] Ports used for flip : |$port_1|, |$port_2| and expose docker port |$docker_port|"
echo "[INFO] -----------------------------------------------------"; echo ""

now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Current directory before clone, checkout, pull: $(pwd)"
cd "$base_repositories" || { echo "[ERROR] Failed to change directory to $folder_path"; exit 1; }

echo "[INFO] Cloning: |$github_url| into |$id|"
sudo git clone $github_url $id
cd "$base_repositories/$id"
echo "[INFO] Checkout |$branch| branch"
sudo git checkout "$branch"
echo "[INFO] Pull"
sudo git pull
echo "[INFO] -----------------------------------------------------"; echo ""

# Initialize variables for docker actions
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Current directory before building image: $(pwd)"
new_port=""
old_port=""
docker_line_1=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_1")
docker_line_2=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_2")
if [ -z "$docker_line_1" ]; then
    echo "[INFO] Currently no container found open on port $port_1"
else
  if [ "$debug" = "true" ]; then
    echo "[DEBUG] docker_line_1: $docker_line_1";
  fi
  current_name_1=$(echo "$docker_line_1" | awk -F ' || ' '{print $1}')
  current_port_1=$(echo "$docker_line_1" | awk -F '[->,:]' '{print $3}')
  new_port="$port_2"
  old_port="$port_1"
  echo "[INFO] Currently $current_name_1 is running on $current_port_1"
fi

if [ -z "$docker_line_2" ]; then
    echo "[INFO] Currently no container found open on port $port_2"
else
  if [ "$debug" = "true" ]; then echo "[DEBUG] docker_line_2: $docker_line_2"; fi
  current_name_2=$(echo "$docker_line_2" | awk -F ' || ' '{print $1}')
  current_port_2=$(echo "$docker_line_2" | awk -F '[->,:]' '{print $3}')
  new_port="$port_1"
  old_port="$port_2"
  echo "[INFO] Currently $current_name_2 is running on $current_port_2"
fi


if [ -z "$docker_line_1" ] && [ -z "$docker_line_2" ]; then
  echo "[INFO] It will be first deployment for $id"
  is_first_deployment="true"
  new_port="$port_1"
fi

if [ -n "$docker_line_1" ] && [ -n "$docker_line_2" ]; then
  echo "[ERROR] Both port_1 ($current_port_1) and port_2 ($current_port_2) are currently used"
  exit 1
fi

if [ -n "$docker_line_1" ] && [ "$current_name_1" != "container-$id-$port_1" ]; then
  echo "$docker_line_1"
  echo "[ERROR] $port_1 is not used by a $id container. Stopping deployment by safety"
  exit 1
fi

if [ -n "$docker_line_2" ] && [ "$current_name_2" != "container-$id-$port_2" ]; then
  echo "[ERROR] $port_1 is not used by a $id container. Stopping deployment by safety"
  exit 1
fi
echo "[INFO] -----------------------------------------------------"; echo ""

# Docker actions
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
new_image_name="image-$id-$new_port"
old_image_name="image-$id-$old_port"
new_container_name="container-$id-$new_port"
old_container_name="container-$id-$old_port"
echo "[INFO] new image |$new_image_name|"
echo "[INFO] old_container_name |$old_container_name|"

echo "[INFO] Building new image |$new_image_name|"
sudo docker build -t "$new_image_name" . # add the tag commit ?
# need to retreive the port of the Dockerfile
echo "[INFO] Running new |$new_container_name| on |$new_port| (using docker port |$docker_port|)"
sudo docker run --name "$new_container_name" -d -p "$new_port:$docker_port" "$new_image_name"
echo "[INFO] -----------------------------------------------------"; echo ""

# Update nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
path_nginx_file="$base_nginx_sites/$id"
current_proxy_pass=$(grep "proxy_pass" "$path_nginx_file" | awk -F 'http://localhost:' '{print "http://localhost:"$2}')

# Check if a proxy_pass was found
if [ -z "$current_proxy_pass" ]; then
  echo "[ERROR] No proxy_pass found in the nginx conf"
  exit 1
else
  echo "[INFO] The current proxy_pass is: $current_proxy_pass"
fi

if [ "$debug" = "true" ]; then echo "[DEBUG] before grep : |$current_proxy_pass|$old_port|"; fi
# Check if the string contains the substring
if [ "$is_first_deployment" != "true" ] && echo "$current_proxy_pass" | grep -q "$old_port"; then
  echo "[INFO] The proxy_pass will be edit"
elif [ "$first_deployment" != "true" ]; then
  echo "[ERROR] The current proxy pass ($current_proxy_pass) does not contain the old port ($old_port)"
  exit 1
else
 echo "[INFO] First deployment, will not change old_port"
fi

if [ "$is_first_deployment" != "true" ]; then
  echo "[INFO] Replacing old_port to new_port into nginx file"
  sudo sed -i "s|$old_port|$new_port|g" "$path_nginx_file"
fi

# Restart nginx service
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx start at $now"
sudo systemctl restart nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx finished at $now"
echo "[INFO] -----------------------------------------------------"; echo ""


# Delete old docker (if running (not first time))
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Kill, remove old container (|$old_container_name|) and remove old image (|$old_image_name|)"
if [ "$is_first_deployment" != "true" ]; then
   sudo docker kill "$old_container_name"
   sudo docker rm "$old_container_name"
   sudo docker image rm "$old_image_name" -f
else
  echo "[INFO] First deployment, will not delete old container/image"
fi
echo "[INFO] -----------------------------------------------------"; echo ""

# Clean repository
echo "[INFO] ---------------------$now--------------------------"
echo "[INFO] Delete repository folder (|$base_repositories/$id|)"
sudo rm -rf "$base_repositories/$id"
echo "[INFO] -----------------------------------------------------"

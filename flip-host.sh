#!/bin/bash

# Argument treatment (validation and initialization)
if [ "$#" -eq 2 ]; then
    echo "...Executing init-host.sh with |$1| id: |$2|"
    config_file="$1"
    id="$2"
elif [ "$#" -eq 1 ]; then
  echo "...Executing init-host.sh with /3-click-deployment/config.json id: |$1|"
  config_file="/3-click-deployment/config.json"
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

#sudo mkdir "$base_logs"
#sudo mkdir "$base_repositories"

start=$(date +"%Y-%m-%d-%H-%M")
log_file_path="$base_logs/flip-host-$id-$start"
sudo touch "$log_file_path"

if [ "$debug" = "true" ]; then
  echo "[DEBUG] base_logs: |$base_logs|" >> "$log_file_path"
fi
if [ "$debug" = "true" ]; then
  echo "[DEBUG] base_repositories: |$base_repositories|" >> "$log_file_path"
fi

# Prerequisites
# sudo apt install jq
# install jq, nginx, certbot, (use template nginx)


# Read JSON file
json_data=$(cat config_file)

# Loop through each object in the array
json_block=$(jq --arg id "$id" '.[] | select(.id == $id)' "$config_file")
if [ -z "$json_block" ]; then echo "[ERROR] No json block find with id |$id| into |$config_file|" >> "$log_file_path"; exit 1; fi

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
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
echo "[INFO] Id of config: $id" >> "$log_file_path"
echo "[INFO] Github URL : |$github_url|" >> "$log_file_path"
echo "[INFO] GitHub : repository |$github_repository| owned by |$github_url| with branch |$branch|" >> "$log_file_path"
echo "[INFO] DNS used: |$dns|" >> "$log_file_path"
echo "[INFO] Ports used for flip : |$port_1|, |$port_2| and expose docker port |$docker_port|" >> "$log_file_path"
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"

now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
echo "[INFO] Current directory before clone, checkout, pull: $(pwd)" >> "$log_file_path"
cd "$base_repositories" || { echo "[ERROR] Failed to change directory to $folder_path" >> "$log_file_path"; exit 1; }

echo "[INFO] Cloning: |$github_url| into |$id|" >> "$log_file_path"
sudo git clone $github_url $id
cd "$base_repositories/$id"
echo "[INFO] Checkout |$branch| branch" >> "$log_file_path"
sudo git checkout "$branch"
echo "[INFO] Pull" >> "$log_file_path"
sudo git pull
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"

# Initialize variables for docker actions
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
echo "[INFO] Current directory before building image: $(pwd)" >> "$log_file_path"
new_port=""
old_port=""
docker_line_1=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_1")
docker_line_2=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_2")
if [ -z "$docker_line_1" ]; then
    echo "[INFO] Currently no container found open on port $port_1" >> "$log_file_path"
else
  if [ "$debug" = "true" ]; then
    echo "[DEBUG] docker_line_1: $docker_line_1" >> "$log_file_path";
  fi
  current_name_1=$(echo "$docker_line_1" | awk -F ' || ' '{print $1}')
  current_port_1=$(echo "$docker_line_1" | awk -F '[->,:]' '{print $3}')
  new_port="$port_2"
  old_port="$port_1"
  echo "[INFO] Currently $current_name_1 is running on $current_port_1" >> "$log_file_path"
fi

if [ -z "$docker_line_2" ]; then
    echo "[INFO] Currently no container found open on port $port_2" >> "$log_file_path"
else
  if [ "$debug" = "true" ]; then echo "[DEBUG] docker_line_2: $docker_line_2"; fi
  current_name_2=$(echo "$docker_line_2" | awk -F ' || ' '{print $1}')
  current_port_2=$(echo "$docker_line_2" | awk -F '[->,:]' '{print $3}')
  new_port="$port_1"
  old_port="$port_2"
  echo "[INFO] Currently $current_name_2 is running on $current_port_2" >> "$log_file_path"
fi


if [ -z "$docker_line_1" ] && [ -z "$docker_line_2" ]; then
  echo "[INFO] It will be first deployment for $id" >> "$log_file_path"
  is_first_deployment="true"
  new_port="$port_1"
fi

if [ -n "$docker_line_1" ] && [ -n "$docker_line_2" ]; then
  echo "[ERROR] Both port_1 ($current_port_1) and port_2 ($current_port_2) are currently used" >> "$log_file_path"
  exit 1
fi

if [ -n "$docker_line_1" ] && [ "$current_name_1" != "container-$id-$port_1" ]; then
  echo "[ERROR] docker_line: |$docker_line_1|" >> "$log_file_path"
  echo "[ERROR] $port_1 is not used by a $id container. Stopping deployment by safety" >> "$log_file_path"
  exit 1
fi

if [ -n "$docker_line_2" ] && [ "$current_name_2" != "container-$id-$port_2" ]; then
  echo "[ERROR] $port_1 is not used by a $id container. Stopping deployment by safety" >> "$log_file_path"
  exit 1
fi
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"

# Docker actions
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
new_image_name="image-$id-$new_port"
old_image_name="image-$id-$old_port"
new_container_name="container-$id-$new_port"
old_container_name="container-$id-$old_port"
echo "[INFO] new image |$new_image_name|" >> "$log_file_path"
echo "[INFO] old_container_name |$old_container_name|" >> "$log_file_path"

echo "[INFO] Building new image |$new_image_name|" >> "$log_file_path"
sudo docker build -t "$new_image_name" . # add the tag commit ?
# need to retreive the port of the Dockerfile
echo "[INFO] Running new |$new_container_name| on |$new_port| (using docker port |$docker_port|)" >> "$log_file_path"
sudo docker run --name "$new_container_name" -d -p "$new_port:$docker_port" "$new_image_name"
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"

# Update nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
path_nginx_file="$base_nginx_sites/$id"
current_proxy_pass=$(grep "proxy_pass" "$path_nginx_file" | awk -F 'http://localhost:' '{print "http://localhost:"$2}')

# Check if a proxy_pass was found
if [ -z "$current_proxy_pass" ]; then
  echo "[ERROR] No proxy_pass found in the nginx conf" >> "$log_file_path"
  exit 1
else
  echo "[INFO] The current proxy_pass is: $current_proxy_pass" >> "$log_file_path"
fi

if [ "$debug" = "true" ]; then echo "[DEBUG] before grep : |$current_proxy_pass|$old_port|"; fi
# Check if the string contains the substring
if [ "$is_first_deployment" != "true" ] && echo "$current_proxy_pass" | grep -q "$old_port"; then
  echo "[INFO] The proxy_pass will be edit" >> "$log_file_path"
elif [ "$first_deployment" != "true" ]; then
  echo "[ERROR] The current proxy pass ($current_proxy_pass) does not contain the old port ($old_port)" >> "$log_file_path"
  exit 1
else
 echo "[INFO] First deployment, will not change old_port" >> "$log_file_path"
fi

if [ "$is_first_deployment" != "true" ]; then
  echo "[INFO] Replacing old_port to new_port into nginx file" >> "$log_file_path"
  sudo sed -i "s|$old_port|$new_port|g" "$path_nginx_file"
fi

# Restart nginx service
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx start at $now" >> "$log_file_path"
sudo systemctl restart nginx
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] Restarting nginx finished at $now" >> "$log_file_path"
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"


# Delete old docker (if running (not first time))
now=$(date +"%Y-%m-%d %H:%M:%S")
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
echo "[INFO] Kill, remove old container (|$old_container_name|) and remove old image (|$old_image_name|)" >> "$log_file_path"
if [ "$is_first_deployment" != "true" ]; then
   sudo docker kill "$old_container_name"
   sudo docker rm "$old_container_name"
   sudo docker image rm "$old_image_name" -f
else
  echo "[INFO] First deployment, will not delete old container/image" >> "$log_file_path"
fi
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"; echo "" >> "$log_file_path"

# Clean repository
echo "[INFO] ---------------------$now--------------------------" >> "$log_file_path"
echo "[INFO] Delete repository folder (|$base_repositories/$id|)" >> "$log_file_path"
sudo rm -rf "$base_repositories/$id"
echo "[INFO] -----------------------------------------------------" >> "$log_file_path"

echo "flip-host.sh finished, logs available in $base_logs"

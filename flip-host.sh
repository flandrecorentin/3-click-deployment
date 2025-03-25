#!/bin/bash

# Init
base_logs='/3-click-deployment/logs/'
base_repositories='/3-click-deployment/repositories/'
echo "$base_logs"
echo "$base_repositories"

# Prerequisites
# sudo apt install jq
# install jq, nginx, certbot

# Read JSON file
json_data=$(cat config.json)
  echo "-----------------------------------------------------"

# Loop through each object in the array
for row in $(echo $json_data | jq -c '.[]'); do
  id=$(echo $row | jq -r '.id')
  github_url=$(echo $row | jq -r '.github_url')
  branch=$(echo $row | jq -r '.branch')
  dns=$(echo $row | jq -r '.dns')
  port_1=$(echo $row | jq -r '.port_1')
  port_2=$(echo $row | jq -r '.port_2')
  docker_port=$(echo $row | jq -r '.docker_port')

  # Print the extracted values
  echo "GitHub URL: $github_url"
  echo "Branch: $branch"
  echo "DNS: $dns"
  echo "-----------------------------------------------------"

  cd "$base_repositories" || { echo "Failed to change directory to $folder_path"; exit 1; }
  echo "Current directory before clone: $(pwd)"

  sudo git clone $github_url $id
  cd "$base_repositories/$id"
  echo "Current directory before building image: $(pwd)"
  sudo git checkout main
  sudo git pull

  # Manage new / old ports
  new_port=""
  old_port=""
  docker_line_1=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_1")
  docker_line_2=$(sudo docker ps --format "{{.Names}} || {{.Ports}}" | grep "$port_2")
  if [ -z "$docker_line_1" ]; then
      echo "Currently no container found open on port $port_1"
  else
    echo "$docker_line_1"
    current_name_1=$(echo "$docker_line_1" | awk -F ' || ' '{print $1}')
    current_port_1=$(echo "$docker_line_1" | awk -F '[->,:]' '{print $3}')
    new_port="$port_2"
    old_port="$port_1"
    echo "Currently $current_name_1 is running on $current_port_1"
  fi

  if [ -z "$docker_line_2" ]; then
      echo "Currently no container found open on port $port_2"
  else
    echo "$docker_line_2"
    current_name_2=$(echo "$docker_line_2" | awk -F ' || ' '{print $1}')
    current_port_2=$(echo "$docker_line_2" | awk -F '[->,:]' '{print $3}')
    new_port="$port_1"
    old_port="$port_2"
    echo "$Currently $current_name_2 is running on $current_port_2"
  fi


  if [ -z "$docker_line_1" ] && [ -z "$docker_line_2" ]; then
    echo "It will be first deployment for $id"
    is_first_deployment="true"
    new_port="$port_1"
  fi

  if [ -n "$docker_line_1" ] && [ -n "$docker_line_2" ]; then
    echo "Both port_1 ($current_port_1) and port_2 ($current_port_2) are currently used"
    echo "Stopping deployment"
    exit 1
  fi

    if [ -n "$docker_line_1" ] && [ "$current_name_1" != "container-$id-$port_1" ]; then
      echo "$docker_line_1"
      echo "$port_1 is not used by a $id container"
      echo "Stopping deployment by safety"
      exit 1
    fi

    if [ -n "$docker_line_2" ] && [ "$current_name_2" != "container-$id-$port_2" ]; then
      echo "$port_1 is not used by a $id container"
      echo "Stopping deployment by safety"
      exit 1
    fi

    # Docker command
    new_image_name="image-portfolio-$new_port"
    old_image_name="image-portfolio-$old_port"
    new_container_name="container-portfolio-$new_port"
    old_container_name="container-portfolio-$old_port"
    echo "new image |$new_image_name|"
    echo "old_container_name |$old_container_name|"


    sudo docker build -t "$new_image_name" . # add the tag commit ?
    # need to retreive the port of the Dockerfile
    sudo docker run --name "$new_container_name" -d -p "$new_port:$docker_port" "$new_image_name"

    # Restart nginx
    # sudo systemctl restart nginx
    # switch nginx in /etc/nginx/sites-enabled

    # Delete old docker (if running (not first time))
    if [ "$is_first_deployment" != "true" ]; then
       sudo docker kill "$old_container_name"
       sudo docker rm "$old_container_name"
       sudo docker image rm "$old_image_name" -f
    fi

    # Clean repository
    sudo rm -rf "$base_repositories/$id"
  done

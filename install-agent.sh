#!/bin/bash

sudo apt update

# Install jq
sudo apt install -y jq

# Install and start nginx
sudo apt install nginx
sudo service nginx restart

# Install certbot
sudo apt install snapd
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Install python
sudo apt install python3

# Install github cli
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y
sudo touch .github
echo 'token=' > .github
# YOU NEED TO ADD YOUR GITHUB TOKEN IN THE /3-click-deployment/.github FILE
# GO TO https://github.com/settings/tokens TO CREATE YOUR TOKEN

base_logs='/3-click-deployment/logs/'
path_logs_cron='/3-click-deployment/logs/cron'
base_repositories='/3-click-deployment/repositories/'
path_cron='/3-click-deployment/cron.py'

sudo mkdir "$base_logs"
sudo mkdir "$base_repositories"
sudo touch config.json
sudo touch "$path_logs_cron"

# Add to cron.py to cron file
python_path=$(which python3)
NEW_CRON_JOB="* * * * * $python_path $path_cron"
(crontab -l ; echo "$NEW_CRON_JOB") | crontab -
NEW_CRON_JOB="0 0 * * 1 rm $path_logs_cron && touch $path_logs_cron"
(crontab -l ; echo "$NEW_CRON_JOB") | crontab -

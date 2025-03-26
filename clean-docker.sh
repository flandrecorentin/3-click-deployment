#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Delete: $0 <argument1> on port <argument2>"
    exit 1
fi

# Assign arguments to variables
arg1=$1
arg2=$2

sudo docker kill "container-$arg1-$arg2"
sudo docker rm "container-$arg1-$arg2"
sudo docker image rm "image-$arg1-$arg2" -f

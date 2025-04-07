# 3-click-deployment

Auto deployment and monitor in **3 clicks** personal instances, VPS, etc **at 0 cost** with a **<1s downtime** by deployment.

3-click-deployment is an agent that

### How to setup for a project 

1. Make your project containerisable through a **Dockerfile** or a **docker-compose.yaml** .
2. Define a [config](#config) that suits your needs.

## Installation

Install github CLI on your host :

[Official Github documentation - Install gh](https://github.com/cli/cli?tab=readme-ov-file#installation)

[Official Github documentation - Install gh on **Linux**](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)

## Config

```{json}
{
    "name" : "site-dev-1",
    "repository" : "https://github.com/username/repository.github.io.git",
    "url" : "dev.username.com",
    "branch" : "dev",
    "pull_time_minute" : 1
},
{
    "name" : "site-prod",
    "repository" : "https://github.com/username/repository.github.io.git",
    "url" : "username.com",
    "branch" : "main",
    "pull_time_minute" : 60
}
```

# Features

- Logs into /3-click-deployment/logs/
- Parameterize flip-host.sh (at least for config id)
- Create a validator script for config file
- Default 502 page redirection
- Create initialize script
- Add example account (maybe the same as 502 page redirection)

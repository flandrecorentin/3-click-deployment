# 3-click-deployment

Auto deployment and monitor in **3 clicks** personal instances, VPS, etc **at 0 cost** with a **<3s downtime** by deployment.

3-click-deployment is an agent that

## Scripts

| Script           | Argument                                          | Description | Example Usage                                |
|------------------|---------------------------------------------------|-------------|----------------------------------------------|
| clean-docker.sh  | 1. id-host <br/> 2. port                          |             | bash clean-docker 3-click-deployment-ui 8111 |
| flip-host.sh     | 1. id-host                                        |             | bash flip-host.sh  3-click-deployment-ui     |
| init-host.sh     | 1_optional. config-filename.json <br/> 2. id-host |             | bash init-host.sh  3-click-deployment-ui     |
| install-agent.sh |                                                   |             | bash install-agent.sh                        |
| print-docker.sh  |                                                   |             | bash print-docker.sh                         |


## How to setup a new host

1. Make your project containerisable through a **Dockerfile** or a **docker-compose.yaml** .
2. Define a [config](#config) that suits your needs.
3. Initialize your host 
   - with default config.json filename ```sudo bash init-host.sh <id-host>```
   - custom config.json ```sudo bash init-host.sh <config_path.json> <id-host>```

## Installation

After ssh to your Linux OS (similar to ```sudo ssh -i <private.key> <user>@144.24.203.242```). Give your root rights to install requirements

```{bash}
sudo su
```

Clone 3-click-deployment repository
```{bash}
cd /
git clone https://github.com/flandrecorentin/3-click-deployment.git
```

Install necessary tools and cli
```{bash}
bash install-agent.sh
```

If installation of gh cli (GitHub CLI), check the [Official Github documentation - Install gh](https://github.com/cli/cli?tab=readme-ov-file#installation)

To make the agent able to request your repositories, you need to add your github token (see https://github.com/settings/tokens to create one) into the _/3-click-deployment/.github_ file

```{bash}
GITHUB_TOKEN=<YOUR_GITHUB_TOKEN>
sed -i "s|token=|token=$GITHUB_TOKEN|g" "/3-click-deployment/.github"
```

## Config

The default config filename is _config.json_

```{json}
[
    {
        "id" : "3-click-deployment-ui",
        "github_url" : "https://github.com/flandrecorentin/3-click-deployment-ui.git",
        "github_repository" : "3-click-deployment-ui",
        "github_owner" : "flandrecorentin",
        "github_branch" : "main",
        "dns" : "3clickdeployment.flandrecorentin.com",
        "port_1" : "8111",
        "port_2" : "8112",
        "docker_port" : "80"
    },
    {
        /** another config **/
    }
]
```

# Features to dev

- Logs into /3-click-deployment/logs/
- Create a validator script for config file
- Default 502 page redirection (find where is the nginx?)
- Add example account (maybe the same as 502 page redirection)
- correct user/whoiam 
- multiple github tokens (multi github_owner)

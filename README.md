# OpenFlight Bootcamp Manager

This repository provides some additional wrappers around OpenFlight's deployment tools (namely the [Cluster Builder](https://github.com/openflighthpc/openflight-compute-cluster-builder) and [Ansible Playbook](https://github.com/openflighthpc/openflight-ansible-playbook)) in order to streamline the process of hosting bootcamp sessions. 

The main functionality of this tool is to:
- Deploy clusters for bootcamps in bulk
- Create a website for the bootcamp 
  - User/password protected access
  - Information screen on each available research environment
  - Embedded VNC/terminal sessions
  - Bootcamp instructions

## Creating a bootcamp session

```
bin/create-bootcamp --config 'aws/eu-west-1-x86' \
                    --environments 20 \
                    --modules base,hadoop,jupyter \
                    --name MyBootcampSession
```

Possible arguments:
- `--name` - The name to assign to this bootcamp session, this allows for multiple bootcamp sessions to be launched and kept separately
- `--config` - This is the name of the deployment configuration to use in for `openflight-compute-cluster-builder`, for more information see the [configuration documentation](https://github.com/openflighthpc/openflight-compute-cluster-builder#cluster-using-alternative-configuration). **If multiple configurations are provided (comma separated) then the script will iterate through them whilst deploying, this is useful for deploying a bootcamp that utilises multiple cloud providers or regions**
- `--environments` - Number of research environments to deploy
- `--modules` - The modules to include in the bootcamp
- `--webroot` - The directory to install the website to (by default this is `site/NAME`)

## Modules

Components of a bootcamp workflow are broken down into "modules". A module can:
- Set ansible variables (for enabling/disabling certain customisations for deployment)
- Provide documentation for the webserver

See `modules/mymodule.yaml.example` for more information.

Example Module with all possible things

```
meta:
  description: A Short Description of Module 
ansible:
site:
  lesson: true # Create a lesson page of documentation, if false the module will not be visibly present in the site (default: true)
```

## Webserver

The webserver is launched with `bin/start-server`. This can ultimately be turned into a systemd service for further integration & support. 

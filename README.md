# OpenFlight Bootcamp Manager

This repository provides some additional wrappers around OpenFlight's deployment tools (namely the [Cluster Builder](https://github.com/openflighthpc/openflight-compute-cluster-builder) and [Ansible Playbook](https://github.com/openflighthpc/openflight-ansible-playbook)) in order to streamline the process of hosting bootcamp sessions. 

The main functionality of this tool is to:
- Deploy clusters for bootcamps in bulk
- Create a website for the bootcamp 
  - User/password protected access
  - Information screen on each available research environment
  - Embedded VNC/terminal sessions
  - ~~Bootcamp instructions~~

## Creating a bootcamp session

```
bin/create-bootcamp --config 'aws/eu-west-1-x86' \
                    --environments 20 \
                    --name MyBootcampSession
```

Possible arguments:
- `--name` - The name to assign to this bootcamp session, this allows for multiple bootcamp sessions to be launched and kept separately
- `--config` - This is the name of the deployment configuration to use in for `openflight-compute-cluster-builder`, for more information see the [configuration documentation](https://github.com/openflighthpc/openflight-compute-cluster-builder#cluster-using-alternative-configuration). **If multiple configurations are provided (comma separated) then the script will iterate through them whilst deploying, this is useful for deploying a bootcamp that utilises multiple cloud providers or regions**
- `--environments` - Number of research environments to deploy
- ~~`--modules` - The modules to include in the bootcamp~~
- `--webroot` - The directory to install the website to (by default this is `site/NAME`)

## Adding a Separate Cluster to an Existing Session

Sometimes when launching multiple research environments for a bootcamp there can be unexpected issues due to cloud resources coming up at slightly different rates or having slight network issues. This can ultimately lead to the playbook not running and the cluster not being appropriately customised and configured for the session.

In the event that a cluster doesn't come up, the following instructions describe how to add it into the VNC bootcamp site.

- Delete the failed cluster from the upstream cloud provider

- Recreate the cluster using the config, name and password that are logged in `sessions/SESSIONNAME/CLUSTERNAME.yaml` (note: this example is for a cluster that is launched with password auth, not SSH - [more information](https://github.com/openflighthpc/openflight-compute-cluster-builder#cluster-using-password-instead-of-ssh-key))
    ```
    CONFIG="path/to/config" bash build-cluster.sh CLUSTERNAME PASSWORD
    ```

- Launch the console & desktop VNC sessions
    ```
    ssh -o StrictHostKeyChecking=no GATEWAYIP 'su - flight /opt/flight/bin/flight desktop start xterm'
    ssh -o StrictHostKeyChecking=no GATEWAYIP 'su - flight /opt/flight/bin/flight desktop start gnome'
    ```

- Update the VNC session passwords (and potentially ports depending on the config) in `sessions/SESSIONNAME/CLUSTERNAME.yaml`

- Update the IP (and potentially ports) in the token file for the VNC sessions in `site/SESSIONNAME/tokens.list`

- Export the session information (which can be located in `sessions/SESSIONNAME/session.yaml`
    ```
    export NAME="SESSIONNAME"
    export WEBROOT="site/SESSIONNAME/"
    export SESSIONDIR="sessions/SESSIONNAME"
    export COUNT="X" # X being the number of environments
    ```

- Rerun the site generator
    ```
    ruby bin/generate-site.rb
    ```

# Not Currently Implemented

The below documentation is a rough outline of further features to implement.

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

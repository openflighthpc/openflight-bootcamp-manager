#!/bin/bash

# Initial variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. >/dev/null 2>&1 && pwd )"

# Functions

function usage() {
cat << EOF
NAME
    create-bootcamp.sh - Deploy multiple OpenFlight Research Environments and manage them via web

SYNOPSIS
    create-bootcamp.sh --config 'aws/eu-west-1-x86' \\
                       --environments 20 \\
                       --modules vnc,hadoop,jupyter \\
                       --name MyBootcampSession

REQUIRED ARGUMENTS
  -c NAME1,NAME2, --config NAME1,NAME2
            Names of the various configurations within lib/openflight-compute-cluster-builder/configs/
            to be used for deployment (at least one is required, multiple should be comman-separated)

  -e INT, --environments INT
            The number of research environments to deploy

  -m MODULE1,MODULE2, --modules MODULE1,MODULE2
            Names of modules available in modules/ to be applied to the bootcamp (this input is treated
            as the "lesson order") 

  -n NAME, --name NAME
            The name to give to this bootcamp session

OPTIONAL ARGUMENTS
  -h,--help
            Displays this page and exits

  -w PATH, --webroot PATH
            Specifies the location to output generated HTML files to
EOF
}

# Parse arguments
while [[ $# -gt 0 ]] ; do
    key="$1"

    case $key in
        -c|--config)
            CONFIG="$2"
            shift && shift
            ;;
        -e|--environment)
            export COUNT="$2"
            shift && shift
            ;;
#        -m|--modules)
#            MODULES="$2"
#            shift && shift
#            ;;
        -n|--name)
            export NAME="$2"
            shift && shift
            ;;
        -w|--webroot)
            WEBROOT="$2"
            shift && shift
            ;;
        -h|--help|*)
            usage
            exit
            ;;
    esac
done

# Check presence of args
#if [[ -z $CONFIG || -z $COUNT || -z $MODULES || -z $NAME ]] ; then
if [[ -z $CONFIG || -z $COUNT || -z $NAME ]] ; then
    echo "Missing required arguments!"
    echo "Ensure that config, environment, modules and name are set at the very least"
    echo
    usage
    exit 1
fi

# Verify no conflicting arguments

## Ensure config exists in submoduled builder
for config in $(echo "$CONFIG" | sed 's/,/ /g') ; do
    path=$DIR/lib/builder/configs/$config.sh
    if [[ ! -f $path ]] ; then
        echo "$path: No such file or directory"
        exit 1
    fi
done

## Check that environments count is an integer
re='^[0-9+$]'
if ! [[ $COUNT =~ $re ]] ; then
    echo "Environment needs to be an integer, currently it's '$COUNT'"
    exit 1
fi

## Ensure modules exist in modules dir
#for module in $(echo "$MODULES" |sed 's/,/ /g') ; do
#    path="$DIR/modules/$module.yaml"
#    if [[ ! -f $path ]] ; then 
#        echo "$path: No such file or directory"
#        exit 1
#    fi
#done

## Ensure name isn't an existing bootcamp session
export SESSIONDIR="$DIR/sessions/$NAME/"
SESSIONCONF="$SESSIONDIR/session.yaml"
if [[ -f $SESSIONCONF ]] ; then
    echo "A bootcamp session called $NAME already exists ($SESSIONCONF)"
    exit 1
fi

# Confirm bootcamp creation
echo "Bootcamp Session Info"
echo "---------------------"
echo "Session Name: $NAME"
echo "Number of Environments: $COUNT"
echo "Configurations to Use: $CONFIG"
#echo "Modules to Use: $MODULES"
echo 
read -r -p "Continue with deployment? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        ;;
    *)
        echo "Exiting on user input..."
        exit 1
        ;;
esac

# Some variables
export CONFIGLIST="$(echo "$CONFIG" |tr ',' '\n')"
export CONFIGCOUNT="$(echo "$CONFIGLIST" |wc -l)"
export CONFIGNUMBER=1 # incremented to loop through configs

#MODULECOUNT="$(echo "$MODULES" |tr ',' '\n' |wc -l)"

SESSIONLOGDIR="$DIR/log/$NAME"

WEBROOT="$DIR/site/$NAME" # TODO: Use the webroot arg here
TOKENFILE="$WEBROOT/tokens.list"

# Create directories
mkdir -p $SESSIONDIR $SESSIONLOGDIR $WEBROOT

# Log session info
echo "name: $NAME" > $SESSIONCONF
echo "environments: $COUNT" >> $SESSIONCONF
echo "configurations: $CONFIG" >> $SESSIONCONF
#echo "modules: $MODULES" >> $SESSIONCONF

# Function for cluster deployment to allow for loop to easily background
function deploy_cluster() {
    clustername="group$number"
    clusterlog="$SESSIONLOGDIR/$clustername.log"
    clusterconf="$SESSIONDIR/$clustername.yaml"
    echo "$clustername: Starting deployment"

    # Determine which config to use
    myconfig=$(echo "$CONFIGLIST" |sed "${CONFIGNUMBER}q;d")

    # Set a random alphanumeric password
    password="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"

    echo "name: $clustername" >> $clusterconf
    echo "config: $myconfig" >> $clusterconf
    echo "password: $password" >> $clusterconf

    CONFIG="$myconfig" bash lib/builder/build-cluster.sh $clustername $password >> $clusterlog 2>&1
    ip="$(tail -1 $clusterlog |awk '{print $11}')"
    echo "ip: $ip" >> $clusterconf

    # Add VNC to session configuration info
    echo "vnc:" >> $clusterconf

    # Launch xterm desktop
    console=$(ssh -o StrictHostKeyChecking=no $ip 'su - flight /opt/flight/bin/flight desktop start xterm' |grep -v '^Last login')
    port=$(echo "$console" |grep '^Port' | awk '{print $2}')
    pass=$(echo "$console" |grep '^Password' |awk '{print $2}')
    echo "$clustername-console: $ip:$port" >> $TOKENFILE
    echo "  console:" >> $clusterconf
    echo "    port: $port" >> $clusterconf
    echo "    pass: $pass" >> $clusterconf

    # Launch gnome desktop
    desktop=$(ssh -o StrictHostKeyChecking=no $ip 'su - flight /opt/flight/bin/flight desktop start gnome' |grep -v '^Last login')
    port=$(echo "$desktop" |grep '^Port' | awk '{print $2}')
    pass=$(echo "$desktop" |grep '^Password' |awk '{print $2}')
    echo "$clustername-desktop: $ip:$port" >> $TOKENFILE
    echo "  desktop:" >> $clusterconf
    echo "    port: $port" >> $clusterconf
    echo "    pass: $pass" >> $clusterconf

    echo "$clustername: Finished deployment"
}

# Deploy clusters in parallel
for number in $(seq $COUNT) ; do 
    deploy_cluster &

    # Increment CONFIGNUMBER
    if [[ $CONFIGCOUNT != 1 ]] ; then
        if [[ $CONFIGNUMBER -ge $CONFIGCOUNT ]] ; then
            CONFIGNUMBER=1
        else
            CONFIGNUMBER=$((CONFIGNUMBER + 1))
        fi
    fi
    sleep 5
done

echo "Waiting for clusters to deploy"
wait

echo "Generating website to $WEBROOT"
ruby bin/generate-site.rb
echo "Done."

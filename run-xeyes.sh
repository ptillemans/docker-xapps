#!/bin/bash

get_docker_ip() {

    if [ "$(uname)" == "Darwin" ]
    then
        if ipconfig getifaddr en1
        then
            echo `ipconfig getifaddr en1`
        else
            echo `ipconfig getifaddr en0`
        fi
    fi

    if [ "$(uname -s)" == "Linux" ]
    then
        echo `ip addr show docker0 | grep 'inet ' | \
    cut -d ' ' -f6 | cut -d '/' -f1`
    fi
}

get_x_endpoint() {
    if [ "$SSH_CLIENT" == "" ]
    then
        echo UNIX-CLIENT:\"/tmp/.X11-unix/X0\"
    else
        echo TCP:localhost:$1
    fi
}

# find X screen number and corresponding port
DN=`echo $DISPLAY | cut -d ':' -f2 | cut -d '.' -f1`
DP=$((6000 + $DN))

# get authorization cookie
COOKIE=`xauth list :$DN | cut -d ' ' -f3-`

# find the docker ip number for the host
DOCKER_IP=`get_docker_ip`

# start tunnel
socat TCP-LISTEN:$DP,bind=$DOCKER_IP,reuseaddr,fork \
      `get_x_endpoint $DP` &

SOCAT_PID=$!

# launch the container with parameters
sudo docker run -ti \
     -e COOKIE="$COOKIE" -e DISPLAY="$DOCKER_IP:$DN" \
     $*

# stop tunnel
kill $SOCAT_PID

killall socat

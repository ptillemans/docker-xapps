
SOCKET_MOUNT=""

if [ "$(uname)" == "Darwin" ]
then
    if ipconfig getifaddr en1
    then
        C_DISPLAY=`ipconfig getifaddr en1`:0
    else
        C_DISPLAY=`ipconfig getifaddr en0`:0
    fi
    socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\" &
fi

if [ "$(uname -s)" == "Linux" ]
then
    C_DISPLAY=":0"
    SOCKET_MOUNT="-v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0"
fi


docker run -v $HOME/.Xauthority:/root/.Xauthority:ro \
       $SOCKET_MOUNT \
       -e XAUTHORITY=/root/.Xauthority \
       -e DISPLAY=$C_DISPLAY -ti xeyes

killall socat

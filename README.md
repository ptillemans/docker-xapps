Sample Docker X-Client
======================

As client we use the ever useful *xeyes* app to make sure the Xserver
and XClient are talking to each other.

Create the client
-----------------

Run

    $ ./build

to create the container. It will be tagged with *xeyes*


Prepare the environment
-----------------------

On Linux if you are in the GUI environment no other steps are
needed. If you are doing weird stuff with virtual X servers on other
locations than *:0* you have to adjust the script accordingly.

On the Mac install XQuartz:

    $ brew cask install xquartz

run it with

    $ Xquartz

Now open a *new* terminal to get the *DISPLAY* variable in the
environment. Or use the one started by XQuartz if you start it the old
fashioned way (i.e. with a mouse).

    ~ » echo $DISPLAY
    /private/tmp/com.apple.launchd.0RGpvITReU/org.macosforge.xquartz:0

the actual path will be different as the gobbledigook after launchd is
random generated. If you see this, you are ready to launch the client.

Run the client
--------------

Run the script:


    $ ./run-xeyes.sh xapps xeyes

and you should see the googly eyes, probably in the left upper corner
of the screen.

Since this script is more a technology sample it takes the following
parameters:

    run-xeyes.sh <image-name> <command> [<parameters>*]

Inside the container the apps are launched with an entrypoint script
which adds the authorization to the .Xauthority database:

    #!/bin/bash

    xauth add $DISPLAY $COOKIE

    CMD=$1
    shift

    echo running $CMD $*

    $CMD $*


Behind the scenes
-----------------

An Xclient essentially needs 2 things:

 - a socket connection to the server
 - an .Xauthority file

## SSH connections

By far the easiest way to accomplish this is using *ssh -X*. This will
create a tunnel and add the cookie to the .Xauthority file and
essentially things just work provided the 2 hosts are more or less
sanely setup.

This is the gold standard.

## Unix Sockets

This is the way used here for Linux. The */tmp/.X11-unix/X0* file is
actually a *unix socket* through which the clients and the server
communicate as if it was a network connection (it is actually the
other way around, but that is ancient history).

Here this socket is bind-mounted in the correct place where the
Xclients expect it by default, i.e. for display *:0*.

The *.Xauthority* file is bind mounted to the root home folder, where
the apps in a container expect them to be when they launch. Docker by
default deals with all the permission and ownership weirdness and this
just works.

This method should theoretically work on a Mac with native docker too,
but it doesn't at the moment for one reason or another.

## TCP sockets

For the Mac, for one reason or another, the unix socket trick does not
work (see
[this post in the docker for Mac forum](https://forums.docker.com/t/cant-connect-to-host-listening-unix-socket-from-container-vm/15526)
. tldr; docker.sock is a special case and the rest is on the roadmap
). So we tunnel it through a TCP socket with the swiss army knife of
networking tools : *socat*

    $ socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$DISPLAY\"

It essentially connects to the UNIX socket and forwards all traffic
back and forth. This saves us setting up the Xserver to listen on the
network which is fraught with dangers and complications. This is
clean, connects to the unix socket which also avoids putzing around
with the *xhost* program. None of this is needed with this solution.

Note that this solution will enable all Xclients to do things to your
X-display, but since on a Mac this is just an application, and the
macs are only dev machines anyway, and we're only running this while
playing with X clients in containers, and you still need to present a
valid .Xauthority file which you can only get if you already pwned the
Mac, I think the risk is acceptable.

Note that this method would work just as well on a Linux box, with the
added advantage that we could actually bind to the *docker0* interface
and not have to expose a port to the outside world.

## Advanced XAuth magic : remote containers

In order to forward a connection from a container running on a remote
host connected to with *ssh -X* we need to do more advanced
magic. We'll assume that the remote machine hosting the containers is
a linux box. This should be by far the most common case.

The ssh connection actually forwards the magic cookie and adds it to
the remote .Xauthority file and the listens on a port for the Xclients
to connect to on localhost. However the containers have no access to
the ports on localhost of the host.

First lets figure out on which ip address the host has on the docker
network where the containers are attached to :

    pti@mdp1-test:~$ ip addr show docker0
    3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP
        link/ether 02:42:86:55:62:32 brd ff:ff:ff:ff:ff:ff
        inet 172.17.0.1/16 scope global docker0
           valid_lft forever preferred_lft forever
        inet6 fe80::42:86ff:fe55:6232/64 scope link
           valid_lft forever preferred_lft forever

from the *inet* line we see that it listens on 172.17.0.1. So we'll
have the container use that address and connect the ssh socket
to a new port where we'll be listening for connections. We'll be
listening on port 6000 which corresponds to screen *:0*

    pti@mdp1-test:~$ DOCKER_IP=`ip addr show docker0 | grep 'inet ' | \
                                cut -d ' ' -f6 | cut -d '/' -f1`

Now we have the ip address in a variable *DOCKER_IP*

    pti@mdp1-test:~$ socat TCP-LISTEN:6000,bind=$DOCKER_IP,reuseaddr,fork \
                           TCP:localhost:6011 &

We launch this in the background

    pti@mdp1-test:~$ DISPLAY="$DOCKER_IP:0"
    pti@mdp1-test:~$ COOKIE=`xauth list | cut -d ' ' -f3-`
    pti@mdp1-test:~$ sudo docker run -ti \
        -e COOKIE="$COOKIE" -e DISPLAY="$DISPLAY" \
        xeyes /bin/bash
    root@9443f36a5083:/# xauth add $DISPLAY $COOKIE
    root@9443f36a5083:/# xeyes


Notes:

- this only allows 1 xclient running at the same time. It would be
  better to use the same port on the DOCKER_IP to for the tunnel. The
  ssh-daemon will ensure no conflicts occur and this limitation is
  lifted.

- Do not forget to terminate the socat process after the container has
  finished. It wont hurt, but it is ugly and will throw errors the
  next time it is started

## Expansion to multiple x-clients on remote hosts

First let's deal with the risk of binding to the same port. SSH has
the same issue, and they already solved this, so let's piggyback on
their solution. We'll derive the port number to bind to from the X
screen number.

    pti@mdp1-test:~$ DN=`echo $DISPLAY | cut -d ':' -f2 | cut -d '.' -f1`
    pti@mdp1-test:~$ DP=$((6000 + $DN))
    pti@mdp1-test:~$ echo $DP
    6013

This gives us a nice port number to bind to.

The previous solution also assumed that the .Xauthority database only
has a single entry. This is rather optimistic so let's improve on
that:

    pti@mdp1-test:~$ xauth list :$DN
    mdp1-test.sensors.elex.be/unix:13  MIT-MAGIC-COOKIE-1  d8b1...
    pti@mdp1-test:~$ COOKIE=`xauth list :$DN | cut -d ' ' -f3-`
    pti@mdp1-test:~$ echo $COOKIE
    MIT-MAGIC-COOKIE-1 d8b1...

This isolates the entry added by the current *ssh -X* session from the
Xauthority database and store it in the COOKIE variable.

To forward the connection the socat statement now becomes

    pti@mdp1-test:~$ socat TCP-LISTEN:$DP,bind=$DOCKER_IP,reuseaddr,fork \
                           TCP:localhost:$DP &

This allows every *ssh -X* session to be forwarded to its
corresponding container(s).

To launch the container use

    pti@mdp1-test:~$ sudo docker run -ti \
        -e COOKIE="$COOKIE" -e DISPLAY="$DOCKER_IP:$DN" \
        xeyes /bin/bash
    root@9443f36a5083:/# xauth add $DISPLAY $COOKIE
    root@9443f36a5083:/# xeyes


In a script this becomes

    #!/bin/bash

    # find X screen number and corresponding port
    DN=`echo $DISPLAY | cut -d ':' -f2 | cut -d '.' -f1`
    DP=$((6000 + $DN))

    # get authorization cookie
    COOKIE=`xauth list :$DN | cut -d ' ' -f3-`

    # find the docker ip number for the host
    DOCKER_IP=`ip addr show docker0 | grep 'inet ' | \
               cut -d ' ' -f6 | cut -d '/' -f1`

    # start tunnel
    socat TCP-LISTEN:$DP,bind=$DOCKER_IP,reuseaddr,fork \
          TCP:localhost:$DP &

    SOCAT_PID=$!

    # launch the container with parameters
    sudo docker run -ti \
        -e COOKIE="$COOKIE" -e DISPLAY="$DOCKER_IP:$DN" \
        $*

    # stop tunnel
    kill $SOCAT_PID

The script in the repo adds support for the local case using the same
principle.

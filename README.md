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


    $ run-xeyes.sh

and you should see the googly eyes, probably in the left upper corner
of the screen.

Behind the scenes
-----------------

An Xclient essentially needs 2 things:

 - a socket connection to the server
 - an .Xauthority file

## SSH connections

By far the easiest way to accomplish this is using *ssh -X*. This will
create a tunnel and forward the .Xauthority file and essentially
things just work provided the 2 hosts are more or less sanely setup.

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
work (please prove me wrong! In theory this should work, or at least
it works for the docker unix socket.). So we tunnel it through a TCP socket
with the swiss army knife of networking tools : *socat*

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

Note that this method would work just as well on a Linux box.

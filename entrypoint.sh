#!/bin/bash

xauth add $DISPLAY $COOKIE

CMD=$1
shift

echo running $CMD $*

$CMD $*

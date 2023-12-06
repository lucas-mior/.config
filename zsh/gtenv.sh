#!/bin/sh

# gti-home environment variable (all platforms)
GTIHOME=/opt/GTI
export GTIHOME

# prepend $GTIHOME/bin to PATH
PATH=$GTIHOME/bin:$PATH
export PATH

# GTISOFT License Service setup . . . 
GTISOFT_LICENSE_FILE=27005@150.162.25.271
export GTISOFT_LICENSE_FILE
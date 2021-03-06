#!/bin/bash
# This shell script tested on OSX
# To run it successful, YOU NEED to instal dmd compiler for D lang
# grab D lang compiler at https://dlang.org

RELEASE_ARGS=(-O -wi -release -inline -boundscheck=off -m64 -mcpu=native)

for dFiles in $(ls | grep "\.d$")
do
 dmd "${RELEASE_ARGS[@]}" $dFiles arsd/{color,png}.d
 strip ${dFiles%.*}
done

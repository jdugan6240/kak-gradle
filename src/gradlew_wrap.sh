#!/usr/bin/sh

dir=$1
shift

$dir/gradlew $@
read -n 1 -p "Press any key to continue..." input

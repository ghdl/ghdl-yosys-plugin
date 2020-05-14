#!/bin/sh

topdir=../..
. $topdir/testenv.sh

#formal axis_squarer
run_symbiyosys axis_squarer.sby cover

clean
echo OK

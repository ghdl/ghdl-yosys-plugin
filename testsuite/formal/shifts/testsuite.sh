#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in lsl lsr asr; do
  formal "test_${f}"
done

clean

#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in abs lsl lsr asr; do
  formal "test_${f}"
done

clean
echo OK

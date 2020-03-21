#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in abs minmax lsl lsr asr; do
  formal "test_${f}"
done

clean
echo OK

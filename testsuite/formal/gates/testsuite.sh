#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in abs minmax pmux lsl lsr asr mod_rem; do
  formal "test_${f}"
done

clean
echo OK

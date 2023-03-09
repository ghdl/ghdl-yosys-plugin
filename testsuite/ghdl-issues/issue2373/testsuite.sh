#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_symbiyosys -fd work  async_test-plus.sby prove || true
if ! grep -q "BMC failed" work/engine_0/logfile.txt; then
    echo "failure expected"
    exit 1
fi

run_symbiyosys -fd work  async_test-star.sby prove || true
if ! grep -q "BMC failed" work/engine_0/logfile.txt; then
    echo "failure expected"
    exit 1
fi

clean
echo OK

#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_symbiyosys -fd work  async_test-0.sby prove

run_symbiyosys -fd work  async_test-1.sby prove || true
if ! grep -q "BMC failed" work/engine_0/logfile.txt; then
    echo "failure expected"
    exit 1
fi

run_symbiyosys -fd work  async_test-2.sby prove || true
if ! grep -q "BMC failed" work/engine_0/logfile.txt; then
    echo "failure expected"
    exit 1
fi

clean
echo OK

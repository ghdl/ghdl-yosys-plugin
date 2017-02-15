#!/bin/sh

for d in */; do
    if [ -f $d/testsuite.sh ]; then
        echo "############ $d"
        cd $d
        if ./testsuite.sh; then
            echo "OK"
        else
            echo "FAILED!"
            exit 1
        fi
        cd ..
    else
        echo "#### Skip $d (no testsuite.sh)"
    fi
done

echo "All tests are OK"
exit 0

#!/bin/sh

cd "$(dirname $0)"
. ../testenv.sh

for d in */; do
    if [ -f $d/testsuite.sh ]; then
        travis_start "test" "$d" "$ANSI_CYAN"
        cd $d
        if . ./testsuite.sh; then
            printf "${ANSI_GREEN}OK$ANSI_NOCOLOR\n"
        else
            printf "${ANSI_RED}FAILED!$ANSI_NOCOLOR\n"
            exit 1
        fi
        cd ..
        travis_finish "test"
    else
        printf "${ANSI_YELLOW}Skip $d (no testsuite.sh)$ANSI_NOCOLOR\n"
    fi
    clean
done

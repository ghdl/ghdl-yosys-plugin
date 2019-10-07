#!/usr/bin/env bash

cd "$(dirname $0)"
. ../utils.sh

for d in */; do
    if [ -f $d/testsuite.sh ]; then
        printf "${ANSI_CYAN}test $d ${ANSI_NOCOLOR}\n"
        cd $d
        if ./testsuite.sh; then
            printf "${ANSI_GREEN}OK$ANSI_NOCOLOR\n"
        else
            printf "${ANSI_RED}FAILED!$ANSI_NOCOLOR\n"
            exit 1
        fi
        cd ..
    else
        printf "${ANSI_YELLOW}Skip $d (no testsuite.sh)$ANSI_NOCOLOR\n"
    fi
done

printf "${ANSI_GREEN}All tests are OK$ANSI_NOCOLOR\n"
exit 0

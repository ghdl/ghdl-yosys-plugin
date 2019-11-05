#!/usr/bin/env bash

cd "$(dirname $0)"
. ../utils.sh

for d in */*/; do
    cd $d
    printf "${ANSI_CYAN}test $d ${ANSI_NOCOLOR}\n"
    if [ -f ./testsuite.sh ]; then
        if ./testsuite.sh; then
            printf "${ANSI_GREEN}OK${ANSI_NOCOLOR}\n"
        else
            printf "${ANSI_RED}FAILED!${ANSI_NOCOLOR}\n"
            exit 1
        fi
    else
        printf "${ANSI_YELLOW}Skip $d (no testsuite.sh)${ANSI_NOCOLOR}\n"
    fi
    cd ../..
done

printf "${ANSI_GREEN}All tests are OK${ANSI_NOCOLOR}\n"
exit 0

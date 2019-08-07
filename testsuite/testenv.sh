# Testsuite environment

set -e

. ../../utils.sh

if [ x"$GHDL" = x ]; then
    GHDL=ghdl
fi

if [ x"$YOSYS" = x ]; then
    YOSYS="yosys -m ../../ghdl.so"
fi

cmd ()
{
    echo "· $@"
    "$@"
}

run_yosys ()
{
    cmd $YOSYS "$@"
}

analyze ()
{
    printf "${ANSI_BLUE}Analyze $@ $ANSI_NOCOLOR\n"
    cmd "$GHDL" -a $GHDL_STD_FLAGS $GHDL_FLAGS $@
}

synth ()
{
    travis_start "synth" "Synthesize $@"
    run_yosys -p "ghdl $@; synth_ice40 -blif out.blif"
    travis_finish "synth"
}

clean ()
{
    travis_start "rm" "Remove work library"
    "$GHDL" --remove $GHDL_STD_FLAGS
    rm -f out.blif
    travis_finish "rm"
}

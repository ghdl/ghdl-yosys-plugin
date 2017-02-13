# Testsuite environment

set -e

if [ x"$GHDL" = x ]; then
    GHDL=ghdl
fi

if [ x"$YOSYS" = x ]; then
    YOSYS="yosys -m ../../ghdl.so"
fi

analyze ()
{
    echo "analyze $@"
    "$GHDL" -a $GHDL_STD_FLAGS $GHDL_FLAGS $@
}

synth ()
{
    echo "synthesize $@"
    "$YOSYS" -p "ghdl $@; synth_ice40 -blif out.blif"
}

clean ()
{
    echo "Remove work library"
    "$GHDL" --remove $GHDL_STD_FLAGS
    rm -f out.blif
}

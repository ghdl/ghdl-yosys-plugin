# Testsuite environment

if [ x"$topdir" = x"" ]; then
  echo "topdir must be defined"
  exit 1
fi

. $topdir/../utils.sh
abs_topdir=`pwd`/$topdir

set -e

if [ x"$GHDL" = x ]; then
    GHDL=ghdl
fi

if [ x"$YOSYS" = x ]; then
    # Need to use abs_topdir because with sby yosys is executed in a subdir.
    YOSYS="yosys -m $abs_topdir/../ghdl.so"
fi

if [ x"$SYMBIYOSYS" = x ]; then
    SYMBIYOSYS="sby"
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

run_symbiyosys ()
{
    cmd $SYMBIYOSYS --yosys "$YOSYS" "$@"
}

analyze ()
{
    printf "${ANSI_BLUE}Analyze $@ $ANSI_NOCOLOR\n"
    cmd "$GHDL" -a $GHDL_STD_FLAGS $GHDL_FLAGS $@
}

synth_import ()
{
    travis_start "synth" "Synthesize $@"
    run_yosys -p "ghdl $*"
    travis_finish "synth"
}

synth_ice40 ()
{
    travis_start "synth" "Synthesize $@"
    run_yosys -p "ghdl $*; synth_ice40 -blif out.blif"
    travis_finish "synth"
}

synth ()
{
    synth_ice40 "$*"
}

formal ()
{
    travis_start "formal" "Verify $@"
    run_symbiyosys -f -d work $@.sby
    travis_finish "formal"
}

clean ()
{
    "$GHDL" --remove $GHDL_STD_FLAGS
    rm -f out.blif
}

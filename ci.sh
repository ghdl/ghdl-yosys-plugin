#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

# Build ghdl (from scratch)
do_ghdl ()
{
gstart "[Build] ghdl" "$ANSI_MAGENTA"

echo "nproc: $(nproc)"

sudo apt-get update
sudo apt-get install -y --no-install-recommends gcc gnat git

git clone https://github.com/ghdl/ghdl
cd ghdl
./configure --enable-libghdl --enable-synth
make all GNATMAKE="gnatmake -j4"
sudo make install
cd ..

ghdl --version

gend
}

# Build yosys (from scratch)
# Not used: too long.
do_yosys_build ()
{
gstart "[Build] yosys" "$ANSI_MAGENTA"

sudo apt-get install -y --no-install-recommends \
     build-essential clang bison flex \
     libreadline-dev gawk tcl-dev libffi-dev git \
     graphviz xdot pkg-config python3 libboost-system-dev \
     libboost-python-dev libboost-filesystem-dev zlib1g-dev

git clone https://github.com/YosysHQ/yosys.git
cd yosys
git submodule update --init
make config-clang
make -j4
sudo make install
cd ..

gend
}

# Install nightly yosys build
# Much faster and comes with provers
do_yosys_fetch()
{
gstart "[Fetch] yosys" "$ANSI_MAGENTA"

# Get the build from yesterday
now=$(date +%s)
now=$(expr $now - 86400)

url="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$(date --date=@$now +%Y-%m-%d)/oss-cad-suite-linux-x64-$(date --date=@$now +%Y%m%d).tgz"

echo "Fetch $url"

curl -L $url | tar zxf -

#ls
#ls oss-cad-suite/lib

PATH=$PATH:$PWD/oss-cad-suite/bin

ghdl --version

#echo "yosys-config output:"
#for f in cxx cxxflags ldflags ldlibs; do
#    echo -n " --$f: "
#    yosys-config --$f
#done

gend
}


# Build ghdl-yosys-plugin
do_plugin ()
{
gstart "[Build] plugin" "$ANSI_MAGENTA"

# Need to use libstdc++ from yosys
make LDFLAGS="$PWD/oss-cad-suite/lib/libstdc++.so.6"
cp ghdl.so /tmp/ghdl_yosys.so

#ldd ghdl.so

gend

}

# Run the testsuite
do_test ()
{
printf "${ANSI_MAGENTA}[Test] testsuite ${ANSI_NOCOLOR}\n"

./testsuite/testsuite.sh

}

do_yosys_fetch
do_ghdl
do_plugin
do_test

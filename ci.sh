#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

# Build ghdl (from scratch)
do_ghdl ()
{
gstart "[Build] ghdl" "$ANSI_MAGENTA"

set -x

echo "nproc: $(nproc)"

sudo apt-get update
sudo apt-get install -y --no-install-recommends gcc gnat git

git clone https://github.com/ghdl/ghdl
cd ghdl
git describe
./configure --enable-libghdl --enable-synth
make all GNATMAKE="gnatmake -j4"
sudo make install
git describe
cd ..

which ghdl
hash -r
ghdl --version

set +x
gend
}

# Build yosys (from scratch) using CMake.
# ABI guarantee: plugin and yosys are compiled with the same toolchain and
# headers, so std::source_location symbol names will always match.
do_yosys_build ()
{
gstart "[Build] yosys" "$ANSI_MAGENTA"

set -x

# CMake 3.28+ is required.  Ubuntu 22.04 apt ships 3.22, so get a recent
# version via pip.  --break-system-packages not needed on 22.04.
sudo apt-get install -y --no-install-recommends \
     build-essential clang bison flex \
     libreadline-dev tcl-dev libffi-dev git \
     pkg-config python3 python3-pip zlib1g-dev
pip3 install --quiet --upgrade cmake
export PATH="$HOME/.local/bin:$PATH"

cmake --version

git clone --recursive https://github.com/YosysHQ/yosys.git
cmake \
    -S yosys \
    -B yosys/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DYOSYS_INSTALL_DRIVER=ON \
    -DYOSYS_INSTALL_LIBRARY=ON \
    -DYOSYS_WITH_PYTHON=OFF \
    -DBUILD_SHARED_LIBS=ON
cmake --build yosys/build -j$(nproc)
sudo cmake --install yosys/build

which yosys
yosys --version

set +x
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

set -x
echo $PATH
PATH=$PWD/oss-cad-suite/bin:$PATH

which ghdl
ghdl --version

rm -f oss-cad-suite/lib/libghdl*

#echo "yosys-config output:"
#for f in cxx cxxflags ldflags ldlibs; do
#    echo -n " --$f: "
#    yosys-config --$f
#done
set +x

gend
}


# Build ghdl-yosys-plugin
do_plugin ()
{
gstart "[Build] plugin" "$ANSI_MAGENTA"

# Use same llvm compiler as the one used by yosys
# FIXME: find it automatically
curl -L https://apt.llvm.org/llvm.sh > llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 18
sudo update-alternatives --force --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 200
sudo update-alternatives --force --install /usr/bin/clang clang /usr/bin/clang-18 200

echo PATH=$PATH
echo "yosys-config: $(which yosys-config)"

yosys --version
clang++ --version

make

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

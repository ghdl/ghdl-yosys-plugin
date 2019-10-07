#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

prefix='/opt/ghdl'

#--
travis_start "ghdl" "[Build] ghdl/synth:latest" "$ANSI_MAGENTA"

case "$TRAVIS_COMMIT_MESSAGE" in
  "*[stable]*")
    echo "IS_STABLE"
    GHDL_URL="https://github.com/ghdl/ghdl/archive/9d61a62f96dc4897dadbf88f5f4ee199d20e0f8f.tar.gz"
  ;;
  *)
    echo "IS_MASTER"
    GHDL_URL="https://codeload.github.com/ghdl/ghdl/tar.gz/master"
  ;;
esac
echo "GHDL_URL: $GHDL_URL"

docker build -t ghdl/synth:latest - <<-EOF
FROM ghdl/build:buster-mcode AS build

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    ca-certificates \
    curl \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists

RUN mkdir -p ghdl && cd ghdl \
 && curl -fsSL "$GHDL_URL" | tar xzf - --strip-components=1 \
 && ./configure --prefix="$prefix" --enable-libghdl --enable-synth \
 && make all \
 && make install

FROM ghdl/run:buster-mcode
COPY --from=build $prefix $prefix
ENV PATH $prefix/bin:\$PATH
EOF

travis_finish "ghdl"
#--
travis_start "ghdlsynth" "[Build] ghdl/synth:beta" "$ANSI_MAGENTA"

docker build -t ghdl/synth:beta . -f- <<-EOF
FROM ghdl/synth:yosys-gnat AS build
COPY --from=ghdl/synth:latest $prefix $prefix
COPY . /ghdlsynth

RUN cd /ghdlsynth \
 && export PATH=\$PATH:$prefix/bin \
 && make \
 && cp ghdl.so $prefix/lib/ghdl_yosys.so

FROM ghdl/synth:yosys-gnat
COPY --from=build $prefix $prefix
ENV PATH $prefix/bin:\$PATH
RUN yosys-config --exec mkdir -p --datdir/plugins \
 && yosys-config --exec ln -s $prefix/lib/ghdl_yosys.so --datdir/plugins/ghdl.so
EOF

travis_finish "ghdlsynth"
#---
travis_start "formal" "[Build] ghdl/synth:formal" "$ANSI_MAGENTA"

docker build -t ghdl/synth:formal . -f- <<-EOF
FROM ghdl/synth:beta

COPY --from=ghdl/cache:formal ./z3 /opt/z3
COPY --from=ghdl/cache:formal ./symbiyosys /usr/local

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    python3 \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

ENV PATH=/opt/z3/bin:\$PATH
EOF

travis_finish "formal"
#---
printf "${ANSI_MAGENTA}[Test] testsuite ${ANSI_NOCOLOR}\n"

docker run --rm -t -e TRAVIS=$TRAVIS -v /$(pwd)://src -w //src -e YOSYS='yosys -m ghdl' ghdl/synth:formal bash -c "$(cat <<EOF
./testsuite/testsuite.sh
EOF
)"

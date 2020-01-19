#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

#--
gstart "[Build] ghdl/synth:latest" "$ANSI_MAGENTA"

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

docker build -t tmp - <<-EOF
FROM ghdl/build:buster-mcode

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    ca-certificates \
    curl \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && update-ca-certificates \
 && rm -rf /var/lib/apt/lists

RUN mkdir -p ghdl && cd ghdl \
 && curl -fsSL "$GHDL_URL" | tar xzf - --strip-components=1 \
 && ./configure --enable-libghdl --enable-synth \
 && make all \
 && make DESTDIR=/opt/ghdl install
EOF

docker build -t ghdl/synth:latest - <<-EOF
FROM ghdl/run:buster-mcode
COPY --from=tmp /opt/ghdl /
EOF

gend
#--
gstart "[Build] ghdl/synth:beta" "$ANSI_MAGENTA"

docker build -t ghdl/synth:beta . -f- <<-EOF
FROM ghdl/cache:yosys-gnat AS build
COPY --from=tmp /opt/ghdl /opt/ghdl
COPY . /ghdlsynth

RUN cp -vr /opt/ghdl/* / \
 && cd /ghdlsynth \
 && make \
 && cp ghdl.so /opt/ghdl/usr/local/lib/ghdl_yosys.so

FROM ghdl/cache:yosys-gnat
COPY --from=build /opt/ghdl /
RUN yosys-config --exec mkdir -p --datdir/plugins \
 && yosys-config --exec ln -s /usr/local/lib/ghdl_yosys.so --datdir/plugins/ghdl.so
EOF

gend
#---
gstart "[Build] ghdl/synth:formal" "$ANSI_MAGENTA"

docker build -t ghdl/synth:formal . -f- <<-EOF
FROM ghdl/synth:beta

COPY --from=ghdl/cache:formal ./z3 /
COPY --from=ghdl/cache:formal ./symbiyosys /

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    python3 \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*
EOF

gend "formal"
#---
printf "${ANSI_MAGENTA}[Test] testsuite ${ANSI_NOCOLOR}\n"

docker run --rm -t -e CI -v /$(pwd)://src -w //src -e YOSYS='yosys -m ghdl' ghdl/synth:formal bash -c "$(cat <<EOF
./testsuite/testsuite.sh
EOF
)"

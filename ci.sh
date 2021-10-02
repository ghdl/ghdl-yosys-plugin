#!/bin/sh

set -e

cd "$(dirname $0)"
. ./utils.sh

# To build latest GHDL from sources, uncomment the following block
# and replace --from=ghdl/pkg:buster-mcode below with --from=tmp

#docker build -t tmp - <<-EOF
#FROM ghdl/build:buster-mcode
#RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
#    ca-certificates curl && update-ca-certificates \
# && mkdir -p ghdl && cd ghdl \
# && curl -fsSL "$GHDL_URL" | tar xzf - --strip-components=1 \
# && ./configure --enable-libghdl --enable-synth \
# && make all \
# && make DESTDIR=/opt/ghdl install
#EOF

#--

do_plugin () {

gstart "[Build] ghdl/synth:beta" "$ANSI_MAGENTA"

docker build -t ghdl/synth:beta . -f- <<-EOF
ARG REGISTRY='gcr.io/hdl-containers/debian/bullseye'

#---

# WORKAROUND: this is required because 'COPY --from' does not support ARGs
FROM \$REGISTRY/pkg/ghdl AS pkg-ghdl

FROM \$REGISTRY/yosys AS base

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    libgnat-9 \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists

COPY --from=pkg-ghdl /ghdl /

#---

FROM base AS build

COPY . /ghdlsynth

RUN cd /ghdlsynth \
 && make \
 && cp ghdl.so /tmp/ghdl_yosys.so

#---

FROM base
COPY --from=build /tmp/ghdl_yosys.so /usr/local/lib/
RUN yosys-config --exec mkdir -p --datdir/plugins \
 && yosys-config --exec ln -s /usr/local/lib/ghdl_yosys.so --datdir/plugins/ghdl.so
EOF

gend

}

#---

do_formal () {

gstart "[Build] ghdl/synth:formal" "$ANSI_MAGENTA"
docker build -t ghdl/synth:formal . -f- <<-EOF
ARG REGISTRY='gcr.io/hdl-containers/debian/bullseye'

#--

# WORKAROUND: this is required because 'COPY --from' does not support ARGs
FROM \$REGISTRY/pkg/z3 AS pkg-z3
FROM \$REGISTRY/pkg/symbiyosys AS pkg-symbiyosys

FROM ghdl/synth:beta

COPY --from=pkg-z3 /z3 /
COPY --from=pkg-symbiyosys /symbiyosys /

RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    python3 \
 && apt-get autoclean && apt-get clean && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*
EOF
gend "formal"

}

#---

do_test () {

printf "${ANSI_MAGENTA}[Test] testsuite ${ANSI_NOCOLOR}\n"
docker run --rm -t -e CI -v /$(pwd)://src -w //src -e YOSYS='yosys -m ghdl' ghdl/synth:formal bash -c "$(cat <<EOF
./testsuite/testsuite.sh
EOF
)"

}

#---

case $1 in
  plugin)
    do_plugin
    ;;
  formal)
    do_plugin
    do_formal
    ;;
  test)
    do_test
    ;;
  *)
    do_plugin
    do_formal
    do_test
esac

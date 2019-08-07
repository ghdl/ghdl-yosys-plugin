# Utils for pretty printing logs

enable_color() {
  ENABLECOLOR='-c '
  ANSI_RED="\033[31m"
  ANSI_GREEN="\033[32m"
  ANSI_YELLOW="\033[33m"
  ANSI_BLUE="\033[34m"
  ANSI_MAGENTA="\033[35m"
  ANSI_CYAN="\033[36;1m"
  ANSI_DARKCYAN="\033[36m"
  ANSI_NOCOLOR="\033[0m"
}

disable_color() { unset ENABLECOLOR ANSI_RED ANSI_GREEN ANSI_YELLOW ANSI_BLUE ANSI_MAGENTA ANSI_CYAN ANSI_DARKCYAN ANSI_NOCOLOR; }

enable_color

#--

print_start() {
  COL="$ANSI_BLUE"
  if [ "x$3" != "x" ]; then
    COL="$3"
  fi
  printf "$COL> $2$ANSI_NOCOLOR\n"
}

travis_start () {
  print_start "$@"
}
travis_finish () {
  :
}

[ -n "$TRAVIS" ] && {
  # This is a trimmed down copy of
  # https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/templates/header.sh
  travis_time_start() {
    # `date +%N` returns the date in nanoseconds. It is used as a replacement for $RANDOM, which is only available in bash.
    travis_timer_id=`date +%N`
    travis_start_time=$(travis_nanoseconds)
    echo "travis_time:start:$travis_timer_id"
  }
  travis_time_finish() {
    travis_end_time=$(travis_nanoseconds)
    local duration=$(($travis_end_time-$travis_start_time))
    echo "travis_time:end:$travis_timer_id:start=$travis_start_time,finish=$travis_end_time,duration=$duration"
  }

  if [ "$TRAVIS_OS_NAME" = "osx" ]; then
    travis_nanoseconds() {
      date -u '+%s000000000'
    }
  else
    travis_nanoseconds() {
      date -u '+%s%N'
    }
  fi

  travis_start () {
    echo "travis_fold:start:$1"
    travis_time_start
    print_start "$@"
  }

  travis_finish () {
    travis_time_finish
    echo "travis_fold:end:$1"
  }

} || echo "INFO: not in Travis CI"

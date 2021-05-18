#!/bin/bash
# A shell script for executing opentitantool as the test harness for
# functional tests.
#
# Currently this script expects only to execute tests via verilator.

set -e

PASS="PASS"
FAIL="FAIL"
TIMELIMIT=$((15*60))

for arg in "$@"; do
  case $arg in
    --tool=*)
      OPENTITANTOOL="${arg#*=}"
      shift
      ;;
    --verilator-bin=*)
      VERILATOR_BIN="${arg#*=}"
      shift
      ;;
    --verilator-rom=*)
      VERILATOR_ROM="${arg#*=}"
      shift
      ;;
    --verilator-flash=*)
      VERILATOR_FLASH="${arg#*=}"
      shift
      ;;
    --verilator-otp=*)
      VERILATOR_OTP="${arg#*=}"
      shift
      ;;
    --pass=*)
      PASS="${arg#*=}"
      shift
      ;;
    --fail=*)
      FAIL="${arg#*=}"
      shift
      ;;
    --timeout=*)
      TIMELIMIT="${arg#*=}"
      shift
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
esac
done

RUST_BACKTRACE=1 ${OPENTITANTOOL} \
    --logging=info \
    --interface=verilator \
    --verilator-bin=${VERILATOR_BIN} \
    --verilator-rom=${VERILATOR_ROM} \
    --verilator-flash=${VERILATOR_FLASH} \
    --verilator-otp=${VERILATOR_OTP} \
    console \
    --exit-failure=${FAIL} \
    --exit-success=${PASS} \
    --timeout=${TIMELIMIT}


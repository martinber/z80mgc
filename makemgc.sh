#!/usr/bin/env bash

# My sort of makefile

ZASM=/home/mbernardi/extra/async/programas/zasm-4.4.10-Linux64/zasm

if [[ "$#" -ne 2 ]]; then
    echo "ERROR: Give command and program to use"
    exit 1
fi
COMMAND=$1
PROGRAM=$2


case "${COMMAND}" in
    "build")
        ${ZASM} "./src/${PROGRAM}.asm" -l "./out/${PROGRAM}.lst" -o "./out/${PROGRAM}.bin" -uw
        ;;

    "emulate")
        ${ZASM} "./src/${PROGRAM}.asm" -l "./out/${PROGRAM}.lst" -o "./out/${PROGRAM}.bin" -uw \
            && pushd ./emulation/z80mgc-emu \
            && cargo run -- "../../out/${PROGRAM}.bin" \
            && popd
        ;;

    *)
        echo "ERROR: Invalid command"
        ;;

esac

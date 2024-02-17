#!/usr/bin/env bash

# My sort of makefile

ZASM=/media/mbernardi/datos/async/extra/software/zasm-4.4.10-Linux64/zasm

if [[ "$#" -ne 2 ]]; then
    echo "ERROR: Give command and program to use"
    exit 1
fi
COMMAND=$1
PROGRAM=$2


case "${COMMAND}" in
    "build")
        mkdir ./out
        ${ZASM} "./src/${PROGRAM}.asm" -l "./out/${PROGRAM}.lst" -o "./out/${PROGRAM}.bin" -uw
        ;;

    "emulate")
        mkdir ./out
        ${ZASM} "./src/${PROGRAM}.asm" -l "./out/${PROGRAM}.lst" -o "./out/${PROGRAM}.bin" -uw \
            && pushd ./emulation/z80mgc-emu \
            && cargo run -- "../../out/${PROGRAM}.bin" \
            && popd
        ;;

    *)
        echo "ERROR: Invalid command"
        ;;

esac

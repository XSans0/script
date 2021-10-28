#!/bin/bash

export KERNELNAME=Waifu-EiChan-EAS

export LOCALVERSION=Rev1.0

export KBUILD_BUILD_USER=XSans

export KBUILD_BUILD_HOST=CircleCI

export TOOLCHAIN=clang

export DEVICES=tulip

export CI_ID=${TELEGRAM_ID}

export BOT_TOKEN=${BOT_TOKEN}

export GROUP_ID=none

source helper

gen_toolchain

send_msg "<b>⏳ Start building:</b> <code>${KERNELNAME}-${LOCALVERSION}</code>%0A<b>Device: tulip</b>%0A<b>Linux version:</b> <code>$(make kernelversion)</code>%0A<b>Compiler:</b> <code>$KBUILD_COMPILER_STRING</code>"

START=$(date +"%s")

for i in ${DEVICES//,/ }
do
	build ${i} -oldcam

	build ${i} -newcam
done

send_msg "<b>⏳ Start building Overclock version</b>"

git apply oc.patch

git apply em.patch

for i in ${DEVICES//,/ }
do
	if [ $i == "tulip" ]
	then
		build ${i} -oldcam -overclock

		build ${i} -newcam -overclock
	fi
done

END=$(date +"%s")

DIFF=$(( END - START ))

send_msg "✅ Build completed in $((DIFF / 60))m $((DIFF % 60))s"

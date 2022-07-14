#!/usr/bin/env bash
# Copyright ©2022 XSans02

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

function panel() {
    echo -e "\e[1;34m$*\e[0m"
}

function panel2() {
    echo -ne "\e[1;34m$*\e[0m"
}

function err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Home directory
HOME=$(pwd)

# Cancel if something is missing
msg "* Token Checker"
sleep 3
if [[ -z "${TELEGRAM_TOKEN}" ]] || [[ -z "${CHANNEL_ID}" ]] || [[ -z "${GIT_TOKEN}" ]]; then
    err "(X) There is something missing!"
    exit
else
    msg "(OK) Everything is okey"
fi

# Clang source checker
msg ""
msg "* Clang Checker"
sleep 3
if [[ "$(cat toolchain.txt)" == "clang" ]]; then
    # Toolchain directory
    CLANG_DIR="$HOME/clang"
    PrefixDir="$CLANG_DIR/bin/"
    export KBUILD_COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

    msg "(OK) ${KBUILD_COMPILER_STRING} detected."
elif [[ "$(cat toolchain.txt)" == "aosp" ]]; then
    # Toolchain directory
    CLANG_DIR="$HOME/clang"
    GCC64_DIR="$HOME/arm64"
    GCC32_DIR="$HOME/arm32"
    PrefixDir="$CLANG_DIR/bin/"
    export KBUILD_COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

    msg "(OK) ${KBUILD_COMPILER_STRING} detected."
elif [[ "$(cat toolchain.txt)" == "sdclang" ]]; then
    # Toolchain directory
    CLANG_DIR="$HOME/clang/compiler"
    GCC64_DIR="$HOME/arm64"
    GCC32_DIR="$HOME/arm32"
    PrefixDir="$CLANG_DIR/bin/"
    export KBUILD_COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

    msg "(OK) ${KBUILD_COMPILER_STRING} detected."
else
    err "(X) Clang not found, please clone first!"
    msg ""
    msg "* Load clang source"
    sleep 10
    source clang.sh
fi

# Clone Source
msg ""
msg "* Clone Kernel/AK3 Source"
rm -rf kernel AK3
git clone --depth=1 -b 12.1/main https://"$GIT_TOKEN":x-oauth-basic@github.com/XSans0/kernel_xiaomi_vayu kernel
git clone --depth=1 -b vayu https://github.com/XSans0/AnyKernel3 AK3
cd kernel || exit

# environtment
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/"
AK3_DIR="$HOME/AK3/"
BASE_DTB_NAME="sm8150-v2"
CODENAME="vayu"
DEFCONFIG="vayu_defconfig"
CORES=$(nproc --all)
CPU=$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT="$(git log --pretty=format:'%s' -1)"

# Checking toolchain for adapt CROSS_COMPILE & CROSS_COMPILE_ARM32
if [[ -d "$GCC64_DIR" ]] || [[ -d "$GCC32_DIR" ]]; then
    ARM64=aarch64-linux-android-
    ARM32=arm-linux-androideabi-
else
    ARM64=aarch64-linux-gnu-
    ARM32=arm-linux-gnueabi-
fi

# Set default time to WIB
export TZ="Asia/Jakarta"
export ZIP_DATE="$(TZ=Asia/Jakarta date +'%Y%m%d')"
export CURRENTDATE="$(TZ=Asia/Jakarta date +"%A, %d %b %Y, %H:%M:%S")"

# Export
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="XSansツ"
export KBUILD_BUILD_HOST="Wibu-Server"
export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"

# Telegram Setup
git clone --depth=1 https://github.com/XSans02/Telegram Telegram

TELEGRAM=Telegram/telegram
function send_msg() {
  "${TELEGRAM}" -c "${CHANNEL_ID}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

function send_file() {
  "${TELEGRAM}" -f "$(echo "$AK3_DIR"/*.zip)" \
  -c "${CHANNEL_ID}" -H \
      "$1"
}

function send_log() {
  "${TELEGRAM}" -f "$(echo out/log.txt)" \
  -c "${CHANNEL_ID}" -H \
      "$1"
}
function start_msg() {
    send_msg "<b>New Kernel On The Way</b>" \
                 "<b>==================================</b>" \
                 "<b>Device : </b>" \
                 "<code>* $CODENAME</code>" \
                 "<b>Branch : </b>" \
                 "<code>* $BRANCH</code>" \
                 "<b>Build Using : </b>" \
                 "<code>* $CPU $CORES thread</code>" \
                 "<b>Last Commit : </b>" \
                 "<code>* $COMMIT</code>" \
                 "<b>==================================</b>"
}
function end_msg() {
    send_msg "<b>Build Successfully</b>" \
                 "<b>==================================</b>" \
                 "<b>Build Date : </b>" \
                 "<code>* $(date +"%A, %d %b %Y, %H:%M:%S")</code>" \
                 "<b>Build Took : </b>" \
                 "<code>* $(("$TOTAL_TIME" / 60)) Minutes, $(("$TOTAL_TIME" % 60)) Second.</code>" \
                 "<b>Compiler : </b>" \
                 "<code>* $KBUILD_COMPILER_STRING</code>" \
                 "<b>==================================</b>"
}

# Menu
while true; do
    panel ""
    panel " Menu                                                               "
    panel " ╔═════════════════════════════════════════════════════════════════╗"
    panel " ║ 1. Export defconfig to Out Dir                                  ║"
    panel " ║ 2. Start Compile With Clang                                     ║"
    panel " ║ 3. Start Compile With Clang LLVM                                ║"
    panel " ║ 4. Copy Image, dtbo, dtb to Flashable Dir                       ║"
    panel " ║ 5. Make Zip                                                     ║"
    panel " ║ 6. Upload to Telegram                                           ║"
    panel " ║ e. Back Main Menu                                               ║"
    panel " ╚═════════════════════════════════════════════════════════════════╝"
    panel2 " Enter your choice 1-6, or press 'e' for back to Main Menu : "

    read -r menu

    # Export deconfig
    if [[ "$menu" == "1" ]]; then
        make O=out $DEFCONFIG
        msg ""
        msg "(OK) Success export $DEFCONFIG to Out Dir"
        msg ""
    fi

    # Build With Clang
    if [[ "$menu" == "2" ]]; then
        msg ""
        START=$(date +"%s")
        msg "(OK) Start Compile kernel for $CODENAME, started at $CURRENTDATE using $CPU $CORES thread"
        msg ""
        start_msg

        # Run Build
        make -j"$CORES" O=out \
            CC=clang \
            LD=ld.lld \
            AR=llvm-ar \
            NM=llvm-nm \
            AS=llvm-as \
            STRIP=llvm-strip \
            OBJCOPY=llvm-objcopy \
            OBJDUMP=llvm-objdump \
            OBJSIZE=llvm-size \
            READELF=llvm-readelf \
            CLANG_TRIPLE=aarch64-linux-gnu- \
            CROSS_COMPILE=${ARM64} \
            CROSS_COMPILE_ARM32=${ARM32} 2>&1 | tee out/log.txt

        if ! [ -a "$KERNEL_IMG" ]; then
            err ""
            err "(X) Compile Kernel for $CODENAME failed, See buildlog to fix errors"
            err ""
            send_log "<b>Build Failed, See log to fix errors</b>"
            exit
        fi

        END=$(date +"%s")
        TOTAL_TIME=$(("$END" - "$START"))
        msg ""
        msg "(OK) Compile Kernel for $CODENAME successfully, Kernel Image in $KERNEL_IMG"
        msg "(OK) Total time elapsed: $(("$TOTAL_TIME" / 60)) Minutes, $(("$TOTAL_TIME" % 60)) Second."
        msg ""
        end_msg
    fi

        # Build With Clang LLVM
    if [[ "$menu" == "3" ]]; then
        msg ""
        START=$(date +"%s")
        msg "(OK) Start Compile kernel for $CODENAME, started at $CURRENTDATE using $CPU $CORES thread"
        msg ""
        start_msg

        # Run Build
        make -j"$CORES" O=out \
            CC=clang \
            LD=${PrefixDir}ld.lld \
            AR=${PrefixDir}llvm-ar \
            NM=${PrefixDir}llvm-nm \
            AS=${PrefixDir}llvm-as \
            STRIP=${PrefixDir}llvm-strip \
            OBJCOPY=${PrefixDir}llvm-objcopy \
            OBJDUMP=${PrefixDir}llvm-objdump \
            OBJSIZE=${PrefixDir}llvm-size \
            READELF=${PrefixDir}llvm-readelf \
            HOSTCC=clang \
            HOSTCXX=clang++ \
            HOSTAR=${PrefixDir}llvm-ar \
	    HOSTLD=${PrefixDir}ld.lld \
            CLANG_TRIPLE=aarch64-linux-gnu- \
            CROSS_COMPILE=${ARM64} \
            CROSS_COMPILE_ARM32=${ARM32} \
            LLVM=1 2>&1 | tee out/log.txt

        if ! [ -a "$KERNEL_IMG" ]; then
            err ""
            err "(X) Compile Kernel for $CODENAME failed, See buildlog to fix errors"
            err ""
            send_log "<b>Build Failed, See log to fix errors</b>"
            exit
        fi

        END=$(date +"%s")
        TOTAL_TIME=$(("$END" - "$START"))
        msg ""
        msg "(OK) Compile Kernel for $CODENAME successfully, Kernel Image in $KERNEL_IMG"
        msg "(OK) Total time elapsed: $(("$TOTAL_TIME" / 60)) Minutes, $(("$TOTAL_TIME" % 60)) Second."
        msg ""
        end_msg
    fi

    # Copy image, dtbo, dtb to flashable dir
    if [[ "$menu" == "4" ]]; then
        msg ""
        msg "* Copying Image, dtbo, dtb ..."
        if [[ -f "$KERNEL_IMG" ]]; then
            cp "$KERNEL_IMG" "$AK3_DIR"/
            msg "(OK) Done Copy kernel img to $AK3_DIR"
        else
            err "(X) Image Not Found"
        fi
        sleep 1
        if [[ -f "$KERNEL_DTBO" ]]; then
            cp "$KERNEL_DTBO" "$AK3_DIR"/
            msg "(OK) Done copy dtbo to $AK3_DIR"
        else
            err "(X) dtbo Not Found"
        fi
        sleep 1
        if [[ -f $KERNEL_DTB/${BASE_DTB_NAME}.dtb ]]; then
		    cp "$KERNEL_DTB/${BASE_DTB_NAME}.dtb" "$AK3_DIR/dtb.img"
            msg "(OK) Done Copy dtb to $AK3_DIR"
            msg ""
        else
            err "(X) dtb Not Found"
            err ""
        fi
    fi

    # Make Zip
    if [[ "$menu" == "5" ]]; then
        cd "$AK3_DIR" || exit
        ZIP_NAME=["$ZIP_DATE"]WeebX-Personal-"$(TZ=Asia/Jakarta date +'%H%M')".zip
        zip -r9 "$ZIP_NAME" ./*
        cd "$KERNEL_DIR" || exit

        msg ""
        msg "(OK) Done Zipping Kernel"
        msg ""
    fi

    # Upload Telegram
    if [[ "$menu" == "6" ]]; then
        send_log "<b>Build Successfully</b>"
        send_file "<b>md5 : </b><code>$(md5sum "$AK3_DIR/$ZIP_NAME" | cut -d' ' -f1)</code>"

        msg ""
	    msg "(OK) Done Upload to Telegram"
        msg ""
    fi

    # Exit
    if [[ "$menu" == "e" ]]; then
        exit
    fi

done
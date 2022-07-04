#!/usr/bin/env bash
# Copyright ©2022 XSans02

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

function err() {
    echo -e "\e[1;41m$*\e[0m"
}

# Cancel if something is missing
if [[ -z "${GIT_TOKEN}" ]] || [[ -z "${1}" ]]; then
    err "* There is something missing!"
    exit
fi

# Setup branch
BRANCH="${1}"

# Set a directory
DIR="$(pwd ...)"

# Build LLVM
msg "*Building LLVM..."

# Start Count
BUILD_START=$(date +"%s")
LLVM_START=$(date +"%s")

if [[ "${BRANCH}" == "release/15-gr" ]]; then
	./build-llvm.py \
		--clang-vendor "WeebX" \
	    	--defines "LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3" \
	    	--projects "clang;lld;polly" \
	    	--targets "ARM;AArch64;X86" \
		--pgo "kernel-defconfig" \
		--lto "full" \
		--use-good-revision \
		--incremental
else
		./build-llvm.py \
		--clang-vendor "WeebX" \
	    	--defines "LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 CMAKE_CXX_FLAGS=-O3" \
	    	--projects "clang;lld;polly" \
	    	--targets "ARM;AArch64;X86" \
		--pgo "kernel-defconfig" \
		--lto "full" \
		--shallow-clone \
		--incremental \
		--branch "${BRANCH}"
fi


# End Count
LLVM_END=$(date +"%s")
LLVM_DIFF=$(($LLVM_END - $LLVM_START))

msg "* Build LLVM Finished $(("$LLVM_DIFF" / 60)) Minutes, $(("$LLVM_DIFF" % 60)) Second."

# Check if the final clang binary exists or not.
if ! [ -a clang-1* ]; then
	err "* Building LLVM failed ! Kindly check errors !"
	exit
fi

# Build binutils
msg "Building binutils..."

# Start Count
BIN_START=$(date +"%s")
./build-binutils.py --targets arm aarch64 x86_64

# End Count
BIN_END=$(date +"%s")
BIN_DIFF=$(($BIN_END - $BIN_START))

msg "* Build Binutils Finished $(("$BIN_DIFF" / 60)) Minutes, $(("$BIN_DIFF" % 60)) Second."

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done

# Release Info
pushd llvm-project || exit
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< "$llvm_commit")"
popd || exit

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$short_llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# End Count
BUILD_END=$(date +"%s")
TOTAL_TIME=$(($BUILD_END - $BUILD_START))

msg "* Clang Build Finished $(("$TOTAL_TIME" / 60)) Minutes, $(("$TOTAL_TIME" % 60)) Second."

# Update git config
git config --global user.name "XSans"
git config --global user.email "xsansdroid@gmail.com"

# Push to gitlab
msg "* Push to gitlab"
git clone https://XSans0:"${GIT_TOKEN}"@gitlab.com/XSans0/weebx-clang.git rel_repo
pushd rel_repo || exit
rm -rf ./*
cp -r ../install/* .
echo "# Just Info" >> README.md
echo "* Build Date : $(TZ=Asia/Jakarta date +%Y-%m-%d)" >> README.md
echo "* Clang Version : $clang_version" >> README.md
echo "* Binutils Version : $binutils_ver" >> README.md
echo "* Compiled Based : $llvm_commit_url" >> README.md
git add .
git commit -asm "WeebX-Clang-$clang_version Build: $(TZ=Asia/Jakarta date +%Y-%m-%d)"
git push origin HEAD:"${BRANCH}"
popd || exit
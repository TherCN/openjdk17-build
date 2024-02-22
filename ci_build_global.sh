#!/bin/bash
set -e
wget https://apt.llvm.org/llvm.sh
sudo bash llvm.sh 17
git clone https://github.com/termux/termux-elf-cleaner || true
cd termux-elf-cleaner
sudo apt install autoconf m4 automake g++-11 -y
autoreconf -vfi
./configure CXX=/usr/bin/clang++
make
cd ..
. setdevkitpath.sh

export JDK_DEBUG_LEVEL=release

if [ "$BUILD_IOS" != "1" ]; then
  sudo apt update
  sudo apt -y install autoconf python unzip zip

  wget -nc -nv -O android-ndk-$NDK_VERSION-linux-x86_64.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux-x86_64.zip"
  ./extractndk.sh
  ./maketoolchain.sh
else
  # OpenJDK 8 iOS port is still in unusable state, so we need build in debug mode
  export JDK_DEBUG_LEVEL=slowdebug

  chmod +x ios-arm64-clang
  chmod +x ios-arm64-clang++
  chmod +x macos-host-cc
fi

# Some modifies to NDK to fix
./getlibs.sh
./buildlibs.sh
./clonejdk.sh
./buildjdk.sh
./removejdkdebuginfo.sh
./tarjdk.sh

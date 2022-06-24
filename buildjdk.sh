#!/bin/bash
set -e
. setdevkitpath.sh

export FREETYPE_DIR=$PWD/freetype-$BUILD_FREETYPE_VERSION/build_android-$TARGET_SHORT
export CUPS_DIR=$PWD/cups-2.2.4
export CFLAGS+=" -DLE_STANDALONE -DANDROID" # -I$FREETYPE_DIR -I$CUPS_DI
if [ "$TARGET_JDK" == "arm" ]
then
  export CFLAGS+=" -O3 -D__thumb__"
else
  export CFLAGS+=" -O3"
fi

# if [ "$TARGET_JDK" == "aarch32" ] || [ "$TARGET_JDK" == "aarch64" ]
# then
#   export CFLAGS+=" -march=armv7-a+neon"
# fi

# It isn't good, but need make it build anyways
# cp -R $CUPS_DIR/* $ANDROID_INCLUDE/

# cp -R /usr/include/X11 $ANDROID_INCLUDE/
# cp -R /usr/include/fontconfig $ANDROID_INCLUDE/

if [ "$BUILD_IOS" != "1" ]; then
  chmod +x android-wrapped-clang
  chmod +x android-wrapped-clang++
  ln -s -f /usr/include/X11 $ANDROID_INCLUDE/
  ln -s -f /usr/include/fontconfig $ANDROID_INCLUDE/
  AUTOCONF_x11arg="--x-includes=$ANDROID_INCLUDE/X11"

  export LDFLAGS+=" -L$PWD/dummy_libs"

  sudo apt -y install systemtap-sdt-dev libxtst-dev libasound2-dev libelf-dev libfontconfig1-dev libx11-dev libxext-dev libxrandr-dev libxrender-dev libxtst-dev libxt-dev

# Create dummy libraries so we won't have to remove them in OpenJDK makefiles
  mkdir -p dummy_libs
  ar cru dummy_libs/libpthread.a
  ar cru dummy_libs/librt.a
  ar cru dummy_libs/libthread_db.a
else
  ln -s -f /opt/X11/include/X11 $ANDROID_INCLUDE/
  platform_args=--with-toolchain-type=clang
  AUTOCONF_x11arg="--with-x=/opt/X11/include/X11 --disable-precompiled-headers --prefix=/data/data/bin.mt.plus/files/term/usr/share/openjdk-17"
  sameflags="-arch arm64 -isysroot $thesysroot -miphoneos-version-min=12.0 -DHEADLESS=1 -I$PWD/ios-missing-include -Wno-implicit-function-declaration -Wl,-rpath=/data/data/bin.mt.plus/files/term/usr/share/openjdk-17/lib"
  export CFLAGS+=" $sameflags"
  export CXXFLAGS="$sameflags"

  HOMEBREW_NO_AUTO_UPDATE=1 brew install ldid xquartz
fi

# fix building libjawt
ln -s -f $CUPS_DIR/cups $ANDROID_INCLUDE/

cd openjdk
# rm -rf build
patch -p0 -i ../fix-libjava.patch
#   --with-extra-cxxflags="$CXXFLAGS -Dchar16_t=uint16_t -Dchar32_t=uint32_t" \
#   --with-extra-cflags="$CPPFLAGS" \
#   --with-sysroot="$(xcrun --sdk iphoneos --show-sdk-path)" \

bash ./configure \
    --openjdk-target=$TARGET \
    --with-extra-cflags="$CFLAGS" \
    --with-extra-cxxflags="$CFLAGS" \
    --with-extra-ldflags="$LDFLAGS" \
    --disable-precompiled-headers \
    --disable-warnings-as-errors \
    --enable-option-checking=fatal \
    --enable-headless-only=yes \
    --with-toolchain-type=gcc \
    --with-jvm-variants=$JVM_VARIANTS \
    --with-jvm-features=-dtrace,-zero,-vm-structs,-epsilongc \
    --with-cups-include=$CUPS_DIR \
    --with-devkit=$TOOLCHAIN \
    --with-debug-level=$JDK_DEBUG_LEVEL \
    --with-fontconfig-include=$ANDROID_INCLUDE \
    --with-freetype-lib=$FREETYPE_DIR/lib \
    --with-freetype-include=$FREETYPE_DIR/include/freetype2 \
    $AUTOCONF_x11arg $AUTOCONF_EXTRA_ARGS \
    --x-libraries=/usr/lib \
        $platform_args || \
error_code=$?
if [ "$error_code" -ne 0 ]; then
  echo "\n\nCONFIGURE ERROR $error_code , config.log:"
  cat config.log
  exit $error_code
fi

cd build/${JVM_PLATFORM}-${TARGET_JDK}-${JVM_VARIANTS}-${JDK_DEBUG_LEVEL}
make JOBS=4 images || \
error_code=$?
if [ "$error_code" -ne 0 ]; then
  echo "Build failure, exited with code $error_code. Trying again."
  make JOBS=4 images
fi

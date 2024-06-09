#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0
# Author: Vaisakh Murali
set -e

echo "*****************************************"
echo "* Building Bare-Metal Bleeding Edge GCC *"
echo "*****************************************"

WORK_DIR="${PWD}"
NPROC="$(nproc --all)"
PREFIX="${WORK_DIR}/install"
OPT_FLAGS="-pipe -O3 -flto=${NPROC} -fipa-pta -fgraphite -fgraphite-identity -floop-nest-optimize -fno-semantic-interposition -ffunction-sections -fdata-sections -Wl,--gc-sections"
BUILD_DATE="$(cat ${WORK_DIR}/gcc/gcc/DATESTAMP)"
BUILD_DAY="$(date "+%d %B %Y")"
BUILD_TAG="$(date +%Y%m%d-%H%M-%Z)"
TARGETS="aarch64-linux-gnu"
HEAD_SCRIPT="$(git log -1 --oneline)"
HEAD_GCC="$(git --git-dir gcc/.git log -1 --oneline)"
HEAD_BINUTILS="$(git --git-dir binutils/.git log -1 --oneline)"
PKG_VERSION="eraselk"
IS_MASTER="${1}"
export PKG_VERSION WORK_DIR NPROC PREFIX OPT_FLAGS BUILD_DATE BUILD_DAY BUILD_TAG TARGETS HEAD_SCRIPT HEAD_GCC HEAD_BINUTILS IS_MASTER


build_zstd() {
#   "<b>GitHub Action : </b><pre>Zstd build started . . .</pre>"
  mkdir ${WORK_DIR}/build-zstd
  cd ${WORK_DIR}/build-zstd
  cmake ${WORK_DIR}/zstd/build/cmake -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}"
  make -j${NPROC} 
  make install -j${NPROC} 

  # check Zstd build status
  if [ -f "${PREFIX}/bin/zstd" ]; then
    rm -rf ${WORK_DIR}/build-zstd
#     "<b>GitHub Action : </b><pre>Zstd build finished ! ! !</pre>"
    cd $WORK_DIR
  else
    cd $WORK_DIR
    exit 1
  fi
}

build_binutils() {
#   "<b>GitHub Action : </b><pre>Binutils build started . . .</pre><b>Target : </b><pre>[${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-binutils
  cd ${WORK_DIR}/build-binutils
  # Check compiler first
  gcc -v 
  ld -v 

  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../binutils/configure \
    --disable-compressed-debug-sections \
    --disable-docs \
    --disable-gdb \
    --disable-gold \
    --disable-gprofng \
    --disable-multilib \
    --disable-nls \
    --disable-shared \
    --enable-ld=default \
    --enable-plugins \
    --enable-threads \
    --enable-64-bit-bfd \
    --prefix=${PREFIX} \
    --program-prefix=${TARGET}- \
    --target=${TARGET} \
    --with-pkgversion="${PKG_VERSION} Binutils" \
    --with-sysroot \
    --with-system-zlib \
    --quiet 
  make -j${NPROC} 
  make install -j${NPROC} 

  # check Binutils build status
  if [ -f "${PREFIX}/bin/${TARGET}-ld" ]; then
    rm -rf ${WORK_DIR}/build-binutils
#     "<b>GitHub Action : </b><pre>Binutils build finished ! ! !</pre>"
    cd $WORK_DIR
  else
    cd $WORK_DIR
    exit 1
  fi
}

build_gcc() {
#   "<b>GitHub Action : </b><pre>GCC build started . . .</pre><b>Target : </b><pre>[${TARGET}]</pre>"
  mkdir ${WORK_DIR}/build-gcc
  cd ${WORK_DIR}/build-gcc
  # Check compiler first
  gcc -v 
  ld -v 

  case $TARGET in
    x86_64*)
      EXTRA_CONF="--without-cuda-driver"
      ;;
    aarch64*)
      EXTRA_CONF="--enable-fix-cortex-a53-835769 \
        --enable-fix-cortex-a53-843419 \
        --with-headers=/usr/include"
      ;;
    arm*)
      EXTRA_CONF="--with-headers=/usr/include"
      ;;
  esac

  env CFLAGS="${OPT_FLAGS}" CXXFLAGS="${OPT_FLAGS}" \
    ../gcc/configure \
    --disable-bootstrap \
    --disable-checking \
    --disable-decimal-float \
    --disable-docs \
    --disable-gcov \
    --disable-libcc1 \
    --disable-libffi \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libsanitizer \
    --disable-libssp \
    --disable-libstdcxx-debug \
    --disable-libstdcxx-pch \
    --disable-libvtv \
    --disable-multilib \
    --disable-nls \
    --disable-shared \
    --enable-default-pie \
    --enable-default-ssp \
    --enable-gnu-indirect-function \
    --enable-languages=c,c++ \
    --enable-linux-futex \
    --enable-threads=posix \
    --prefix=${PREFIX} \
    --program-prefix=${TARGET}- \
    --target=${TARGET} \
    --with-gnu-as \
    --with-gnu-ld \
    --with-newlib \
    --with-pkgversion="${PKG_VERSION} GCC" \
    --with-sysroot \
    --with-system-zlib \
    --quiet ${EXTRA_CONF} 
  make all-gcc -j${NPROC} 
  make all-target-libgcc -j${NPROC} 
  make install-gcc -j${NPROC} 
  make install-target-libgcc -j${NPROC}

  # check GCC build status
  if [ -f "${PREFIX}/bin/${TARGET}-gcc" ]; then
    rm -rf ${WORK_DIR}/build-gcc
#     "<b>GitHub Action : </b><pre>GCC build finished ! ! !</pre>"
    cd $WORK_DIR
  else
    cd $WORK_DIR
    exit 1
  fi
}

strip_binaries(){
#   "<b>GitHub Action : </b><pre>Strip binaries . . .</pre>"

  find install -type f -exec file {} \; > .file-idx

  for TARGET in ${TARGETS}; do
    case $TARGET in
      x86_64*)
        grep "x86-64" .file-idx |
          grep "not strip" |
          tr ':' ' ' | awk '{print $1}' |
          while read -r file
            do strip -s "$file"
          done;;
      aarch64*)
        cp -rf ${PREFIX}/bin/${TARGET}-strip ./stripp-a64
        grep "ARM" .file-idx | grep "aarch64" |
          grep "not strip" |
          tr ':' ' ' | awk '{print $1}' |
          while read -r file
            do ./stripp-a64 -s "$file"
          done;;
      arm*)
        cp -rf ${PREFIX}/bin/${TARGET}-strip ./stripp-a32
        grep "ARM" .file-idx | grep "eabi" |
          grep "not strip" |
          tr ':' ' ' | awk '{print $1}' |
          while read -r file
            do ./stripp-a32 -s "$file"
          done;;
    esac
  done

  # clean unused files
  find install -name *.cmake -delete
  find install -name *.la -delete
  find install -name *.a -delete
  rm -rf stripp-* .file-idx
}

git_push(){
  GCC_CONFIG="$(${PREFIX}/bin/aarch64-linux-gnu-gcc -v 2>&1)"
  GCC_VERSION="$(${PREFIX}/bin/aarch64-linux-gnu-gcc --version | head -n1 | cut -d' ' -f4)"
  BUILD_DATE="$(${PREFIX}/bin/aarch64-linux-gnu-gcc --version | head -n1 | cut -d' ' -f5)"
  BINUTILS_VERSION="$(${PREFIX}/bin/aarch64-linux-gnu-ld --version | head -n1 | cut -d' ' -f5)"
  MESSAGE="${PKG_VERSION}-${GCC_VERSION}-${BUILD_DATE}"
  BUILD_TAG="${GCC_VERSION}-${BUILD_DATE}-release"
  
# symlink liblto_plugin.so
  cd ${PREFIX}/lib/bfd-plugins
  ln -sr ../../libexec/gcc/aarch64-linux-gnu/${GCC_VERSION}/liblto_plugin.so .
  cd $WORK_DIR
  
  # Generate archive
  mkdir $WORK_DIR/gcc-repo
  cd ${WORK_DIR}/gcc-repo
  cp -rf ${PREFIX}/* .
  #tar -I"${PREFIX}/bin/zstd --ultra -22 -T0" -cf gcc.tar.zst *
  tar -czvf "${MESSAGE}.tar.gz" *
  cp ${MESSAGE}.tar.gz ${WORK_DIR}
  cd $WORK_DIR
}

build_zstd
for TARGET in ${TARGETS}; do
  build_binutils
  build_gcc
done
strip_binaries
git_push

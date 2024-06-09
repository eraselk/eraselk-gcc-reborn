#!/usr/bin/env bash

echo "*****************************************"
echo "*        Download GCC & Binutils        *"
echo "*****************************************"

export IS_MASTER="${1}"

download() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt-get install -y flex bison ncurses-dev texinfo gcc gperf patch libtool automake g++ libncurses5-dev gawk subversion expat libexpat1-dev python-all-dev binutils-dev bc libcap-dev autoconf libgmp-dev build-essential pkg-config libmpc-dev libmpfr-dev autopoint gettext txt2man liblzma-dev libssl-dev libz-dev mercurial wget tar gcc-10 g++-10 zstd --fix-broken --fix-missing
    git clone -b binutils-2_42 --depth=1 git://sourceware.org/git/binutils-gdb.git binutils
    wget https://ftp.gnu.org/gnu/gcc/gcc-11.1.0/gcc-11.1.0.tar.gz -O gcc-tarball
    tar -xf gcc-tarball
    rm -f gcc-tarball
    mv -f gcc* gcc
    git clone -b v1.5.5 https://github.com/facebook/zstd zstd
  fi
  sed -i '/^development=/s/true/false/' binutils/bfd/development.sh
  cd gcc
  ./contrib/download_prerequisites
  cd ../binutils
  git apply -3 ../patch/compilespeed-binutils.patch || true
  cd ..
}

download

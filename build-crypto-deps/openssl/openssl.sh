#!/bin/sh

set -e

if [ ! -e openssl-0.9.8k.tar.gz ]; then
    curl -O http://www.openssl.org/source/openssl-0.9.8k.tar.gz
fi

# customize the version here
VER=0.9.8k

TOPDIR=`pwd`
BASEDIR="${TOPDIR}/${PLATFORM}_${SDK}_${CONFIG}"
BUILDDIR="${BASEDIR}/openssl-$VER"
MAKEFILE="${BUILDDIR}/Makefile"

mkdir -p "${BASEDIR}"
tar zxvf openssl-${VER}.tar.gz -C "${BASEDIR}"
cd "${BUILDDIR}"

DEBUG_ONOFF=
if [ -n "${DEBUG}" ]; then
    DEBUG_ONOFF=-d
fi

./config ${DEBUG_ONOFF} --openssldir="${PREFIX}"

# add -sysroot to CC=
sed -ie "s!^CFLAG=!CFLAG=${SYSROOT} !" "${MAKEFILE}"

# change the -arch flag
if [ "${PLATFORM}" = "iPhoneOS" ]; then
    sed -ie "s!-arch i386!-arch armv6!" "${MAKEFILE}"
    sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "${BUILDDIR}/crypto/ui/ui_openssl.c"
fi

make && make install


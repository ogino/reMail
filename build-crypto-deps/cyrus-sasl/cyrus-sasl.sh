#!/bin/sh

set -e

if [ ! -e cyrus-sasl-2.1.23.tar.gz ]; then
    curl -O ftp://ftp.andrew.cmu.edu/pub/cyrus-mail/cyrus-sasl-2.1.23.tar.gz
fi

# customize the version here
VER=2.1.23

TOPDIR=`pwd`
BASEDIR="${TOPDIR}/${PLATFORM}_${SDK}_${CONFIG}"
BUILDDIR="${BASEDIR}/cyrus-sasl-$VER"

mkdir -p "${BASEDIR}"
tar zxvf cyrus-sasl-${VER}.tar.gz -C ${BASEDIR}

export CC="${CC}"
export CFLAGS="${SYSROOT} -arch ${ARCH} -pipe -Os -gdwarf-2"
export LDFLAGS="${SYSROOT} -arch ${ARCH}"

DEBUG_ONOFF=
if [ -n "${DEBUG}" ]; then
    DEBUG_ONOFF=--enable-debug
fi

cd "${BUILDDIR}"
./configure \
    --prefix="${PREFIX}" \
    ${DEBUG_ONOFF} \
    --host="${ARCH}-apple-darwin" \
    --disable-shared --enable-static \
    --with-openssl="${PREFIX}"

(cd lib && make)
(cd include && make saslinclude_HEADERS="hmac-md5.h md5.h sasl.h saslplug.h saslutil.h prop.h" install)
(cd lib && make install)

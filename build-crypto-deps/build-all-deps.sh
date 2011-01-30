#!/bin/sh

# list of SDK you want to support 
#
# each library will be compiled 4 times for each given SDK
#   iPhoneSimulator     "Release" version
#   iPhoneSimulator     "Debug" version
#   iPhoneOS            "Release" version
#   iPhoneOS            "Debug" version
#

# NOTE: When changing the iOS SDK you're compiling against, you need
#       to change the line below to reflect the new version
SDKLIST="4.2"

# list of libraries to cross-compile
LIBRARIES="openssl cyrus-sasl"

if [ $# -ne 1 ]; then
    echo "Usage: build-all-deps.sh INSTALLATION_DIR"
    exit 1
fi

# you should leave the following vars unchanged
PREFIX=$1
PLATFORMS="iPhoneSimulator iPhoneOS"
CONFIGS="Debug Release"

GCC_VERSION="4.2"

mkdir -p "${PREFIX}"

for lib in ${LIBRARIES}; do
    for sdk in ${SDKLIST}; do
        for platform in ${PLATFORMS}; do
            PLATFORMDIR="/Developer/Platforms/${platform}.platform"
            BINDIR="${PLATFORMDIR}/Developer/usr/bin"
            SDK="${platform}${sdk}.sdk"
            SDKDIR="${PLATFORMDIR}/Developer/SDKs/${SDK}"

            CC="${BINDIR}/gcc-${GCC_VERSION}"
            CXX="${BINDIR}/g++-${GCC_VERSION}"
            CPP="${BINDIR}/cpp-${GCC_VERSION}"
            SYSROOT="-isysroot ${SDKDIR}"

            ARCH=i386
            if [ "${platform}" = "iPhoneOS" ]; then
                ARCH=armv6
            fi

            for config in ${CONFIGS}; do
                echo "builing ${lib} for ${platform}${sdk} (${config})"

                DEBUG_ONOFF=
                if [ "${config}" = "Debug" ]; then
                    DEBUG_ONOFF=1
                fi

                # redirect stdout and stderr to the log file
                {
                    (cd ${lib} && env \
                        CC="${CC}" \
                        CXX="${CXX}" \
                        CPP="${CPP}" \
                        SYSROOT="${SYSROOT}" \
                        ARCH="${ARCH}" \
                        PREFIX="${PREFIX}/${SDKDIR}/${config}" \
                        PLATFORM="${platform}" \
                        SDK="${SDK}" \
                        CONFIG="${config}" \
                        DEBUG=${DEBUG_ONOFF} \
                    ./${lib}.sh )
                } #> ${lib}-${platform}${sdk}-${config}.log 2>&1 

            done
        done
    done
done


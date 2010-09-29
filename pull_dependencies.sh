#!/usr/bin/sh
# for this to work you need to have the following installed:
# - Xcode 3.1.3 or higher: http://developer.apple.com/
# - git: http://help.github.com/mac-git-installation/
# - mercurial / hg: http://mercurial.berkwood.com/

# pull three20
cd ..
git clone git://github.com/facebook/three20.git

# pull mailcore
hg clone http://bitbucket.org/mronge/mailcore/

# compile crypto libs (cyrus-sasl, openssl)
cd -
cd build-crypto-deps
# set path - in some screwed-up configs, this is missing
export PATH=$PATH:/Developer/usr/bin
sh build-all-deps.sh `pwd`/binaries

# copy crypto libs into the right place (Mailcore subdirectory)
mkdir -p ../../mailcore/libetpan/binaries
cp -R binaries/Developer ../../mailcore/libetpan/binaries/Developer

# libetpan needs openssl / cyrus-sasl to build correctly on iPhone 3.1+
cp -r -v binaries/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.1.sdk/Debug/include/* ../../mailcore/libetpan/build-mac/include/.

# this should be it - you can now open the ReMailIPhone Xcode project
echo "Done - if you didn't see errors, you can now open the ReMailIPhone Xcode project"

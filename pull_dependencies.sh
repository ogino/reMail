#!/usr/bin/sh
# for this to work you need to have the following installed:
# - git: http://help.github.com/mac-git-installation/
# - mercurial / hg: http://mercurial.berkwood.com/
# - wget: http://www.mactricksandtips.com/2008/07/installing-wget-on-your-mac-for-terminal.html

# pull three20
cd ..
git clone git://github.com/facebook/three20.git

# pull mailcore
hg clone http://bitbucket.org/mronge/mailcore/

# compile crypto libs (cyrus-sasl, openssl)
cd -
cd build-crypto-deps
sh build-all-deps.sh `pwd`/binaries

# copy crypto libs into the right place (Mailcore subdirectory)
mkdir -p ../../mailcore/libetpan/binaries
cp -r binaries/Developer ../../mailcore/libetpan/binaries/Developer

# this should be it - you can now open the ReMailIPhone Xcode project
echo "Done - you can now open the ReMailIPhone Xcode project"

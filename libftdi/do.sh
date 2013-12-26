#!/bin/bash
VERSION="1.0"
ARCH="x86_64"
HW=`pwd`
TMP="/tmp/new-libftdi1-dir"
mkdir $TMP

cd $TMP
for FILE in `ls $HW/slackbuild`
do
    ln -s $HW/slackbuild/$FILE ./
done

wget "http://www.intra2net.com/en/developer/libftdi/download/libftdi1-$VERSION.tar.bz2"

ARCH=$ARCH TMP=$TMP VERSION=$VERSION sh libftdi1.SlackBuild


installpkg libftdi1-$VERSION-*.txz

cd $WH
rm -rf $TMP
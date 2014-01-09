#!/bin/bash
HW=`pwd`
TMP=/tmp/new-openocd
if [ -x $TMP ]
then
    rm -rf $TMP
fi
mkdir $TMP
cd $TMP
git clone git://git.code.sf.net/p/openocd/code

cd code
./bootstrap
./configure --enable-ft2232_libftdi1 --enable-vsllink --enable-jlink --enable-usbprog --enable-stlink --libdir=/usr/lib64/ --prefix=/usr
make
make install DESTDIR=$TMP/openocd-pkg
cd $TMP/openocd-pkg
makepkg -c y -l y ../openocd-$VERSION-x86_64-1.txz
installpkg ../openocd-*.txz
cd $HW
#rm -rf $TMP
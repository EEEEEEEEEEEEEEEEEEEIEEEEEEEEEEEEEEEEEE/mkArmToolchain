#!/bin/bash



GNU_WEB="ftp://ftp.gnu.org/gnu/"


GCC_WEB="$GNU_WEB/gcc"
BINUTILS_WEB="$GNU_WEB/binutils"
GDB_WEB="$GNU_WEB/gdb"
NEWLIB_WEB="ftp://sources.redhat.com/pub/newlib"


CURDIR=`pwd`
SRCDIR=$CURDIR/src
if [ ! -d $SRCDIR ]
then
  mkdir $SRCDIR
fi  

PKG_DIR="/tmp/pkg"
READY_PKG_DIR="$CURDIR/pkg"
if [ ! -d $READY_PKG_DIR ]
then
  mkdir $READY_PKG_DIR
fi

PATH="$PATH:/sbin:/usr/sbin"


getVersion()
{
  UTIL=$2
  WEB=$1
  DATELIST=""
  for LINE in `curl "$WEB/" 2> /dev/null |awk '{print $6 "|" $7 "|" $8 "+" $9}'|grep $UTIL `;
  do 
     #echo $LINE
     DATE=`echo $LINE|sed "s/+/ /g"|awk '{print $1}'|sed "s/|/ /g"`
     NAME=`echo $LINE|sed "s/+/ /g"|awk '{print $2}'`
     DATELIST="$DATELIST`date -d "$DATE" +%s ` $NAME\n"
     
  done
  #echo -e $DATELIST
  RES=`echo -e $DATELIST |sort -n |tail -n 1 |awk '{print $2}' |sed "s/$UTIL-//"`
  echo $RES |grep "\.tar" >> /dev/null && RES=`echo $RES|sed 's/\.tar/ /g'|awk '{print $1}'`
  echo $RES
}


get_src_if_needed()
{
    UTIL=$1
    VER=$2
    WEB=$3
    FILE=$UTIL-$VER
    cd $SRCDIR
    echo "1" >> "process_{$FILE}"
    if [ -f "$FILE.tar.gz" ]
      then 
	echo "File '$FILE.tar.gz' already exist!"
	rm "process_{$FILE}"
      else 
	wget "$WEB/$FILE.tar.gz"  -o "process_{$FILE}" && mv "process_{$FILE}" "{$FILE}_downloaded"
    fi
}

#getVersion $GCC_WEB gcc

#getVersion $BINUTILS_WEB binutils
#exit 0
echo "************
Calculating actual version
*************"

echo -n "  GCC Version: "
GCC_VER=`getVersion $GCC_WEB gcc`
echo "$GCC_VER"
echo -n "  NEWLIB Version: "
NEWLIB_VER=`getVersion $NEWLIB_WEB newlib`
echo "$NEWLIB_VER"
echo -n "  BINUTILS Version: " 
BINUTILS_VER=`getVersion $BINUTILS_WEB binutils`
echo "$BINUTILS_VER"
echo -n "  GDB Version: "
GDB_VER=`getVersion $GDB_WEB gdb`
echo "$GDB_VER"

echo "************
Getting sources
*************"
get_src_if_needed gcc $GCC_VER $GCC_WEB/gcc-$GCC_VER &
get_src_if_needed binutils $BINUTILS_VER $BINUTILS_WEB &
get_src_if_needed gdb $GDB_VER $GDB_WEB &
get_src_if_needed newlib $NEWLIB_VER $NEWLIB_WEB &
sleep 1
while ls $SRCDIR |grep process >>/dev/null
do
    echo "wait..." > /dev/null
done

TARGET='arm-none-eabi'
PKG_PREFIX='arm_none_eabi'
PKG_SUFFIX='1'
MAKE_PREFIX=' -j 5'
PREFIX=/usr/
LIBDIR=/usr/lib64/
#ARCH=arm
CROSS_COMPILE=${TARGET}-
PATH=$PATH:${PREFIX}/bin

config()
{
  if [[ $BUILD_DIR = "true" ]]; then
    echo "../configure"
  else
    echo "./configure"
  fi
}


make_binutils()
{
    if [ -f "/var/log/packages/binutils_$PKG_PREFIX-$BINUTILS_VER-x86_64-${PKG_SUFFIX}" ]
      then 
	echo "package binutils_$PKG_PREFIX-$BINUTILS_VER-x86_64-${PKG_SUFFIX} installed!"
      else
        cd $SRCDIR
        tar -xf binutils*.tar.*z
	cd $SRCDIR/binutils-$BINUTILS_VER

	mkdir build; cd build; BUILD_DIR="true"
	if [ -d build ] 
	  then rm -rf build
	fi

      
	`config` \
	    --prefix=${PREFIX} \
	    --libdir=${LIBDIR} \
	    --target=${TARGET} \
	    --disable-nls \
	    2>&1
	echo "
	********
	**MAKE**
	********
	"
	make  2>&1 || exit 1
	echo "
	****************
	**MAKE INSTALL**
	****************
	"
	make install DESTDIR=$PKG_DIR/binutils-$BINUTILS_VER ||exit 1
	cd $PKG_DIR/binutils-$BINUTILS_VER ||exit 1
	makepkg --linkadd y --chown n $READY_PKG_DIR/binutils_$PKG_PREFIX-$BINUTILS_VER-x86_64-$PKG_SUFFIX.txz
	installpkg $READY_PKG_DIR/binutils_$PKG_PREFIX-$BINUTILS_VER-x86_64-$PKG_SUFFIX.txz
    fi
}
#---------------GCC--------------------

make_gcc()
{
    if [ -f /var/log/packages/gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX}_pre ]
      then 
	echo "package gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX}_pre installed!"
      else
	if [ -f /var/log/packages/gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX} ]
	then 
	  echo "package gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX} installed!"
	else
          cd $SRCDIR
          tar -xf gcc*.tar.*z
	  cd $SRCDIR/gcc-$GCC_VER
	  if [ -d build ] 
	    then rm -rf build
	  fi
	  mkdir build; cd build; BUILD_DIR="true"

#	  AR_FOR_TARGET=<xscale-ar> \
	  BUILD_CC=gcc AR=ar RANLIB=ranlib AS=as LD=ld `config` \
	      --with-newlib\
	      --prefix=${PREFIX} \
	      --libdir=${LIBDIR} \
	      --target=${TARGET} \
	      --enable-languages=c \
	      --disable-shared --disable-nls --disable-libssp \
	      2>&1 || exit 1

	  echo "
	  ********
	  **MAKE**
	  ********
	  "
	  make 2>&1 || exit 1
	  echo "
	  ****************
	  **MAKE INSTALL**
	  ****************
	  "
	  make install DESTDIR=$PKG_DIR/gcc-$GCC_VER ||exit 1
	  cd $PKG_DIR/gcc-$GCC_VER ||exit 1
	  makepkg --linkadd y --chown n $READY_PKG_DIR/gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX}_pre.txz
	  installpkg $READY_PKG_DIR/gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX}_pre.txz
      fi
    fi
}
make_newlib()
{
    if [ -f "/var/log/packages/newlib_$PKG_PREFIX-$NEWLIB_VER-x86_64-$PKG_SUFFIX" ]
      then 
	echo "package newlib_$PKG_PREFIX-$NEWLIB_VER-x86_64-$PKG_SUFFIX installed!"
      else
	cd $SRCDIR
	tar -xf newlib*.tar.*z
        cd $SRCDIR/newlib-$NEWLIB_VER
	if [ -d build ] 
	  then rm -rf build
	fi
	mkdir build; cd build; BUILD_DIR="true"
	CFLAGS_FOR_TARGET="-mthumb -mcpu=cortex-m3" \
	 ../configure --prefix=${PREFIX} --libdir=${LIBDIR} --target=${TARGET} \
	    --with-mode=thumb \
	    --enable-multilib \
	    --disable-nls \
	    --with-gnu-as --with-gnu-ld\
	    --enable-interwork \
	    --disable-newlib-supplied-syscalls \
	    --enable-static-nss \
	    2>&1 || exit 1

	echo "
	********
	**MAKE**
	********
	"
	CFLAGS_FOR_TARGET="-ffunction-sections -fdata-sections -DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -Os -fomit-frame-pointer -mcpu=cortex-m3 -mthumb -D__thumb2__ -D__BUFSIZ__=256" CCASFLAGS="-mcpu=cortex-m3 -mthumb -D__thumb2__"\
	make 2>&1 || exit 1
	echo "
	****************
	**MAKE INSTALL**
	****************
	"
	make install DESTDIR=$PKG_DIR/newlib-${NEWLIB_VER}_2 ||exit 1
	cd $PKG_DIR/newlib-${NEWLIB_VER}_2 ||exit 1
	makepkg --linkadd y --chown n $READY_PKG_DIR/newlib_$PKG_PREFIX-$NEWLIB_VER-x86_64-$PKG_SUFFIX.txz
	installpkg $READY_PKG_DIR/newlib_$PKG_PREFIX-$NEWLIB_VER-x86_64-$PKG_SUFFIX.txz
    fi
}
make_gcc2()
{
    if [ -f "/var/log/packages/gcc_$PKG_PREFIX-$GCC_VER-x86_64-$PKG_SUFFIX" ]
      then 
	echo "package gcc_$PKG_PREFIX-$GCC_VER-x86_64-$PKG_SUFFIX installed!"
      else

	cd $SRCDIR
	tar -xf gcc*.tar.*z
	cd $SRCDIR/gcc-$GCC_VER
	if [ -d build ] 
	  then rm -rf build
	fi
	mkdir build; cd build; BUILD_DIR="true"


	BUILD_CC=gcc AR=ar RANLIB=ranlib AS=as LD=ld `config` \
	    --prefix=${PREFIX} \
	    --libdir=${LIBDIR} \
	    --target=${TARGET} \
	    --enable-languages=c,c++ --disable-multilib \
	    --with-newlib \
	    --without-headers --disable-shared --disable-libssp --disable-nls \
	    --disable-hardfloat --enable-threads=single --with-gnu-as --with-gnu-ld\
	    2>&1 || exit 1

	echo "
	********
	**MAKE**
	********
	"
	make 2>&1 || exit 1
	echo "
	****************
	**MAKE INSTALL**
	****************
	"
	make install DESTDIR=$PKG_DIR/gcc-${GCC_VER}_2 ||exit 1
	cd $PKG_DIR/gcc-${GCC_VER}_2 ||exit 1
	makepkg --linkadd y --chown n $READY_PKG_DIR/gcc_$PKG_PREFIX-$GCC_VER-x86_64-$PKG_SUFFIX.txz
	removepkg $READY_PKG_DIR/gcc_$PKG_PREFIX-$GCC_VER-x86_64-${PKG_SUFFIX}_pre.txz
	installpkg $READY_PKG_DIR/gcc_$PKG_PREFIX-$GCC_VER-x86_64-$PKG_SUFFIX.txz
    fi
}

make_gdb()
{
    if [ -f "/var/log/packages/gdb_$PKG_PREFIX-$GDB_VER-x86_64-$PKG_SUFFIX" ]
    then
	echo "GDB already installed"
    else
        cd $SRCDIR
        tar -xf gdb*.tar.*z
	cd $SRCDIR/gdb-$GDB_VER

        mkdir build; cd build; BUILD_DIR="true"

	`config` \
    	    --prefix=${PREFIX} \
    	    --libdir=${LIBDIR} \
    	    --target=${TARGET} \
	    --enable-interwork --disable-multilib \
    	    2>&1 || exit 1

        echo "
        ********
        **MAKE**
        ********
        "
        make || exit 1 
        echo "
        ****************
        **MAKE INSTALL**
        ****************
        "
        make install DESTDIR=$PKG_DIR/gdb-$GDB_VER 2>&1 || exit 1
        cd $PKG_DIR/gdb-$GDB_VER || exit 1
        makepkg --linkadd y --chown n $READY_PKG_DIR/gdb_$PKG_PREFIX-$GDB_VER-x86_64-$PKG_SUFFIX.txz
        installpkg $READY_PKG_DIR/gdb_$PKG_PREFIX-$GDB_VER-x86_64-$PKG_SUFFIX.txz
    fi
}
#---------------GLIBC--------------------
make_glibc()
{
    cd $SRCDIR/glibc-$GLIBC_VER

    mkdir build; cd build; BUILD_DIR="true"

    #--prefix=/usr --host=${TARGET} --enable-add-ons=linuxthreads --with-headers=${SYSROOT}/usr/include 2>&1
    `config`\
        --prefix=${PREFIX} \
        --libdir=${LIBDIR} \
        --host=${TARGET} \
	--enable-add-ons \
        2>&1 || exit 1

    echo "
    ********
    **MAKE**
    ********
    "
    make  2>&1 |tee $CURDIR/make_glibc.out 
    echo "
    ****************
    **MAKE INSTALL**
    ****************
    "
    make install DESTDIR=$PKG_DIR/glibc-$GLIBC_VER 2>&1 || exit 1
    cd $PKG_DIR/glibc-$GLIBC_VER || exit 1
    makepkg --linkadd y --chown n $READY_PKG_DIR/glibc_$PKG_PREFIX-$GLIBC_VER-x86_64-$PKG_SUFFIX.txz
    installpkg $READY_PKG_DIR/glibc_$PKG_PREFIX-$GLIBC_VER-x86_64-$PKG_SUFFIX.txz
}

run_log()
{
    echo "Run $1"
    cd $CURDIR
    rm $1.log.old 2>/dev/null
    mv $1.log $1.log.old 2>/dev/null
    touch $1.log
    tail -f $1.log &
    TMP_PID=$!
    make_$1 2>&1 >> $1.log || exit 1
    kill $TMP_PID
}
run_log binutils || exit 1
run_log gcc || exit 1
run_log newlib || exit 1
run_log gcc2 || exit 1
run_log gdb || exit 1
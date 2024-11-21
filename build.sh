#!/bin/bash
PKGNAME=$1
SH_PATH=$(readlink -f `dirname "$0"`)
PKG_LOCATION_PATH="/tmp/2022"
DEB_OPT="dd"

errlog(){
   echo $1;
   exit 1;
}

copy_dir(){
                rsync -ra $SH_DIR/$PKGNAME /build
                cd /build/$PKGNAME
}

if [ ! -n "$PKGNAME" ];then
	errlog "Useage: ./build.sh pve-common"
fi

if [ ! -d "$SH_PATH/packages/$PKGNAME" ];then
	errlog "$PKGNAME is not exsited!"
fi

if [ -n "$PKG_DIR" ];then
	PKG_LOCATION_PATH=$PKG_DIR
fi

if [ -n "$DEB_BUILD_OPTIONS" ];then
        DEB_OPT=$DEB_BUILD_OPTIONS
fi

dscflag="dsc"

if [[  "$DEB_BUILD_OPTIONS" == *"nodsc"*   ]];then
	dscflag="nodsc"
fi

echo  "--------------info------------------"
echo  "This is Proxmox-Port package build scripts"
echo  "Package is $PKGNAME"
echo  "Docker build is $BUILDERNAME"
echo  "Package dir is $PKG_LOCATION_PATH/$PKGNAME"
if [ -n "$DEB_BUILD_OPTIONS" ];
then
	echo "DEB_BUILD_OPTIONS = $DEB_BUILD_OPTIONS"
fi
echo  "--------------start-----------------"

dockerbuild(){
	rm $SH_PATH/packages/$PKGNAME/$PKGNAME/pvebuild -rf
	if [ -n "$BUILDERNAME"  ];then
		docker run -it -e DEB_BUILD_OPTIONS=$DEB_OPT  -e PKGDIR=$SH_PATH/packages/$PKGNAME/$PKGNAME -v $SH_PATH/:$SH_PATH --name $PKGNAME --rm $BUILDERNAME || errlog "builderror"
	else
		docker run -it -e DEB_BUILD_OPTIONS=$DEB_OPT  -e PKGDIR=$SH_PATH/packages/$PKGNAME/$PKGNAME  -v $SH_PATH/:$SH_PATH --name $PKGNAME --rm pvebuilder || errlog "builderror"
	fi
}

upload_pkg(){
	mkdir $PKG_LOCATION_PATH/$PKGNAME -p
	find "$SH_PATH/packages/$PKGNAME/$PKGNAME" -name "*.deb" -exec cp {} $PKG_LOCATION_PATH/$PKGNAME \;
	find "$SH_PATH/packages/$PKGNAME/$PKGNAME" -name "*.buildinfo" -exec cp {} $PKG_LOCATION_PATH/$PKGNAME \;
	find "$SH_PATH/packages/$PKGNAME/$PKGNAME" -name "*.changes" -exec cp {} $PKG_LOCATION_PATH/$PKGNAME \;
	find "$SH_PATH/packages/$PKGNAME/$PKGNAME" -name "*.dsc" -exec cp {} $PKG_LOCATION_PATH/$PKGNAME \;
	find "$SH_PATH/packages/$PKGNAME/$PKGNAME" -name "*.tar*" -exec cp {} $PKG_LOCATION_PATH/$PKGNAME \;
	for i in `ls $PKG_LOCATION_PATH/$PKGNAME/*.deb`;
		do
		md5sum $i > $i.md5
		cat $i.md5
	done
	for i in `ls $PKG_LOCATION_PATH/$PKGNAME/*.buildinfo`;
                do
                md5sum $i > $i.md5
                cat $i.md5
        done

        for i in `ls $PKG_LOCATION_PATH/$PKGNAME/*.changes`;
                do
                md5sum $i > $i.md5
                cat $i.md5
        done

	if [ $dscflag == "dsc" ];then
        	for i in `ls $PKG_LOCATION_PATH/$PKGNAME/*.dsc`;
	                do
                	md5sum $i > $i.md5
	                cat $i.md5
        	done
	        for i in `ls $PKG_LOCATION_PATH/$PKGNAME/*.tar*`;
        	        do
                	md5sum $i > $i.md5
	                cat $i.md5
        	done
	fi

}

update_submodues(){
	rm $SH_PATH/packages/$PKGNAME/$PKGNAME/ -rf
	mkdir $SH_PATH/packages/$PKGNAME/$PKGNAME/
	git submodule update --init --recursive "$SH_PATH/packages/$PKGNAME/$PKGNAME"
}

update_submodues || errlog  "Failed to update submodule"

if [ -f "$SH_PATH/packages/$PKGNAME/series" ];then
	cd "$SH_PATH/packages/$PKGNAME/$PKGNAME"
	for i in `cat $SH_PATH/packages/$PKGNAME/series`;
                do patch -p1 < $SH_PATH/packages/$PKGNAME/$i
        done
fi

ARCH=$(arch)

if [ -f "$SH_PATH/packages/$PKGNAME/series.$ARCH" ];then
        cd "$SH_PATH/packages/$PKGNAME/$PKGNAME"
        for i in `cat $SH_PATH/packages/$PKGNAME/series.$ARCH`;
                do patch -p1 < $SH_PATH/packages/$PKGNAME/$i
        done
fi

cd $SH_PATH

dockerbuild
upload_pkg || errlog "upload pkg failed"


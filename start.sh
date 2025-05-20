#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
echo $LD_LIBRARY_PATH
echo "Sleep 20s"
sleep 20

if [ -d /media/ramdisk ]; then
	echo "/media/ramdisk exists"
	echo $sudoPW | sudo -S rmdir /media/ramdisk
	sudo mkdir /media/ramdisk
else 
	echo "/media/ramdisk not exists"
	echo $sudoPW | sudo mkdir /media/ramdisk
fi


sudo mount -t ramfs -o size=2048 ramfs /media/ramdisk
sudo chmod 0777 /media/ramdisk

cd /media/truecrypt1/App
dotnet /media/truecrypt1/App/StartJazm.dll

#!/bin/bash

if [ $EUID -ne 0 ];then
	echo "[!] You are not root."
	exit 1;
fi

if [ `systemctl get-default` != 'rescue.target' ];then
	echo "[!] Error. The system target is not rescue.target. Try running <systemctl isolate rescue.target> and execute the script again."
	exit 10;
fi

CRYPT_TOOL=`which cryptsetup`

if [ $? -eq 0 ];then
	echo "[+] Cryptsetup tool is installed"
else
	echo "[!] Cryptsetup is not installed. Run the following command <apt install cryptsetup>"
	exit 2;
fi


echo "[+] Making a backup of the home folder..."

if [ -d /homebackup ]; then
	cp -av /home/* /homebackup
	echo "[+] Backup done in /homebackup"
else
	mkdir /homebackup
	cp -av /home/* /homebackup
	echo "[+] Backup done in /homebackup"
fi

echo "[+] Listing the partitions:"

lsblk

read -p "Type the partition of /home: " PARTITION

BLKID="UUID="`blkid $PARTITION | cut -d "" -f2 | cut -d\" -f2`

sed -e "/$BLKID/ s/^#*/#/" -i /etc/fstab

umount $PARTITION

if [ $? -eq 0 ];then
	echo "[+] $PARTITION dismounted"
else
	echo "[!] Error. $PARTITION could not be dismounted."
	exit 3;
fi

cryptsetup -v --cipher aes-xts-plain64 -s 512 -h sha512 -i 1000 --use-random -y luksFormat $PARTITION

if [ $? -eq 0 ];then
	echo "[+] $PARTITION have been encrypted successfuly."
else
	echo "[!] Error. $PARTITION could not be encrypted."
	exit 4;
fi

cryptsetup luksOpen $PARTITION chome

echo "[+] Formatting the partition..."

mkfs.ext4 /dev/mapper/chome

if [ $? -eq 0 ];then
	echo "[+] $PARTITION have been formatted."
else
	echo "[!] Error. $PARTITION could not be formatted."
	exit 5;
fi

if [ -e /etc/crypttab ];then
	echo "chome $PARTITION none luks,timeout=60 cipher=aes-xts-plain64,size=512" >> /etc/crypttab
else
	echo "[!] /etc/crypttab file does not exist. Creating the file..."
	echo "chome $PARTITION none luks,timeout=60 cipher=aes-xts-plain64,size=512" >> /etc/crypttab
fi

echo "[+] Adding the encrypted partition to the /etc/fstab..."

echo "/dev/mapper/chome    /home    ext4    rw,relatime,data=ordered    0    2" >> /etc/fstab

mount /dev/mapper/chome /home

if [ $? -eq 0 ];then
	echo "[+] $PARTITION have been mounted successfuly."
else
	echo "[!] Error. $PARTITION could not be mounted."
	exit 7;
fi

cp -av /homebackup/* /home/

if [ $? -eq 0 ];then
	rm -r /homebackup
fi

echo "Restarting this computer..."

sleep 2

init 6


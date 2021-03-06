#!/bin/bash
read -p "是否已先sudo raspi-config 做 Expand Filesystem (y/n)" expand
if [ "${expand}" == "Y" ] || [ "${expand}" == "y" ]; then
	x=0	# 沒東西出現error @@
elif [ "${expand}" == "N" ] || [ "${expand}" == "n" ]; then
	echo "請先Expand Filesystem以避免安裝空間不足"
	exit 0 
else
	echo "Error input"
fi
sudo fdisk -l
echo "顯示硬碟分割表，尋找你的外接裝置"
read -p "輸入你的硬碟位置(ex:/dev/sda1): " diskpwd
read -p "是否需要格式化?(y/n): " yn
read -p "選擇格式化格式(1:NTFS  2.Ext4 3.回上一步)請輸入1 or 2 or 3: " mkfstype
read -p "你的NAS要建在哪?(請輸入絕對位置ex:/media/NAS): " naspwd
read -p "設定samba的目錄(請輸入絕對位置ex:/media/NAS): " sambapwd
read -p "samba登入帳號: " smbname
read -p "samba登入密碼: " smbpasswd
read -p "是否安裝transmission?(y/n): " transmissionyn
if [ "${transmissionyn}" == "Y" ] || [ "${transmissionyn}" == "y" ]; then
	read -p "transmission登入帳號: " rpcname
	read -p "transmission登入密碼: " rpcpasswd
fi
if [ "${transmissionyn}" == "N" ] || [ "${transmissionyn}" == "n" ]; then
	x=0
else
        echo "Error input"
fi
echo "開始安裝....    需費時40分UP _(:3」∠)_"

echo "update & upgrade ........."
sleep 1
sudo apt-get update 
sudo apt-get upgrade -y 

#====================#
# Adding USB Storage #
#====================#
#sudo fdisk -l
#echo "顯示硬碟分割表，尋找你的外接裝置"
#read -p "輸入你的硬碟位置(ex:/dev/sda1): " diskpwd
ynflag=0
mkfstypeflag=0
while [ "${ynflag}" != "1" ]
do
#	read -p "是否需要格式化?(y/n)" yn
	if [ "${yn}" == "Y" ] || [ "${yn}" == "y" ]; then
		while [ "${mkfstypeflag}" != "1" ]
		do
#			read -p "選擇格式化格式(1:NTFS  2.Ext4 3.回上一步)請輸入1 or 2 or 3: " mkfstype
			if [ "${mkfstype}" == "1" ];then
				mkfstypeflag=1
				sudo apt-get install ntfs-3g -y -qq
				sudo mkfs.ntfs $diskpwd -f -I
				ynflag=1
			fi
			if [ "${mkfstype}" == "2" ];then
				mkfstypeflag=1
				sudo echo "y" | sudo mkfs -t ext4 $diskpwd                   #無法自動回答
				ynflag=1
			fi
			if [ "${mkfstype}" == "3" ];then
				break
			else
				echo "Error input"
			fi
		done
	fi
	if [ "${yn}" == "N" ] || [ "${yn}" == "n" ]; then
		ynflag=1
	else
		echo "Error input"
	fi
done

# 建立NAS,samba目錄
#read -p "你的NAS要建在哪?(請輸入絕對位置ex:/media/NAS)" naspwd
sudo mkdir -p $naspwd
sudo mkdir -p $sambapwd
# 修改目錄擁有者
sudo chown -R pi:pi $naspwd
sudo chown -R pi:pi $sambapwd


# 掛載
echo "fstab 的device設定使用磁碟裝置檔名(ex:/dev/sda1)"
echo "建議自行改成UUID"
sleep 2
# 可使用 ls -l /dev/disk/by-uuid/
#     或 sudo blkid
# 來查看UUID
sudo mount $diskpwd $naspwd
if [ "${mkfstype}" == "1" ];then			#下面這行還未測試
	sudo mount -t ntfs-3g $diskpwd $naspwd
	sudo tee -a /etc/fstab<<EOF
	$diskpwd       $naspwd      ntfs    defaults          0       0
EOF								
fi
if [ "${mkfstype}" == "2" ];then
	#sudo echo "$diskpwd       $naspwd      ext4    defaults          0       0" >>/etc/fstab
	sudo mount -t ext4 $diskpwd $naspwd
	sudo tee -a /etc/fstab<<EOF
	$diskpwd       $naspwd      ext4    defaults          0       0
EOF
fi

#===========#
# 安裝samba #
#===========#
echo "安裝samba"
sudo apt-get install samba samba-common-bin -y -qq
# 備份設定檔
#read -p "設定samba的目錄(請輸入絕對位置ex:/media/NAS):" sambapwd
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.old
# 設定samba設定檔
sudo tee -a /etc/samba/smb.conf <<EOF
[PiNas]
comment = PiNas
path = $sambapwd
valid users = $smbname
browseable = yes
create mask = 0660
directory mask = 0771
read only = no
guest ok = no
locking = no
EOF
echo "samba restart"
sudo /etc/init.d/samba restart
#sudo echo "$smbpasswd $smbpasswd" | sudo smbpasswd -a $smbname                   #無法自動回答 
echo "$smbpasswd" >> pass.tmp
echo "$smbpasswd" >> pass.tmp
sudo smbpasswd -a $smbname < pass.tmp
sudo rm -f pass.tmp

#===================#
# 安裝 Transmission #
#===================#
if [ "${transmissionyn}" == "Y" ] || [ "${transmissionyn}" == "y" ]; then
sudo apt-get install transmission-daemon -y -qq
sudo killall transmission-daemon
sudo cp /var/lib/transmission-daemon/info/settings.json /var/lib/transmission-daemon/info/settings.json.old
sudo mkdir -p $naspwd/BT/Bt_inprogress
#read -p "transmission登入帳號: " rpcname
#read -p "transmission登入密碼: " rpcpasswd
# 細部設定 https://trac.transmissionbt.com/wiki/EditConfigFiles
sudo bash -c 'cat > /var/lib/transmission-daemon/info/settings.json' <<EOF
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "blocklist-url": "http://www.example.com/blocklist",
    "cache-size-mb": 4,
    "dht-enabled": true,
    "download-dir": "$naspwd/BT",
    "download-limit": 100,
    "download-limit-enabled": 0,
    "download-queue-enabled": true,
    "download-queue-size": 10,
    "encryption": 0,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "$naspwd/BT/Bt_inprogress",
    "incomplete-dir-enabled": true,
    "lpd-enabled": true,
    "max-peers-global": 220,
    "message-level": 1,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 59926,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": true,
    "peer-socket-tos": "default",
    "pex-enabled": true,
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "prefetch-enabled": 1,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "rpc-authentication-required": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-enabled": true,
    "rpc-password": "$rpcpasswd",
    "rpc-port": 9091,
    "rpc-url": "/transmission/",
    "rpc-username": "$rpcname",
    "rpc-whitelist": "*.*.*.*",
    "rpc-whitelist-enabled": false,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "speed-limit-down": 3000,
    "speed-limit-down-enabled": true,
    "speed-limit-up": 100,
    "speed-limit-up-enabled": true,
    "start-added-torrents": true,
    "trash-original-torrent-files": false,
    "umask": 18,
    "upload-limit": 100,
    "upload-limit-enabled": 0,
    "upload-slots-per-torrent": 14,
    "utp-enabled": true
}
EOF
sudo service transmission-daemon reload
sudo service transmission-daemon restart
#sudo service transmission-daemon status
sudo insserv transmission-daemon                #update-rc.d servicename defaults
sudo usermod -a -G $rpcname debian-transmission
sudo chmod -R 775 $naspwd/BT
fi
#==============#
# 安裝watchdog #
#==============#
sudo modprobe bcm2708_wdog
	sudo tee -a /etc/modules <<EOF
bcm2708_wdog
EOF

sudo tee -a /etc/watchdog.conf <<EOF
max-load-1              = 24
watchdog-device = /dev/watchdog
EOF
sudo apt-get install watchdog chkconfig -y
sudo chkconfig watchdog on
sudo /etc/init.d/watchdog start

if [ "${transmissionyn}" == "Y" ] || [ "${transmissionyn}" == "y" ]; then
sudo service transmission-daemon status
echo "如果transmission-daemon 狀態為failed"
echo "可能是設定檔出問題，可以用下面指令復原就設定檔"
echo "sudo cp /var/lib/transmission-daemon/info/settings.json.old /var/lib/transmission-daemon/info/settings.json"
echo "sudo service transmission-daemon restart"
echo "如果依然不行，請重新新安裝"
echo "參考資料：http://wwssllabcd.github.io/blog/2013/04/22/how-to-setup-transmission-deamon-in-raspberry-pi/"
echo "設定檔參考：https://trac.transmissionbt.com/wiki/EditConfigFiles"
fi



echo "安裝結束 Have fun (“￣▽￣)-o█"
#=============#
#  Reference  #
#==============
#  格式化,mount,samba
#	http://linux.vbird.org/
#	man
#  transmission-daemon
#	http://wwssllabcd.github.io/blog/2013/04/22/how-to-setup-transmission-deamon-in-raspberry-pi/
#	https://trac.transmissionbt.com/wiki/EditConfigFiles
#  watchdog
#	http://pi.gadgetoid.com/article/who-watches-the-watcher
#
#


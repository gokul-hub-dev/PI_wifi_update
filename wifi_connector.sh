#!/bin/bash

wifi_lost_flag="/tmp/.wifi_connection_lost"
wifi_lnf_count=0

if [ "$(systemctl is-active NetworkManager)"="active" ]; then
    echo "NetworkManager is running. Stopping it..."
    sudo systemctl stop NetworkManager
else
    echo "NetworkManager is already stopped."
fi

if [ "$(systemctl is-enabled NetworkManager)"="enabled" ]; then
    echo "NetworkManager is enabled. Disabling it..."
    sudo systemctl disable NetworkManager
else
    echo "NetworkManager is already disabled."
fi

function restart_wpa(){
	echo "kill wpa_supplicat"
	sudo killall wpa_supplicant
	cat /etc/wpa_supplicant/wpa_supplicant.conf
	sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf -D nl80211,wext
	sudo dhclient wlan0
}
function Download_wifi_credentials(){
	cp -f /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/last_wifi.conf
	FILEID=`cat CloudFileDetails.txt | grep fileId | awk -F'"' '{print $2}'`
	FILENAME=`cat CloudFileDetails.txt | grep fileName | awk -F'"' '{print $2}'`
	WIFIFILE="/tmp/${FILENAME}"
	#curl -L -o "$WIFIFILE" "https://drive.google.com/uc?export=download&id=${FILEID}"
	curl -L -o "$WIFIFILE" "https://docs.google.com/document/d/${FILEID}/export?format=txt"
	if [ $? -ne 0 ]; then
		echo "Download wifi credentials failed"
      		return 1
	fi
	ssid=`cat "$WIFIFILE" | grep ssid | awk -F'"' '{print $2}'`
	pass=`cat "$WIFIFILE" | grep password | awk -F'"' '{print $2}'`
	echo "ssid : $ssid"
	echo "pass : $pass"
	if [ -n "$ssid" ] || [ -n "$pass" ]; then
		sed -i "/^\s*ssid=/c\    ssid=\"$ssid\"" /etc/wpa_supplicant/wpa_supplicant.conf
		sed -i "/^\s*psk=/c\    psk=\"$pass\"" /etc/wpa_supplicant/wpa_supplicant.conf
	fi
}

pidof_wpa=$(pgrep wpa_supplicant)
if [ -n "$pidof_wpa" ]; then
	echo "restart wpa"
	restart_wpa
fi

pid_wifi_monitor=$(pgrep wifi_monitor.sh)
if [ -z "$pid_wifi_monitor" ]; then
    ./wifi_monitor.sh &
    echo "execute wifi_monitor.sh"
fi
while true; do
	if [ -f "$wifi_lost_flag" ]; then
	        #connect to lnf
		if [ ! -f "/tmp/lnf_InProgess" ]; then
			cp -f /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/last_wifi.conf
			cp -f /etc/wpa_supplicant/lnf_wifi.conf /etc/wpa_supplicant/wpa_supplicant.conf
			touch /tmp/lnf_InProgess
		fi
		#cp -f /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/last_wifi.conf
		#cp -f /etc/wpa_supplicant/lnf_wifi.conf /etc/wpa_supplicant/wpa_supplicant.conf
		restart_wpa
		echo "connect to lnf"
		sleep 40
		ping -c 3 -w 3 8.8.8.8 > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Download wifi creadentials from cloud"
			Download_wifi_credentials
			if [ $? -eq 0 ]; then
				restart_wpa				
				sleep 40
				ping -c 3 -w 3 8.8.8.8 > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					cp -f /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/last_wifi.conf	
					rm -f /tmp/lnf_InProgess
					rm -f "$wifi_lost_flag"
				fi
			fi
		else
			wifi_lnf_count=$((wifi_lnf_count+1))
			if [ $wifi_lnf_count -ge 2 ]; then
				cp -f /etc/wpa_supplicant/last_wifi.conf /etc/wpa_supplicant/wpa_supplicant.conf
				restart_wpa
				ping -c 3 -w 3 8.8.8.8 > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					rm -f /tmp/lnf_InProgess
					rm -f "$wifi_lost_flag"
				fi
			fi
		fi
        fi
	echo "wifi_connector.sh running..."
        sleep 10
done

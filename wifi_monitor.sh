#!/bin/bash
wifi_lost_flag="/tmp/.wifi_connection_lost"
wifi_lost_counter=0
while true; do 
	ping -c 3 -w 3 8.8.8.8 > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		wifi_lost_counter=$((wifi_lost_counter + 1))
	else
		wifi_lost_counter=0
	fi
	if [ $wifi_lost_counter -ge 20 ]; then
		touch "$wifi_lost_flag"
	fi
	sleep 6
done

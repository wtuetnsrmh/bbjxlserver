#!/bin/sh
rm -f t.log
clinum=$1
host="127.0.0.1"
port=9898
if [ ! $clinum ]; then
	clinum=1
fi;
for ((i=1;i<=clinum;i++)); do
	curl -G -d name=xiefan$i 115.29.193.94:8686/proxy >> t.log
done;
lua gamescripts/robot.lua $host $port $clinum

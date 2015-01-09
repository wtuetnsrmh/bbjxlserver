#! /bin/sh

dir=`dirname $0`

cd $dir
if [ -d /proc/`cat skynet.pid` ]; then
        kill `cat skynet.pid`
fi

if [ -f "server.log" ]; then
        mv "server.log" "server.log"-`date +%s`
fi

./skynet gamescripts/config
cd 
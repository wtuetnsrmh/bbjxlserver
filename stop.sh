#! /bin/sh

dir=`dirname $0`

cd $dir
if [ -d /proc/`cat skynet.pid` ]; then
        kill `cat skynet.pid`
fi
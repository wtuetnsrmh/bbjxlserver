#!/bin/bash

proc_all()
{
	for file in `find $1 -name "*.csv" -type f` 
	do
		dos2unix $file
	done
}

proc_all "./csv"


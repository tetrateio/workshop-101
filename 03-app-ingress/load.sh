#!/usr/bin/env bash
echo "Loading endpoint: $1"
for ((n=0;n<20;n++))
do
    result=$(curl -m 5 -k -s -o /dev/null -I -w "%{http_code}" "$1")
    echo $(date) --  status code: "$result"
done



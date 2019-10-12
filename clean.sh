#!/bin/bash
x=$(ls -R data| awk '
/:$/&&f{s=$0;f=0}
/:$/&&!f{sub(/:$/,"");s=$0;f=1;next}
NF&&f{ print s"/"$0 }' | grep exp)
arr=(`echo ${x}`);
echo "${arr[5]}"
for i in "${arr[@]}"
do
python clean_purchase.py $i &
done

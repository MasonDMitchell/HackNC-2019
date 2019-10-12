#!/bin/bash

download_list=(   
    https://www.bls.gov/cex/pumd/data/comma/diary08.zip
    https://www.bls.gov/cex/pumd/data/comma/diary09.zip
    https://www.bls.gov/cex/pumd/data/comma/diary10.zip
    https://www.bls.gov/cex/pumd/data/comma/diary11.zip
)
for i in "${download_list[@]}"; do
    wget -N "$i"
    unzip $(basename "$i")
done

# for ((i=0;i<${#array[@]};++i)); do
#     printf "%s is in %s\n" "${array[i]}" "${array2[i]}"
# done
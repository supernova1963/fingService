#!/usr/bin/env bash
rm controls_fingService.txt
find ./FHEM -type f \( ! -iname ".*" \) -print0 | while IFS= read -r -d '' f;
  do
   echo "DEL ${f}" >> controls_fingService.txt
   out="UPD "$(stat -f "%Sm" -t "%Y-%m-%d_%T" $f)" "$(stat -f%z $f)" ${f}"
   echo ${out//.\//} >> controls_fingService.txt
done

# CHANGED file
echo "fingService last changes:" > CHANGED
echo $(date +"%Y-%m-%d") >> CHANGED
echo " - $(git log -1 --pretty=%B)" >> CHANGED

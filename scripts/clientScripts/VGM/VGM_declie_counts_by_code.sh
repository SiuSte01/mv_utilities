###broken, need to do this in R so we can calculate a count

for i in `cat raw_claims.tab | cut -f7 | grep -v CODE | sort -u`
do
 echo $i
 head -n1 raw_claims.tab > "$i"_sub.txt
 grep -w $i raw_claims.tab >> "$i"_sub.txt

 perl /vol/cs/CHAMPS_Technical/hms_delivery/bin/decile --in "$i"_sub.txt --out "$i"_ranks.txt --group NONE --atom PIID --score Count --ncile 10

done





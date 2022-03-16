echo $i

head -n5 $1

indivs_line=`grep -nr "Indivs: Rank Comparison" $1 | cut -d ":" -f 1`
orgs_line=`grep -nr "Orgs: Rank Comparison" $1 | cut -d ":" -f 1`
end=`wc -l $1 | cut -d " " -f 1`

inl=`echo $orgs_line" - 3" | bc`

indivs_new_line=`cat $1 | sed -n $inl'p'`
orgs_new_line=`cat $1 | sed -n $end'p'`

#echo $indivs_new_line

indivs_count=`echo $indivs_new_line | wc -w`
#indivs_last=`echo $indivs_count "- 1" | bc`
#echo $indivs_count


start=`echo $indivs_line" + 4" | bc`
curr=$start

#echo $indivs_line
#echo $curr

echo "indivs change by rank"
for i in `echo $indivs_new_line`
do
[ "X$i" == "X<NA>" ] && continue

#echo $i
#old=`cat $1 | sed -n $curr'p' | tr -s " " | cut -d " " -f $indivs_last`
old_line=`cat $1 | sed -n $curr'p'`
#echo $old_line
old=`echo $old_line | cut -d " " -f $indivs_count`
rank=`echo $old_line | cut -d " " -f 1`
[ "X$rank" == "X<NA>" ] && continue
#echo $old

change=`echo $i" - "$old | bc`
echo $rank $change

((curr++))

done




echo "orgs change by rank"
orgs_count=`echo $orgs_new_line | wc -w`


start=`echo $orgs_line" + 4" | bc`
curr=$start

#echo $orgs_line
#echo $curr

for i in `echo $orgs_new_line`
do
[ "X$i" == "X<NA>" ] && continue

old_line=`cat $1 | sed -n $curr'p'`
old=`echo $old_line | cut -d " " -f $orgs_count`
rank=`echo $old_line | cut -d " " -f 1`
[ "X$rank" == "X<NA>" ] && continue
#echo $old

change=`echo $i" - "$old | bc`
echo $rank $change

((curr++))

done



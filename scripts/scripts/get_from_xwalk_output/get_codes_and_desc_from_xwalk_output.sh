xwalk_output=$1

temp=$RANDOM
#echo $temp
touch $temp"_temp.txt"
cp $xwalk_output $xwalk_output"_"$temp".txt"
sed -i s/"\t"/"~"/g $xwalk_output"_"$temp".txt"

echo -e "CODE_GROUP\tCODE\tTYPE\tSCHEME"

while read i
do

bucket=`echo $i | cut -d "~" -f 1`
type=`echo $i | cut -d "~" -f 2`
source=`echo $i | cut -d "~" -f 4`
source_scheme=`echo $i | cut -d "~" -f 7`
source_desc=`echo $i | cut -d "~" -f 9`
target=`echo $i | cut -d "~" -f 6`
target_scheme=`echo $i | cut -d "~" -f 8`
target_desc=`echo $i | cut -d "~" -f 10`

if [ "$source" != "SOURCE_CODE_NODEC" ] && [ "$source" != "" ];then

grep -q $source"_"$source_scheme $temp"_temp.txt" || echo -e "$bucket\t$source\t$source_desc"
grep -q $target"_"$target_scheme $temp"_temp.txt" || echo -e "$bucket\t$target\t$target_desc"

echo $source"_"$source_scheme >> $temp"_temp.txt"
echo $target"_"$target_scheme >> $temp"_temp.txt"

fi

done < $xwalk_output"_"$temp".txt"

[ -e $temp"_temp.txt" ] && rm $temp"_temp.txt"
[ -e $xwalk_output"_"$temp".txt" ] && rm $xwalk_output"_"$temp".txt"


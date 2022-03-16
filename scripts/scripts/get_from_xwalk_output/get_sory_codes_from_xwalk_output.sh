xwalk_output=$1

temp=$RANDOM
#echo $temp
touch $temp"_temp.txt"

while read i
do

source=`echo $i | cut -d " " -f 4`
source_scheme=`echo $i | cut -d " " -f 7`
target=`echo $i | cut -d " " -f 6`
target_scheme=`echo $i | cut -d " " -f 8`

if [ "$source" != "SOURCE_CODE_NODEC" ] && [ "$source" != "" ];then

grep -q $source"_"$source_scheme $temp"_temp.txt" || echo "$source $source_scheme"
grep -q $target"_"$target_scheme $temp"_temp.txt" || echo "$target $target_scheme"

echo $source"_"$source_scheme >> $temp"_temp.txt"
echo $target"_"$target_scheme >> $temp"_temp.txt"

fi

done < $xwalk_output

[ -e $temp"_temp.txt" ] && rm $temp"_temp.txt"


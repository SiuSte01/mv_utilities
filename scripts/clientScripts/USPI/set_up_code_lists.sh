for i in `ls -d 2016_05*PxDx`
do
echo $i
head -n 1 2015_10_21_ALLSURG_1_PxDx/All_codes_fixed2.txt > $i/code_list.txt
old=`echo $i | sed s@"2016_05_02"@"2015_10_21"@g`
 for j in `ls $old/*/config* | cut -d "/" -f 2`
 do 
 grep $j 2015_10_21_ALLSURG_1_PxDx/All_codes_fixed2.txt >> $i/code_list.txt
 done
done


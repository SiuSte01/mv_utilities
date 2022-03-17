if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2016_codes_from_diag_buckets.txt ];then
for i in `ls /vol/cs/clientprojects/USPI/2016_05_10_PxDx/*/codes/codes.tab | grep -v ALL_SURGERY`
do
 bucket=`echo $i | cut -d "/" -f 7`
 echo $bucket
 wc -l $i
 while read j
  do
  code=`echo $j | cut -d " " -f 1`
  echo -e $code"\t"$bucket>> 2016_codes_from_diag_buckets.txt
 done < $i
done
else
echo "list already made 2016"
fi

if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/missing_from_ALL_SURGERY_2016.txt ];then
count=1
while read line
do
 code=`echo $line | cut -f 1 -d " "`
 grep -qw $code /vol/cs/clientprojects/USPI/2016_05_10_PxDx/ALL_SURGERY/codes/codes.tab || echo $line >> missing_from_ALL_SURGERY_2016.txt
[ `expr $count % 1000` == 0 ] && echo $count
((count++))
done < /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2016_codes_from_diag_buckets.txt
fi

if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/missing_from_ALL_SURGERY_2016.txt ];then
count=1
while read line
do
 code=`echo $line | cut -f 1 -d " "`
 grep -qw $code /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2016_codes_from_diag_buckets.txt || echo $code ALL_SURGERY >> missing_from_others_2016.txt
[ `expr $count % 1000` == 0 ] && echo $count
((count++))
done < /vol/cs/clientprojects/USPI/2016_05_10_PxDx/ALL_SURGERY/codes/codes.tab
fi

#### this analysis revealed 2060 unique codes (28537 total) from other buckets. This means 745 codes are not included in the 25315 codes in the ALL_SURGERY bucket.


if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2015_codes_from_diag_buckets.txt ];then
for i in `ls /vol/cs/clientprojects/USPI/2015_10_31_PxDx/*/codes/codes.tab | grep -v ALL_SURGERY`
do
 bucket=`echo $i | cut -d "/" -f 7`
 echo $bucket
 wc -l $i
 while read j
  do
  code=`echo $j | cut -d " " -f 1`
  echo -e $code"\t"$bucket>> 2015_codes_from_diag_buckets.txt
 done < $i
done
else
echo "list already made 2015"
fi

if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/missing_from_ALL_SURGERY_2015.txt ];then
count=1
while read line
do
 code=`echo $line | cut -f 1 -d " "`
 grep -qw $code /vol/cs/clientprojects/USPI/2015_10_31_PxDx/ALL_SURGERY/codes/codes.tab || echo $line >> missing_from_ALL_SURGERY_2015.txt
[ `expr $count % 1000` == 0 ] && echo $count
((count++))
done < /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2015_codes_from_diag_buckets.txt
fi

if [ ! -e /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/missing_from_other_2015.txt ];then
count=1
while read line
do
 code=`echo $line | cut -f 1 -d " "`
 grep -qw $code /vol/cs/CS_PayerProvider/Ryan/utilities/USPI/2015_codes_from_diag_buckets.txt || echo $code ALL_SURGERY >> missing_from_others_2015.txt
[ `expr $count % 1000` == 0 ] && echo $count
((count++))
done < /vol/cs/clientprojects/USPI/2015_10_31_PxDx/ALL_SURGERY/codes/codes.tab
fi




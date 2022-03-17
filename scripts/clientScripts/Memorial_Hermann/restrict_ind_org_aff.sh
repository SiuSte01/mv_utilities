date="2017_10_24"
allcodedate=Jun2017
#directory=/vol/cs/clientprojects/Memorial_Hermann/2016_12_08_MH_PxDxs
directory=/vol/cs/clientprojects/Memorial_Hermann/2017_10_27_MH_PxDxs
#input=/vol/cs/CS_PayerProvider/Ryan/utilities/MH/2016_Dec_buckets_to_filter.txt
input=/vol/cs/CS_PayerProvider/Ryan/utilities/MH/2017_Apr_buckets_to_filter.txt

for i in `cat $input | cut -d "/" -f 7-9`
do
echo i: $i

bucket=`echo $i | cut -d "/" -f 2`
#echo bucket: $bucket

#INA_path=/vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/$allcodedate/INA_Expanded_AS/INA_Expanded_All_Codes_AS/Comb
INA_path=/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes/Oct2017/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb

piidlist=`ls $directory/$i/piid*`

path=$INA_path/$date"_"$bucket

test=`ls $path/affils_grp1_filtered.tab.bak 2> /dev/null`

[ "X$test" != "X" ] && echo $i already restricted && continue

#echo "testing $piidlist $path $test" ; continue

Rscript /vol/cs/CS_PayerProvider/Ryan/utilities/MH/restrict_ind_org_aff.R $path $piidlist


done




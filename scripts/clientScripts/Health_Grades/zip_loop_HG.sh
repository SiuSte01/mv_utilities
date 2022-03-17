[ $# != 4 ] && printf "This script requires 4 arguments.\n\tdate to append to file names\n\tpath for dx only folders\n\tpath for dx to px folders\n\tpath to output directory\n\nExample: zip_loop_HG.sh '2016_07_29' '/vol/cs/clientprojects/HealthGrades/2016_07_29_INAs/2016_07_29_INA_*/*_Dx_To_Px' '/vol/cs/clientprojects/HealthGrades/2016_07_29_INAs/2016_07_29_INA_*/*_Dx_Only' '/vol/cs/clientprojects/HealthGrades/2016_07_29_INAs_Delivery'\n" && exit 1

date=$1
dx_only_path=$2
dx_to_px_path=$3
outpath=$4

mkdir -p $outpath

for i in $dx_only_path
do
echo $i
base=`basename $i`

zip -j $outpath/$date"_""$base".zip $i/Comb/den1summarycounts.txt $i/Comb/den2summarycounts.txt $i/Comb/denom_fordelivery.txt $i/Comb/linksummarycounts.txt $i/Comb/links_fordelivery.txt

done

for i in $dx_to_px_path
do

echo $i
base=`basename $i`

zip -j $outpath/$date"_""$base".zip $i/Comb/den1summarycounts.txt $i/Comb/denom_fordelivery.txt $i/Comb/linksummarycounts.txt $i/Comb/links_fordelivery.txt

done





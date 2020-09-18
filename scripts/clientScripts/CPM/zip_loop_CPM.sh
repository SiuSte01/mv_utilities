[ $# != 3 ] && printf "This script requires 3 arguments.\n\tdate to append to file names\n\tpath for dx only folders\n\tpath for dx to px folders\n\tpath to output directory\n\nExample: zip_loop_CPM.sh '2016_08_15' '/vol/cs/clientprojects/CPM/2016_08_15_CPM_INA_nonEMD/*' '/vol/cs/clientprojects/CPM/2016_08_15_INAs_Delivery'\n" && exit 1

date=$1
inapath=$2
outpath=$3

mkdir -p $outpath

for i in $inapath
do
echo $i
base=`basename $i`

zip -j $outpath/$date"_""$base".zip $i/Comb/den1summarycounts.txt $i/Comb/denom_fordelivery.txt $i/Comb/linksummarycounts.txt $i/Comb/links_fordelivery.txt

done




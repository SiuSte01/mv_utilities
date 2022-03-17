for i in `ls /vol/cs/clientprojects/Memorial_Hermann/2016_12_16_Delivery/2016_12_16_Flat_Files_work/*/affils*tab`
do

path=`dirname $i`
bucket=`echo $path | cut -d "/" -f 8`
echo path: $path
echo bucket: $bucket

cp $path/affils_*_fordelivery.tab $path/HMS_PxDx_"$bucket".tab
cp $path/indivs_*_fordelivery.tab $path/HMS_Individuals_"$bucket".tab
cp $path/orgs_*_fordelivery.tab $path/HMS_Organizations_"$bucket".tab
cp $path/network*txt $path/HMS_Network_"$bucket".tab

printf "***********\n\n"



done



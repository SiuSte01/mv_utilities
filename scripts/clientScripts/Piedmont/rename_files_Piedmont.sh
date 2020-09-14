for i in `ls /vol/cs/clientprojects/Piedmont_Healthcare/2019_01_02_GenSurg_BrCancer_Thoracic_Cardio_Valve_Vein_Neuro_Heart_Refresh/Work/*/*.tab`
do

path=`dirname $i`
bucket=`echo $path | cut -d "/" -f 8`
echo path: $path
echo bucket: $bucket

cp $path/affils_grp2_fordelivery.tab $path/HMS_PxDx.tab
cp $path/affils_grp1_fordelivery.tab $path/HMS_PxDx.tab
cp $path/indivs_grp2_fordelivery.tab $path/HMS_Individuals.tab
cp $path/indivs_grp1_fordelivery.tab $path/HMS_Individuals.tab
cp $path/orgs_grp2_fordelivery.tab $path/HMS_Organizations.tab
cp $path/orgs_grp1_fordelivery.tab $path/HMS_Organizations.tab
cp $path/network_full.txt $path/HMS_Network.tab

printf "***********\n\n"



done



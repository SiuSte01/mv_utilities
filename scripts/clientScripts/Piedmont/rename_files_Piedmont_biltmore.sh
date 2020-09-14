for i in `ls /vol/cs/clientprojects/Piedmont_Healthcare/2018_03_05_GenSurg_BrCancer_Thoracic_Cardio_Valve_Vein_Neuro_Heart/Biltmore_Work/selectFileOut_Bilt/*/*.tab`
do

path=`dirname $i`
bucket=`echo $path | cut -d "/" -f 8`
echo path: $path
echo bucket: $bucket

cp $path/HMS_PxDx.tab $path/affils_grp2_filtered.tab
cp $path/HMS_Individuals.tab $path/indivs_grp2_filtered.tab
cp $path/HMS_Organizations.tab $path/orgs_grp2_filtered.tab
cp $path/HMS_Network.tab $path/network_indiv_profiles.txt

printf "***********\n\n"



done



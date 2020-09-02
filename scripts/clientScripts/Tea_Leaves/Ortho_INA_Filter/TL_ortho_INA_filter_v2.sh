date=$1
inadate=$date
temp="$RANDOM"
dir=`pwd`

cd /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter

[[ $HOSTNAME != *"sas"* ]] && [[ $HOSTNAME != *"plr"* ]] && echo "This script must be run from plsas01 or plr01" && exit 1

#for joint in `echo "Hip"`
#for joint in `echo "Hand_Wrist"`
for joint in `echo "Hip Knee Hand_Wrist Shoulder_Elbow Foot_Ankle"`
do
 echo $joint

 #########################
 ###test if already run###
 #########################

 exists_test=`ls /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/network.txt 2> /dev/null`
 [ "X$exists_test" != "X" ] && continue

 ########
 ###dx###
 ########

 #find indivs files, op and ip
 opdx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_Dx_PxDx_ignore/Ortho_"$joint"_dx_op_office_asc/milestones/individuals.tab`
 ipdx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_Dx_PxDx_ignore/Ortho_"$joint"_dx_ip/milestones/individuals.tab`

 echo $opdx,$ipdx

 [ "X$opdx" == "X" ] || [ "X$ipdx" == "X" ] && echo "dx indivs file missing" && continue

 ###combine to 1 file
 cat $opdx $ipdx | cut -f 1-18 | sort -u > $temp"_"$joint"_"dx.tab

 ###make piidselectioninputs.txt
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/piidselectioninputs_template.txt idselectioninputs.txt
 sed -i s/"REPLACE_INDIVS"/"$temp"_"$joint"_"dx.tab"/g idselectioninputs.txt
 sed -i s@"REPLACE_SPECIALTIES"@"/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/dx_PCP_specialties.txt"@g idselectioninputs.txt

 ###run makepiidlist.R
 Rscript /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/makeidlist.R
 mv idlist.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_idlist.txt
 mv idselectioninputs.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_idselectioninputs.txt
 #rm -f piidselectioninputs.txt

 ########
 ###px###
 ########

 #find indivs files, op and ip
 oppx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_px_op_office_asc/milestones/individuals.tab`
 ippx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_px_ip/milestones/individuals.tab`

 echo $oppx,$ippx

 [ "X$oppx" == "X" ] || [ "X$ippx" == "X" ] && echo "px indivs file missing" && continue

 ###combine to 1 file
 cat $oppx $ippx | cut -f 1-18 | sort -u > $temp"_"$joint"_"px.tab

 ###make piidselectioninputs.txt
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/piidselectioninputs_template.txt idselectioninputs.txt
 sed -i s/"REPLACE_INDIVS"/"$temp"_"$joint"_"px.tab"/g idselectioninputs.txt
 sed -i s@"REPLACE_SPECIALTIES"@"/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/px_Ortho_specialties.txt"@g idselectioninputs.txt

 ###run makepiidlist.R
 Rscript /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/makeidlist.R
 mv idlist.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_idlist.txt
 mv idselectioninputs.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_idselectioninputs.txt
 #rm -f piidselectioninputs.txt

 ################
 ###run filter###
 ################
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/filter_inputs_template.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt

 #replace strings w/ piidlist path
 sed -i s@REPLACE_LIST1@/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_idlist.txt@g /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt
 sed -i s@REPLACE_LIST2@/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_idlist.txt@g /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt

 #create filter folder, move filter input
 filt_test=`ls -d /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter`
 [ "X$filt_test" == "X" ] && mkdir /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter
 mv /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/
 echo /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/ 

 cd /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/
 perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl "$joint"_filter.txt >| stderrout_filter 2>&1 & test=`echo $test "/proc/"$!`
 cd /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter

done

echo "running filters"

complete_test=`ls -d $test 2> /dev/null`

while [ "X$complete_test" != "X"  ]
do
 #echo "still running"
 #ls -d $test 2> /dev/null
 sleep 300
 complete_test=`ls -d $test 2> /dev/null`
done

echo "all complete"

[ "X$temp" != "$temp" ] && rm -f $temp*

cd $dir

###check that all new directories have output###
printf "\n\nChecking that all directories have network files.\n\n"

missing_string=""
#for i in `ls -d $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon/*INA/*/Comb | grep -v "Ortho_Joint_INA"`
#for i in `ls -d $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon/*INA/*/Comb` #this script does not run ortho INA, so should not check for it
for joint in `echo "Hip Knee Hand_Wrist Shoulder_Elbow Foot_Ankle"`
do
 i=/vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb
 echo $i
 if [ ! -e $i/Filter/network.txt ]
 then

  missing_string=`echo "$missing_string"$i/Filter/network.txt'\n'`

 fi

done


#echo "$missing_string"

if [ "X$missing_string" != "X" ];then

 printf "The following networks are missing:\n"$missing_string | mail "$USER@healthmarketscience.com" -s "Ortho_Joint Network Filter Status"
else
 printf "All network files present.\n" | mail "$USER@healthmarketscience.com" -s "Ortho_Joint Network Filter Status"
fi




date=$1
inadate=$date
temp="$RANDOM"
dir=`pwd`

[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1

#for joint in `echo "Hip"`
#for joint in `echo "Hand_Wrist"`
for joint in `echo "Hip Knee Hand_Wrist Shoulder_Elbow"`
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
 opdx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_dx_op_office_asc/milestones/individuals.tab`
 ipdx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_dx_ip/milestones/individuals.tab`

 echo $opdx,$ipdx

 ###combine to 1 file
 cat $opdx $ipdx | cut -f 1-18 | sort -u > $temp"_"$joint"_"dx.tab

 ###make piidselectioninputs.txt
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/piidselectioninputs_template.txt piidselectioninputs.txt
 sed -i s/"REPLACE_INDIVS"/"$temp"_"$joint"_"dx.tab"/g piidselectioninputs.txt
 sed -i s@"REPLACE_SPECIALTIES"@"/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/dx_PCP_specialties.txt"@g piidselectioninputs.txt

 ###run makepiidlist.R
 Rscript /vol/homes/drajagopalan/Network/DiagFocus/ABCode/makepiidlist.R
 mv piidlist.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_piidlist.txt
 mv piidselectioninputs.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_piidselectioninputs.txt
 #rm -f piidselectioninputs.txt

 ########
 ###px###
 ########

 #find indivs files, op and ip
 oppx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_px_op_office_asc/milestones/individuals.tab`
 ippx=`ls /vol/cs/clientprojects/Tea_Leaves/"$date"_PxDx_and_INA/"$date"_PxDx_Emdeon/Ortho_GI_PxDx/Ortho_"$joint"_px_ip/milestones/individuals.tab`

 echo $oppx,$ippx

 ###combine to 1 file
 cat $oppx $ippx | cut -f 1-18 | sort -u > $temp"_"$joint"_"px.tab

 ###make piidselectioninputs.txt
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/piidselectioninputs_template.txt piidselectioninputs.txt
 sed -i s/"REPLACE_INDIVS"/"$temp"_"$joint"_"px.tab"/g piidselectioninputs.txt
 sed -i s@"REPLACE_SPECIALTIES"@"/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/px_Ortho_specialties.txt"@g piidselectioninputs.txt

 ###run makepiidlist.R
 Rscript /vol/homes/drajagopalan/Network/DiagFocus/ABCode/makepiidlist.R
 mv piidlist.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_piidlist.txt
 mv piidselectioninputs.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_piidselectioninputs.txt
 #rm -f piidselectioninputs.txt

 ################
 ###run filter###
 ################
 cp /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/filter_inputs_template.txt /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt

 #replace strings w/ piidlist path
 sed -i s@REPLACE_LIST1@/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"dx_piidlist.txt@g /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt
 sed -i s@REPLACE_LIST2@/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$temp"_"$joint"_"px_piidlist.txt@g /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt

 #create filter folder, move filter input
 filt_test=`ls -d /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter`
 [ "X$filt_test" == "X" ] && mkdir /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter
 mv /vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/$joint"_"filter.txt /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/
 echo /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/ 

 cd /vol/cs/clientprojects/Tea_Leaves/"$inadate"_PxDx_and_INA/"$inadate"_INA_Emdeon/Ortho_Joint_INA/Ortho_"$joint"/Comb/Filter/
 perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl "$joint"_filter.txt >| stderrout_filter 2>&1 & test=`echo $test "/proc/"$!`
 cd $dir

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

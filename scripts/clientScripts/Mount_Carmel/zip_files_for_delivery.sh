###this will collect the 13 directories for which there exist INAs

for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016_*INA/*/Comb/Filter`

#for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016_05_18_Breast*INA/*/Comb/Filter`

do
 echo "*****running for $i"
 pxdx_dir=`echo $i | cut -d "/" -f 1-6 | sed s@"_INA"@""@g`
 [ ! -e $pxdx_dir ] && echo "$pxdx_dir not found" && continue

 name=`basename $pxdx_dir`

 [ -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && echo "already zipped" && continue

 [ -e $i/affils_grp2_fordelivery.tab ] && ziplist=`ls $i/*grp2*fordelivery* $i/network.txt` || ziplist=`ls $i/*grp1*fordelivery* $i/network.txt`

 zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" $ziplist

done

name="2016_05_19_Mammography_Px"
[ ! -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" /vol/cs/clientprojects/Mount_Carmel/2016_05_19_Mammography_Px/Mammography/milestones/pxdx_sample_specfiltered.tab /vol/cs/clientprojects/Mount_Carmel/2016_05_19_Mammography_Px/Mammography/milestones/individuals_sample_specfiltered.tab /vol/cs/clientprojects/Mount_Carmel/2016_05_19_Mammography_Px/Mammography/milestones/organizations_sample.tab

name="2016_06_08_Mount_Carmel_AllCodes_AllSettings"
[ ! -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && ziplist=`ls /vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/Jun2016/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb/2016_06_08_Mount_Carmel_AllCodes_AllSettings/*fordelivery*  /vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/Jun2016/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb/2016_06_08_Mount_Carmel_AllCodes_AllSettings/network.txt` && zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" $ziplist

name="2016_06_08_Mount_Carmel_AllCodes_IPOnly"
[ ! -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && ziplist=`ls /vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/Jun2016/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb/$name/*fordelivery*` && zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" $ziplist

name="2016_06_08_Mount_Carmel_AllCodes_OPOfficeASC"
[ ! -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && ziplist=`ls /vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/Jun2016/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb/$name/*fordelivery*` && zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" $ziplist

name="2016_06_08_PayerMix"
[ ! -e /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" ] && zip -j /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/$name".zip" /vol/cs/clientprojects/Mount_Carmel/2016_06_08_PayerMix/payermix.txt

for i in /vol/cs/clientprojects/Mount_Carmel/Delivery/2016_06_08_Mount_Carmel_Delivery/*
do
 name=`basename $i`
 for j in `unzip -l $i| grep \\.t | grep -v Name | tr -s " " | sed s/"^ "/""/g | cut -d " " -f 4`
 do
  echo $name $j
  echo $j | grep -q network && printf "@ $j\n@=HMS_Network.tab\n" | zipnote -w $i
  echo $j | grep -q affils && printf "@ $j\n@=HMS_PxDx.tab\n" | zipnote -w $i
  echo $j | grep -q indiv && printf "@ $j\n@=HMS_Individuals.tab\n" | zipnote -w $i
  echo $j | grep -q org && printf "@ $j\n@=HMS_Organizations.tab\n" | zipnote -w $i
  echo $j | grep -q pxdx && printf "@ $j\n@=HMS_PxDx.tab\n" | zipnote -w $i


 done
done










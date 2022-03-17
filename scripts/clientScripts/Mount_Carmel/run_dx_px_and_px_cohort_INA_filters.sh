#Below is the list of INAs which use the geography filtered allcodes to define the group and universe of group1

#2016_05_18_Breast_Px_INA
#2016_05_18_Cardiac_Px_INA
#2016_05_18_Gen_Surg_Px_INA
#2016_05_18_GYN_Px_INA
#2016_05_18_Neurosurgery_Px_INA
#2016_05_18_OB_Px_INA
#2016_05_18_Ortho_Joints_Only_Px_INA
#2016_05_18_Ortho_No_Joints_Px_INA
#2016_05_18_Pain_Px_INA
#2016_05_18_Spine_Px_INA
#2016_05_19_CTMRI_Px_INA

[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1

dir=`pwd`

for i in `echo 2016_05_18_Breast_Px_INA 2016_05_18_Cardiac_Px_INA 2016_05_18_Gen_Surg_Px_INA 2016_05_18_GYN_Px_INA 2016_05_18_Neurosurgery_Px_INA 2016_05_18_OB_Px_INA 2016_05_18_Ortho_Joints_Only_Px_INA 2016_05_18_Ortho_No_Joints_Px_INA 2016_05_18_Pain_Px_INA 2016_05_18_Spine_Px_INA 2016_05_19_CTMRI_Px_INA`
#for i in `echo 2016_05_18_Breast_Px_INA` #for testing
do
echo "***** $i"
if [ -e /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/filter_inputs_NEW.txt ] || [ -e /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/filter_inputs_dx2px_pxcohort.txt ];then
 echo "$i already filtered"
 continue
fi

volumetrics=`echo $i | sed s/"_INA"/""/g`
fieldname=$(for j in `head -n 1 /vol/cs/clientprojects/Mount_Carmel/$volumetrics/*/QA/pxdx.tab`;do echo $j | grep PRACTITIONER_NATL_RANK | sed s/"_PRACTITIONER_NATL_RANK"/""/g;done)
pxdx_dir=`echo $i | sed s/"_INA"/""/g`

[ `echo $fieldname | wc -w` != 1 ] && echo "error: more than one result found for fieldname" && continue

cp /vol/cs/CS_PayerProvider/Ryan/utilities/Mount_Carmel/filter_inputs_dx2px_pxcohort.txt /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/

sed -i s@replace_fieldname@$fieldname@g /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/filter_inputs_dx2px_pxcohort.txt 
sed -i s@replace_dirname@$pxdx_dir@g /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/filter_inputs_dx2px_pxcohort.txt

cd /vol/cs/clientprojects/Mount_Carmel/$i/*/Comb/Filter/

nohup perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl filter_inputs_dx2px_pxcohort.txt   >|   stderrout_filter_rerun 2>&1 &

sleep 10

done


cd $dir



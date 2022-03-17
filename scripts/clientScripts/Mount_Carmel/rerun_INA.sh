[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1
for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016*INA`
do
 echo $i
 cd $i/config
 pwd

 old_slash="02/10/2016"
 new_slash="05/11/2016"

 old_comb="20160210"
 new_comb="20160511"

#rhopson@plsas01:Mount_Carmel(0)grep "0210" 2016_05_18_Breast_Px_INA/*/*
#2016_05_18_Breast_Px_INA/Breast_Px_Cohort/inputs:Vintage        20160210
#rhopson@plsas01:Mount_Carmel(0)grep "02/" 2016_05_18_Breast_Px_INA/*/*
#2016_05_18_Breast_Px_INA/config/settings.cfg:VINTAGE = 02/10/2016


 #sed -i s@"$old_slash"@"$new_slash"@g $i/config/settings.cfg
 #sed -i s@"$old_comb"@"$new_comb"@g $i/*/inputs

 nohup perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg >| stderrout2 2>&1 &

 sleep 10

done

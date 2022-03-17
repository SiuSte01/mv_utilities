#[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1
for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016*x | grep -v Payer`
do
 at=`grep ANALYSIS_TYPE $i/settings.cfg`
 echo $i $at

 sed -i s@"$at"@"ANALYSIS_TYPE = Makefile"@g $i/settings.cfg
 
 cd $i/config
 pwd

 old_slash="02/10/2016"
 new_slash="05/11/2016"

 old_comb="20160210"
 new_comb="20160511"

 #sed -i s@"$old_slash"@"$new_slash"@g $i/*.*
 #sed -i s@"$old_slash"@"$new_slash"@g $i/*/*.*

 #sed -i s@"$old_comb"@"$new_comb"@g $i/*.*
 #sed -i s@"$old_comb"@"$new_comb"@g $i/*/*.*

[ -e $i/config/stderrout_makefile_rerun2 ] && echo $i already running && continue

 nohup perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg -multiBucket >| stderrout_makefile_rerun2 2>&1 &

 sleep 5

done




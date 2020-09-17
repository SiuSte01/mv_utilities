###This script runs the monthly refreshes of CPM INAs, both Emd and Non.
#CANNOT be run until Allaire has announced the monthly vintage.

##MUST be run from sas box WRONG. part shell part sas
#[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 2

###update these
Previous=2016_04_15
Current=2016_05_15
vintage=20160413
log=/vol/cs/CS_PayerProvider/Ryan/utilities/CPM/"$vintage"_ina.log

#remove old log if existing
[ -e $log ] && rm -f $log
logrun() {
  echo $@ >> $log
  eval $@
}

###non updating variables
emd=_CPM_INA_EMD
non=_CPM_INA_nonEMD
CPM_dir=/vol/cs/clientprojects/CPM

###make new dirs
emd_dir=`echo "$CPM_dir"/"$Current""$emd"/"$Current""$emd"_Cloning/`
non_dir=`echo "$CPM_dir"/"$Current""$non"/"$Current""$non"_Cloning/`

logrun mkdir -p $emd_dir
logrun mkdir -p $non_dir

###copy cloning dirs
if [ ! -e $emd_dir/configs ] && [ ! -e $CPM_dir/config_archive/$Current"_EMD_config" ];then
 echo "copying"
 logrun cp -r "$CPM_dir"/"$Previous""$emd"/"$Previous""$emd"_Cloning/configs $emd_dir
 logrun cp -r "$CPM_dir"/"$Previous""$non"/"$Previous""$non"_Cloning/configs $non_dir
fi

###set up settings files (emd)
if [ ! -e $emd_dir/inaProjects/"$Current"_CPMINA_EMD/config/settings.cfg ];then
 pushd $emd_dir
 logrun "perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/ina/copyInaJob.pl -configDir configs -vintage $vintage -prefix "$Current"_CPMINA"
 popd
 cp -r $emd_dir/inaProjects/"$Current"_CPMINA_EMD/config "$CPM_dir"/"$Current""$emd"/
 grep "VINTAGE"	"$CPM_dir"/"$Current""$emd"/config/settings.cfg
 grep "JOB_QUEUE" "$CPM_dir"/"$Current""$emd"/config/settings.cfg
fi

###set up settings files (non)
if [ ! -e $non_dir/inaProjects/"$Current"_CPMINA/config/settings.cfg ];then
 pushd $non_dir
 logrun "perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/ina/copyInaJob.pl -configDir configs -vintage $vintage -prefix "$Current"_CPMINA"
 popd
 cp -r $non_dir/inaProjects/"$Current"_CPMINA/config "$CPM_dir"/"$Current""$non"/
 grep "VINTAGE" "$CPM_dir"/"$Current""$non"/config/settings.cfg
 grep "JOB_QUEUE" "$CPM_dir"/"$Current""$non"/config/settings.cfg
fi

#step5
#cd to config
#log onto ***PLSAS***
#maybe can do this with ssh??
#run nohup perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg >| stderrout_ina 2>&1 &
#watch for it to finish

###step 6 - Compare sizes
#cp comparesizes.pl from previous run for both EMD and non, replace olddir
#run using nohup perl comparesizes.pl >| stderroutcompare 2>&1 &

###step 7 - run compare line counts
#this probably replaces step 6 - need to discuss
#run this for EMD and non
#Rscript --vanilla line_count_QA_v1.R /vol/cs/clientprojects/CPM/2016_05_15_CPM_INA_nonEMD/ /vol/cs/clientprojects/CPM/2016_04_15_CPM_INA_nonEMD/ /vol/cs/clientprojects/CPM/2016_05_15_CPM_QA/INA_nonEMD_linecount_QA.csv Apr_May /vol/cs/clientprojects/CPM/2016_05_15_CPM_QA/INA_linecounts_input.txt 5

#step 8
#archive config folders so they don't interfere with subsequent processes
if [ -e "$CPM_dir"/"$Current""$emd"/config ];then
 mv "$CPM_dir"/"$Current""$emd"/config $CPM_dir/config_archive/$Current"_EMD_config"
 mv "$CPM_dir"/"$Current""$non"/config $CPM_dir/config_archive/$Current"_nonEMD_config"
fi

#step 9 - zip up for deliverables
delivery_dir=$CPM_dir/$Current"_CPM_Delivery"
ina_non="$CPM_dir"/"$Current""$non"
logrun mkdir -p $delivery_dir
if [ ! -e $delivery_dir/2016_04_15_INA_Dermatology.zip ];then
 for i in `ls -d $ina_non/*/Comb`;do
  service=`echo $i | cut -d "/" -f 7`
  echo "zipping $service"
  logrun zip -j $delivery_dir/$Current"_INA_"$service".zip" $i/den1summarycounts.txt $i/denom_fordelivery.txt $i/links_fordelivery.txt $i/linksummarycounts.txt
 done
fi








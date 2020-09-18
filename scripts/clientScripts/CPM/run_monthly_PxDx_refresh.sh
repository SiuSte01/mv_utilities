###DO NOT RUN THIS until Sankar and Joe have updated their databases. See email on how to request.
###nonEmdeon must run first, then Emdeon

##MUST be run from sas box
[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 2


###update these
Previous=2016_04_15
Current=2016_05_15
vintage=20160413
log=/vol/cs/CS_PayerProvider/Ryan/utilities/CPM/"$vintage"_pxdx.log

#remove old log if existing
[ -e $log ] && rm -f $log
logrun() {
  echo $@ >> $log
  eval "$@"
}

###non updating variables
emd=_PxDx_Enhanced
non=_PxDx
CPM_dir=/vol/cs/clientprojects/CPM
past_vintage=`grep "specified vintage" $CPM_dir/$Previous"_PxDx/stderrout" | head -n 1 | cut -d " " -f 4`
[ "X$past_vintage" == "X" ] && echo "Previous vintage not found" && exit 2

###Step 2 - setup
pushd /vol/datadev/Statistics/Projects/CPM/InputDataFiles_NewWH/Work
if [ ! -e /vol/datadev/Statistics/Projects/CPM/InputDataFiles_NewWH/phys_matrix_$vintage* ];then
 old_vint=`grep "Vintage" /vol/datadev/Statistics/Projects/CPM/InputDataFiles_NewWH/Work/input.txt` 
 logrun sed -i s@"'$old_vint'"@"'Vintage\t$vintage'"@g /vol/datadev/Statistics/Projects/CPM/InputDataFiles_NewWH/Work/input.txt
 logrun nohup perl setup.pl $vintage >| stderrout_pxdx 2>&1
else
 echo "setup.pl already run"
 echo "setup.pl already run" >> $log
fi

###Step 3 - error checking
err1=`egrep   -i    'error|exit'    stderrout_pxdx`
err2=`find . -name "*log" -exec grep ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further'`
err3=`find . -name "*log" -exec grep -H ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further' | cut -d\: -f1 | sort -u`

if [ "X$err1" != "X" ] || [ "X$err2" != "X" ] || [ "X$err3" != "X" ];then
 echo "error in setup detected: check log $log"
 echo "error in setup detected" >> $log
 echo "err1: $err1" >> $log
 echo "err2: $err2" >> $log
 echo "err3: $err3" >> $log
 exit 2
fi


###Step 4 - QA
cd ../
for i in `echo "active_npiupin active_piid ascaffils ip_datamatrix migration_lookup officeaffils op_datamatrix phys_matrix poid_volume"`
do
 new_fsize=`ls -l $i*$vintage".sas7bdat" | cut -d " " -f 5`
 old_fsize=`ls -l $i*$past_vintage".sas7bdat" | cut -d " " -f 5`
 echo -e "$i\t$new_fsize\t$old_fsize"
 echo -e "$i\t$new_fsize\t$old_fsize" >> $log
done

###Step 5 - setting up to kick off
if [ ! -e $CPM_dir/$Current""$non/SNF/buckets.txt ];then
 for i in `echo "IP OP OfficeASC SNF"`;do
  logrun mkdir -p $CPM_dir/$Current""$non/$i
  logrun cp $CPM_dir/$Previous""$non/$i/buckets.txt $CPM_dir/$Current""$non/$i/
 done
else
 echo "bucket files already copied"
 echo "bucket files already copied" >> $log
fi

###step 6 - kick off projections
###NEEDS CHECKED###
logrun cd $CPM_dir/$Current""$non
if [ ! -e $CPM_dir/$Current""$non/OfficeASC/pxdxresultnostar.txt ];then
 logrun "nohup csh /vol/datadev/Statistics/Projects/CPM/Prod_NewWH/run4.csh $vintage >| stderrout 2>&1" 
else
 echo "projections already run"
 echo "projections already run" >> $log
fi

###step 7 - Error check process
pwd
error_test=`find . -name "*log*" -exec grep -H ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further' | cut -d\: -f1 | sort -u | grep -Ev "OP/log_CoronaryInterventionalProcedures|OP/log_Thoracic|OP/log_HeadandNeckSurgery|OP/log_Tracheostomy|OP/log_Transplant"`
if [ "X$error_test" != "X" ];then
 echo "Error detected in projection: $error_test"
 echo "Error detected in projection: $error_test" >> $log
 exit 2
fi

###step 8 - run QC
###these are old QC scripts written by Dilip. Can be updated.
if [ ! -e $CPM_dir/$Current$non/SNF/poidvolcomp.pdf ];then
 echo "../../$Previous$non" > $CPM_dir/$Current$non/prev.txt
 logrun nohup csh /vol/datadev/Statistics/Projects/CPM/Prod_NewWH/run4comps.csh >|  stderrout_qc 2>&1
else
 echo "QA already run"
 echo "QA already run" >> $log
fi

###step 8.5 - check for migrations, then for outliers

###step 9 - update views for emdeon (email sankar)
#turn back on for next run
#echo -e "Hi Sankar-\nCan you update the CPM aggregation views to point to the Emdeon versions?\nThanks" | mail "Ryan.Hopson@lexisnexis.com Sankar.Ramalingam@risk.lexisnexis.com" -s "CPM PxDx" -- -f "Ryan.Hopson@lexisnexis.com"

if [ ! -e $CPM_dir/$Current""$emd/SNF/buckets.txt ];then
 logrun mkdir -p $CPM_dir/$Current""$emd"_waiting"
 ###wait for update
 while [ -e $CPM_dir/$Current""$emd"_waiting" ]; do sleep 60; done
fi

###step 10 - setting up emd to kick off
if [ ! -e $CPM_dir/$Current""$emd/SNF/buckets.txt ];then
 for i in `echo "IP OP OfficeASC SNF"`;do
  logrun mkdir -p $CPM_dir/$Current""$emd/$i
  logrun cp $CPM_dir/$Previous""$emd/$i/buckets.txt $CPM_dir/$Current""$emd/$i/
 done
else
 echo "bucket files already copied"
 echo "bucket files already copied" >> $log
fi

###step 11 - kick off projections
###NEEDS CHECKED###
logrun cd $CPM_dir/$Current""$emd
if [ ! -e $CPM_dir/$Current""$emd/OfficeASC/pxdxresultnostar.txt ];then
 logrun "nohup csh /vol/datadev/Statistics/Projects/CPM/Prod_NewWH/run4.csh $vintage >| stderrout 2>&1"
else
 echo "projections already run"
 echo "projections already run" >> $log
fi

###step 12 - Error check process
pwd
error_test=`find . -name "*log*" -exec grep -H ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further' | cut -d\: -f1 | sort -u | grep -Ev "OP/log_CoronaryInterventionalProcedures|OP/log_Thoracic|OP/log_HeadandNeckSurgery|OP/log_Tracheostomy|OP/log_Transplant"`
if [ "X$error_test" != "X" ];then
 echo "Error detected in projection: $error_test"
 echo "Error detected in projection: $error_test" >> $log
 exit 2
fi

###step 13 - run QC
###these are old QC scripts written by Dilip. Can be updated.
if [ ! -e $CPM_dir/$Current$emd/SNF/poidvolcomp.pdf ];then
 echo "../../$Previous$emd" > $CPM_dir/$Current$emd/prev.txt
 logrun nohup csh /vol/datadev/Statistics/Projects/CPM/Prod_NewWH/run4comps.csh >|  stderrout_qc 2>&1
else
 echo "EMD QA already run"
 echo "EMD QA already run" >> $log
fi












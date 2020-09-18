###This script runs the monthly refreshes of Payermix
#CANNOT be run until Justin Smith gives the goahead 

##MUST be run from sas box
[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 2

###update these
Previous=2016_04_15
Current=2016_05_15
vintage=20160413
log=/vol/cs/CS_PayerProvider/Ryan/utilities/CPM/"$vintage"_payermix.log

#remove old log if existing
[ -e $log ] && rm -f $log
logrun() {
  echo $@ >> $log
  eval $@
}

###non updating variables
CPM_dir=/vol/cs/clientprojects/CPM

if [ ! -e $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/inputs.txt ];then
 logrun mkdir -p $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage
 logrun cp $CPM_dir/$Previous"_CPM_PayerMix_Vintage"*/inputs.txt $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/
 old_vin=`grep -i vintage $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/inputs.txt`
 logrun sed -i s@"$old_vin"@"Vintage\t$vintage"@g $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/inputs.txt
 echo "input file is: $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/inputs.txt"
fi

if [ ! -e $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/payermix.txt ];then
 dir=`pwd`
 echo "Running payermix"
 logrun cd $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage
 logrun R CMD BATCH --vanilla /vol/datadev/Statistics/Projects/PayerMix/pulldata.R 
 logrun cd $dir
fi

#run QA
if [ ! -e $CPM_dir/$Current"_CPM_QA"/payermix_QA.txt ];then
 echo "Running QA"
 logrun Rscript --vanilla /vol/cs/CS_PayerProvider/Ryan/R/line_count_QA_v1.R $CPM_dir/$Previous"_CPM_PayerMix_Vintage"* $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage $CPM_dir/$Current"_CPM_QA"/payermix_QA.txt $Previous"_"$Current $CPM_dir/$Current"_CPM_QA"/payermix_QA_inputs.txt 5
 ch=`head -n 1 $CPM_dir/$Current"_CPM_PayerMix_Vintage"$vintage/payermix.txt`
 ph=`head -n 1 $CPM_dir/$Previous"_CPM_PayerMix_Vintage"*/payermix.txt`
 if [ "$ch" == "$ph" ];then
  echo "headers are the same"
 else
  echo -e "error, headers do not match:\n$ph\n$ch\n"
  echo -e "error, headers do not match:\n$ph\n$ch\n" >> $log
 fi
fi





#[ $HOSTNAME != "plsas01.hmsonline.com" ] && [ $HOSTNAME != "bctlpsas01.risk.regn.net" ] && echo "This script must be run from plsas01" && exit 1

#[[ $HOSTNAME != *"sas"* ]] && echo "This script must be run from a sas box" && exit 1

test=$(basename $(pwd))
[ "$test" != "config" ] && echo "This script must be run from a config directory." && exit 2

[ $# == 0 ] && errorlog="stderrout_aggrproj"
[ $# == 1 ] && errorlog=$1 && [ ! -e $1 ] && echo "specified errorlog does not exist" && exit 3
[ $# -gt 1 ] && echo "This script takes at most one argument, the name of the error log. If not provided, it defaults to 'stderrout_aggrproj'." && exit 4

echo "***looking for errors in $errorlog"
egrep -i 'error|exit|quota|Problem' $errorlog

echo "***logs found:"
cd ../
find . -name "*log" | wc -l

echo "***counting migration lookups in logs"
find . -name "*log" -exec egrep 'MIGRATION_LOOKUP_201' {} \; | sort -u

echo "***checking for asc codes converted from text"
find . -name new_asc_projections.log -exec grep -l "VAR1 best32" {} \;

echo "***checking for errors in pxdx.log and createxwalks.log"
grep '|ERROR|' *.log | grep -v 'Exception while trying to verify job load'

echo "***counting errors in logs"
find . -name "*log" -exec grep ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further|licensed|PLSAS01|processor|Exception while trying to verify job load|ERROR_CHOOSE|SASUSER.PARMS.PARMS.SLIST' | wc -l

echo "***identifying logs with errors"
for i in `find . -name "*log" -exec grep -H ERROR {} \; | egrep -v '_ERROR_|_EFIERR_|899|Silent|functional|Further|licensed|PLSAS01|processor|Exception while trying to verify job load|ERROR_CHOOSE|SASUSER.PARMS.PARMS.SLIST' | cut  -d\: -f1 | sort -u`
do
ls -l $i
done


printf "\n***checking that projections exist in all settings for all buckets\n"
#for cloned jobs, "codeGroupFileTypeDescriptions.tab" may not work.
#for i in `cat codeGroupFileTypeDescriptions.tab | cut -f 1 | sort -u | grep -v CODE_GROUP`
searched=""
#for i in `cat config/codeGroupMembers.tab | cut -f 1 | sort -u | grep -v CODE_GROUP` #code groups don't always share a name with buckets
#for i in `cat config/codeGroupRules.tab | cut -f 1 | sort -u | grep -v BUCKET_NAME`
while read line
do
 i=`echo $line | cut -f1 -d " "`
 #echo $i
 [ "X$i" == "XBUCKET_NAME" ] && continue
 [ "X$i" == "X" ] && continue
 missing_proj_error=0
 #bucket_name=`grep -w $i config/codeGroupRules.tab | cut -f 1` #this step is redundant now that it loops through codeGroupRules, but I'm changing as little as possible in case we need to revert
 bucket_name=$i
 code_names=`echo $line | cut -f3 -d " "`
 code_names=`grep -w $i config/codeGroupRules.tab | cut -f 3` #added rdh - for projects where bucket name is different from what is seen in codeGroupMembers.tab, such as when claims and patients are counted
 #echo $bucket_name,$code_names
 [ "X$bucket_name" == "X" ] && echo "bucket not found in codeGroupRules: " $i && continue
 echo $searched | grep -q $bucket_name && continue
 exists=`find $bucket_name/Projections/ -name "*projectio*.txt" | cut -d "/" -f 3-`
 searched=`echo $searched,$bucket_name`
 #echo $exists
 list=`cat config/jobVendorSettings.tab | grep $bucket_name | set s/","/" "/g | cut -f2`
 echo $list | grep -q "op\|ip" && list=`echo $list "hospital"` #add hospital if ip or op
 for j in `echo $list`
  do
  #echo $j
  #echo "*******************new setting***************"
  #echo $i,$bucket_name,$j
  [ $j == "hha" ] || [ $j == "snf" ] || [ $j == "hospice" ] && j="pac"
  #echo $i,$j
  if echo $exists | grep -iq $j;then
   line_count=""
   [ $j == "hospital" ] && search_string="Hospital/hospital_projections.txt" || search_string="$j.*projectio.*txt"
   projection_file=`for file_name in $exists;do echo $file_name | grep -i "$search_string" | grep -v "nostar";done`
   #echo "projection_file" $projection_file
   line_count=`wc -l $bucket_name/Projections/$projection_file| cut -f 1 -d " "`
   #echo $line_count
   if [ "X$line_count" == "X1" ];then
    echo "expected setting $j from bucket $i is header only"
   else
    continue
   fi
  fi
  echo "expected setting $j missing from bucket $i"
  missing_proj_error=1
  if [ $j == "asc" ];then
   line_count==""
   [ -e $i/Projections/ASC/natl_counts_emd.txt ] && line_count=`wc -l $i/Projections/ASC/natl_counts_emd.txt | cut -d " " -f 1` || echo "natl_counts_emd.txt not found"
   [ "X$line_count" == "X1" ] && echo "***no national emdeon volume in $i/Projections/ASC/natl_counts_emd.txt. Please confirm that this is an accurate reflection of claims counts. If so, remove ASC setting from this bucket and rerun."
   if [ -e $i/Projections/ASC/natl_counts_emd.txt ] && [ "X$line_count" == "X2" ];then
     testline=`cat $i/Projections/ASC/natl_counts_emd.txt | sed -n 2p`
     a=`echo $testline | cut -f 2 -d " "`;b=`echo $testline | cut -f 4 -d " "`;c=`echo $testline | cut -f 6 -d " "`
     #echo $i/Projections/ASC/natl_counts_emd.txt
     #echo $a,$b,$c
     [ $a -lt 2 ] && [ $b -lt 2 ] && [ $c -lt 2 ] && echo "All MDCR values are less than 1. Please confirm that this is accurate. If so, remove ASC setting from this bucket and rerun."
   fi
  fi
 done

 #if [ 1 == 1 ];then
 if [ $missing_proj_error == 1 ];then
  input=$(echo "'";for k in `grep $code_names config/codeGroupMembers.tab | cut -f 2`;do echo $k"','";done)
  input=`echo $input | sed s/" "/""/g | sed s/",'"$/""/g | sed s/"\\."/""/g`
  usetemp=0
  if [ `echo $input | wc -c` -gt 5000 ];then
   #echo "using temp"
   usetemp=1
   temp=$RANDOM
   echo $input > /tmp/"$temp"_codes.tab
   input=/tmp/"$temp"_codes.tab
  fi
  type=`grep $code_names config/codeGroupMembers.tab | cut -f 3 | sort -u`
  #pwd
  #echo $i
  #echo $input
  #echo $type
  #echo "Rscript /vol/cs/clientprojects/mv_utilities/scripts/scripts/claims_volume_count.R $input $type"
  Rscript /vol/cs/clientprojects/mv_utilities/scripts/scripts/claims_volume_count.R $input $type
  printf "\n\n"
 fi

 [ "X$usetemp" == "X1" ] && rm -f /tmp/"$temp"_codes.tab

done < config/codeGroupRules.tab


cd config



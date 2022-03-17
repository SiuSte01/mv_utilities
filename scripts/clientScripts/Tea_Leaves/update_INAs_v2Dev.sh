[[ $HOSTNAME != *"sas"* ]] && [[ $HOSTNAME != *"plr"* ]] && echo "This script must be run from plsas01 or plr01" && exit 1

#source ~/.bash_profile
#source ~/.bashrc

ORACLE_HOME="/home/oracle/product/11.2.0/client_1/"

####update these###
###################

old_date=$1
new_date=$2

###################


#dir="/vol/cs/clientprojects/Tea_Leaves"
###?for testing
dir="/vol/cs/clientprojects/Tea_Leaves"

old_year=`echo $old_date | cut -d "_" -f 1`
new_year=`echo $new_date | cut -d "_" -f 1`

###added to fix issue working with bad date 9/31
date1new=`echo $new_date | cut -f 1,2 -d "_"`
date1new=$date1new"_01"
date1old=`echo $old_date | cut -f 1,2 -d "_"`
date1old=$date1old"_01"

old_month=$(date --date=`echo $date1old | sed s/"_"/""/g` +%b)
new_month=$(date --date=`echo $date1new | sed s/"_"/""/g` +%b)

old_allcodes=`echo $old_month$old_year`
new_allcodes=`echo $new_month$new_year`

echo $old_date,$old_allcodes
echo $new_date,$new_allcodes

currdir=`pwd`

#set up new dir
mkdir -p $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon

any_run=0 #variable to record if anyting has been run

for i in `ls $dir/"$old_date"_PxDx_and_INA/"$old_date"_INA_Emdeon/*INA/*/Comb/Filter/filter_inputs_NEW.txt`
do

 #echo $i
 old_path=`dirname $i`
 new_path=`echo $old_path | sed s@"$old_date"@"$new_date"@g`
 echo $old_path,$new_path

 ###check if this INA exists in the new directory
 test_path=`echo $new_path | sed s@"/Filter"@""@g`
 [ ! -e $test_path ] && printf "Error: $test_path does not exist in new directory.\n" && continue

 ###check if input already exists###
 [ -e $new_path/filter_inputs_NEW.txt ] && printf "Error: $new_path/filter_inputs_NEW.txt already exists.\n" && continue
 ###################################

 mkdir -p $new_path #make new path
 cp $i $new_path/filter_inputs_NEW.txt #copy filter file
 exit
 sed -i s@"$old_date"@"$new_date"@g $new_path/filter_inputs_NEW.txt #replace all old yyy-mm-dd w new date
 sed -i s@"$old_allcodes"@"$new_allcodes"@g $new_path/filter_inputs_NEW.txt #replace all old MmYYYY w new

 ###check for listed files###
 missing_file=0
 files=$(for j in `grep vol $new_path/filter_inputs_NEW.txt`;do echo $j | grep vol;done)
 for file in $files
 do
  ls $file
  [ ! -e $file ] && printf "Error: missing file $file\n" && missing_file=1
 done
 echo $missing_file
 [ $missing_file == 1 ] && printf "Filter will not be run for $new_path\n\n" && continue
 ###############################

 ###check if already run###
 [ -e $new_path/network.txt ] && printf "Error: $new_path/network.txt already exists. Filter will not be run.\n\n" && continue
 #######################################

 ###check if INA exists###
 [ ! -e $new_path/../links.txt ] && printf "Error: links.txt not found. Check that INA has been run for $new_path.\n\n" && continue
 #########################

 ###run filter###
 echo "Now running filter for $new_path"
 any_run=1
 cd $new_path
 nohup perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl filter_inputs_NEW.txt >| stderrout_filter 2>&1
 cd $currdir
 ################

done

[ $any_run == 0 ] && echo "No new filters run." && exit

###check that all new directories have output###
printf "\n\nChecking that all directories have network files.\n\n"

missing_string=""
for i in `ls -d $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon/*INA/*/Comb`
#for i in `ls -d $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon/*INA/*/Comb` #this script does not run ortho INA, so should not check for it
do
 #echo $i
 if [ ! -e $i/Filter/network.txt ]
 then

  missing_string=`echo "$missing_string"$i/Filter/network.txt'\n'`

 fi

done


#echo "$missing_string"

if [ "X$missing_string" != "X" ];then

 printf "The following networks are missing:\n"$missing_string | mail "$USER@healthmarketscience.com" -s "Network Filter Status"
else
 printf "All network files present.\n" | mail "$USER@healthmarketscience.com" -s "Network Filter Status"
fi












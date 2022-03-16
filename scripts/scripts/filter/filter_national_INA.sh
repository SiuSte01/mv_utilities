source ~/.bash_profile

#this script will filter national INAs and drop/rename columns not meaningful for INAs filtered at the national level
#used for medtronic data

[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 2

path=`pwd`
curr_dir_name=`basename $path`

[ $curr_dir_name != "Comb" ] && echo "This script must be run from a Comb directory" && exit 2

temp=$RANDOM
inputs=/vol/cs/CS_PayerProvider/Ryan/utilities/templates/$temp"nat_INA_template.txt"

cp /vol/cs/CS_PayerProvider/Ryan/utilities/templates/filter_inputs_national.txt $inputs

sed -i s@"path_to_denom_fordelivery.txt"@$path"/denom_fordelivery.txt"@g $inputs

mkdir -p $path/national_filter

cd $path/national_filter

cp $inputs $path/national_filter/nat_filter_inputs.txt

echo "running filter"
#nohup perl /home/drajagopalan/udrive/Network/DiagFocus/ABCode/terrfilter_new.pl $path/national_filter/nat_filter_inputs.txt >| stderrout_filter 2>&1
nohup perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl $path/national_filter/nat_filter_inputs.txt >| stderrout_filter 2>&1

echo "updating columns"
Rscript /vol/cs/CS_PayerProvider/Ryan/R/national_INA.R $path/national_filter/network.txt

cd $path

[[ $HOSTNAME != "shell"*".hmsonline.com" ]] && echo "This script must be run from a shell box" && exit 1

dir=`pwd`
folder=`basename $dir`
[ "X$folder" != "Xdelivery" ] && echo "This script must be run from a delivery folder." && exit 1

name=`echo $dir | cut -d "/" -f 6`

if [ $# == 0 ] ;then
 echo "no network directory supplied."
elif [ $# -gt 1 ];then 
 echo "only one argument allowed, path to INA directory."
 exit 3
else
 inas=`ls -d $1/*/Comb/*/*network.txt`
 [ "X$inas" == "X" ] && echo "ina directory not found." && exit 4
 for i in $inas
 do
  inaname=`echo $i | rev | cut -d "/" -f 4 | rev`
  cp $i ./$inaname"_network.txt"
 done
fi 

[ ! -e $dir/payermix.txt ] && cp ../Payermix_Rx/payermix.txt ./

[ ! -e $dir/"$name"_csv.zip ] && zip -j "$name"_csv.zip *.csv
[ ! -e $dir/"$name"_txt.zip ] && zip -j "$name"_txt.zip *.txt

if [ ! -e $dir/tables.html ];then 
 tables=`ls ../milestones/*.tab | grep -v skinny`
 tables=$(echo $tables `ls payermix.txt`)
 tables=$(echo $tables `ls *network.txt 2>/dev/null`)
 tableinfo $tables > tables.html
 /vol/cs/CS_PayerProvider/Ryan/utilities/fix_html_tables.sh
fi

if [ ! -e $dir/../appendixA.tab ];then
 appendixpath=`ls $dir/../config/codeGroupMembers.tab`
 ssh "$USER"@plsas01.hmsonline.com "source .bash_profile && cd $dir && /vol/cs/CS_PayerProvider/Ryan/utilities/appendixA.sh $appendixpath"
fi


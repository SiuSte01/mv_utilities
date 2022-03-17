####update these###
###################

old_date=2016_08_31
new_date=2016_09_30

###################


#dir="/vol/cs/clientprojects/Tea_Leaves"
###?for testing
dir="/vol/cs/CS_PayerProvider/Ryan/utilities/Tea_Leaves/testing"


###check that all new directories have output###
printf "\n\nChecking that all directories have network files.\n\n"

missing_string=""
for i in `ls -d $dir/"$new_date"_PxDx_and_INA/"$new_date"_INA_Emdeon/*INA/*/Comb`
do
 #echo $i
 if [ ! -e $i/Filter/network.txt ]
 then

  missing_string="$missing_string"$i/Filter/network.txt'\n'

 fi

done


#echo "$missing_string"

if [ "X$missing_string" != "X" ];then

 printf "The following networks are missing:\n"$missing_string | mail "$USER@healthmarketscience.com" -s "Network Filter Status"
else
 printf "All network files present.\n" | mail "$USER@healthmarketscience.com" -s "Network Filter Status"
fi







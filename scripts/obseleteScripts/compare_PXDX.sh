dir1=$1
dir2=$2

for i in `echo ../codeGroupFileTypeDescriptions.tab ../settings.mak codeGroupMembers.tab codeGroupRules.tab codeGroups.tab jobVendorSettings.tab settings.cfg`
do
 echo "************************"
 echo $i
 diff $dir1/config/$i $dir2/config/$i

done





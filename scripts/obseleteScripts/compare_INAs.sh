dir1=$1
dir2=$2

for i in `echo ../codeGroupFileTypeDescriptions.tab claimSettings.tab codeGrpMembrs.tab networkConfigSettings.tab codeGroups.tab settings.cfg`
do
 echo "************************"
 echo $i
 diff $dir1/config/$i $dir2/config/$i

done




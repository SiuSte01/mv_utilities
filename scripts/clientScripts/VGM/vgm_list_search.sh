codelists=`find /vol/cs/clientprojects/VGM/201[78]*"$1"* -name "codeGroupMembers.tab"`
newlen=`wc -l $2 | cut -d " " -f 1`

echo "newlen,oldlen,overlap,list"
for i in $codelists
do
 oldlen=`grep "PX" $i | wc -l | cut -d " " -f 1`
 overlap=0
 for j in `cat $2`
  do
   grep -qw $j $i && ((overlap++))
  done

 [ $overlap != 0 ] && echo $newlen, $oldlen, $overlap, $i
done

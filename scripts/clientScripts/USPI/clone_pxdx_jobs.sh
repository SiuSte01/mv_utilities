[[ $HOSTNAME != "shell"*".dpprod.hmsonline.com" ]] && echo "This script must be run from a shell box" && exit 2

olddate=2016_05_05
newvint=20160914
newdate=2016_09_20

currdir=`pwd`

for i in `ls -d /vol/cs/clientprojects/USPI/$olddate"_"*"_"PxDx`
do

 echo $i
 newpath=`echo $i | sed s@$olddate@$newdate@g`
 echo $newpath
 mkdir -p $newpath
 cd $newpath
 perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/pxdx/copyPxDxJob.pl -configDir $i -vintage $newvint -copyType dory
 mv outDir/* ./
 rmdir outDir
 cd $currdir
done




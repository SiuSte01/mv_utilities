for i in `ls /vol/cs/clientprojects/HealthGrades/2016_07_29_Refresh/2016_07_01_Client_Files/outDir/ncileGroups/group0/therapyLines/Rollup/*/*/ASC/natl_counts_emd.txt`
do
printf "\n****"
echo $i
change=0
lc=`cat $i | wc -l`
if [ $lc == 1 ];then
 change=1
 echo "only one line found, no national EMD data"
else
 a=`cat $i | sed -n 2p | cut -f 2`
 b=`cat $i | sed -n 2p | cut -f 4`
 c=`cat $i | sed -n 2p | cut -f 6`
 [ "X$a$b$c" == "X000" ] && change=1 && echo "all fields zero" || echo "volumes found $a $b $c"
fi

echo $change
if [ "X$change" == "X1" ];then
 path=`echo $i | cut -d "/" -f 1-13`
 ls $path/settings.mak
 sed -i s@"ASCPROJ := 1"@"ASCPROJ := "@g $path/settings.mak
 echo $path/settings.mak >> /vol/cs/CS_PayerProvider/Ryan/utilities/HG/check_ASC_volumes.log
fi

done

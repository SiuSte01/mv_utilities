pxdxdir=/vol/cs/clientprojects/USPI/2017_04_14_PxDx
payermixdir=/vol/cs/clientprojects/USPI/2017_04_14_Payermix
currdir=`pwd`

cut -f 1 $pxdxdir/CARDIO_COMB/milestones/individuals.tab | grep -v HMS_PIID > $payermixdir/temp.txt

cut -f 1 $pxdxdir/milestones/individuals.tab | grep -v HMS_PIID >> $payermixdir/temp.txt

cut -f 1 $pxdxdir/PVD_COMB/milestones/individuals.tab | grep -v HMS_PIID > $payermixdir/temp.txt

echo "HMS_PIID" > $payermixdir/piids.txt

cat $payermixdir/temp.txt | sort -u >> $payermixdir/piids.txt

rm -f $payermixdir/temp.txt


cp /HDS/cs/Training/Sales_Support/Payer_Mix/BasedOn_RX_Data/inputs.txt $payermixdir/inputs.txt

###update vintage
vfull=`grep VINTAGE $pxdxdir/settings.mak | cut -d " " -f 3`
vyear=`echo $vfull | cut -d "/" -f 3`
vmonth=`echo $vfull | cut -d "/" -f 1`
vday=`echo $vfull | cut -d "/" -f 2`
vnew=`echo $vyear$vmonth$vday`
vold=`grep Vintage $payermixdir/inputs.txt | cut -f 2`
sed -i s@"$vold"@"$vnew"@g $payermixdir/inputs.txt

###turn off exclude cash
sed -i s@"ExcludeCash\tY"@"ExcludeCash\tN"@g $payermixdir/inputs.txt

cd $payermixdir
R CMD BATCH --vanilla /vol/datadev/Statistics/Projects/PayerMix/pulldata.R &
cd $currdir


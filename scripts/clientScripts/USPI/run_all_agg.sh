[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1

dir=`pwd`
for i in /vol/cs/clientprojects/USPI/2016_09_20_*1_PxDx
do
echo "##############"
echo $i
cd $i/config
nohup perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg >| stderrout_aggrproj 2>&1 &
#echo "broken - nohup watch_for_email2.sh $! $i &"
cd $dir
done

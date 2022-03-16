###this script is designed to download the latest LDS order form for CMS, and check if the version has changed.

curdate=`date +%D`
lastcmscheck=`cat /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/most_recent.txt`

[[ "x$curdate" == "x$lastcmscheck" ]] && exit 1

echo "running"

[[ "x$curdate" != "x$lastcmscheck" ]] && rm -f /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/most_recent.txt && echo $curdate > /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/most_recent.txt

wget -P /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order "https://www.cms.gov/Research-Statistics-Data-and-Systems/Files-for-Order/LimitedDataSets/Downloads/LDSOrderForm.zip" >| /dev/null 2>&1

oldhash=`sha1sum /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDS_old.zip | cut -f1 -d " "`
newhash=`sha1sum /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDSOrderForm.zip | cut -f1 -d " "`

if [ "X$oldhash" == "X$newhash" ]; then
 rm -f /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDSOrderForm.zip
else
 echo "update"
 rm -f /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDS_old.zip
 mv /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDSOrderForm.zip /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/LDS_old.zip
 python /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/pymail.py
 echo $curdate >> /vol/cs/clientprojects/mv_utilities/scripts/scripts/monitor_cms_order/update_record.txt
fi




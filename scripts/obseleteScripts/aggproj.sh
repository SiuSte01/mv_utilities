##MUST be run from sas box
[[ $HOSTNAME != "plsas01.hmsonline.com" ]] && echo "This script must be run from a shell box" && exit 1

##MUST be run from dory config folder
dir=`pwd`
folder=`basename $dir`
[ $folder != "config" ] && echo "This script must be run from a config directory" && exit 2

perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg >| stderrout_aggrproj 2>&1

/vol/cs/CS_PayerProvider/Ryan/utilities/qc_projections.sh > $dir/qc_projections.txt


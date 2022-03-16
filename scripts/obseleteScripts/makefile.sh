#This script is simply a wrapper for the makefile command that checks to make sure it is being run from a shellbox, config directory, and that the settings.cfg file is set to "Makefile" - rdh

[[ $HOSTNAME != "shell"*".dpprod.hmsonline.com" ]] && echo "This script must be run from a shell box" && exit 1
test=$(basename $(pwd))
[ "$test" != "config" ] && echo "This script must be run from a config directory." && exit 2
test2=`grep ANALYSIS_TYPE ../settings.cfg | cut -d "=" -f 2 | sed s/" "/""/g`
[ "X$test2" != "XMakefile" ] && echo "Make sure settings.cfg has been set to ANALYSIS_TYPE = Makefile" && exit 3

if [ $# == 1 ];then
 nohup perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg -multiBucket >| $1 2>&1 &
elif [ $# == 0 ];then
 perl /vol/cs/clientprojects/Facility_Automation/scripts/aggr/loadAggr.pl -config settings.cfg -multiBucket >| stderrout_makefile 2>&1
else
 echo "Only one argument allowed, stderrout name" && exit 4
fi

for i in `cat codeGroupRules.tab | cut -f 1 | sort -u | grep -v BUCKET_NAME`
do
 testing=`ls ../$i/milestones`
 testing=`echo $testing | sed s@" "@"_"@g`
 [ "$testing" == "fac_decile_breakdown.tab_Facility_TOTAL.tab_indiv_decile_breakdown.tab_individuals.tab_organizations.tab_pxdx.tab" ] && echo "All milestones files present" || echo "Milestones missing for $i"

done



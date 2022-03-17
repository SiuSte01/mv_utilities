for i in `ls -d /vol/cs/clientprojects/Fresenius/2016_08_16_Chronic_Kidney_Disease_INA/*DxCohort`
do

bucket=`echo $i | cut -d "/" -f 7 | cut -d "_" -f 1`
mkdir -p $i/Comb/Filter

piidlist=`ls /vol/cs/clientprojects/Fresenius/2016_08_16_Chronic_Kidney_Disease/$bucket/milestones/individuals.tab`

[ "X$piidlist" == "X" ] && echo "piidlist not found for $bucket" && continue

cp filter_inputs_NEW

done






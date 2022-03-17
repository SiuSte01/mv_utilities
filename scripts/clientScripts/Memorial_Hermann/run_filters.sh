#date="2016_12_16"
#directory=/vol/cs/clientprojects/Memorial_Hermann/2016_12_08_MH_PxDxs

date="2017_10_24"
#directory=/vol/cs/clientprojects/Memorial_Hermann/2017_04_16_MH_PxDx
directory=/vol/cs/clientprojects/Memorial_Hermann/2017_10_27_MH_PxDxs
filterlist=/vol/cs/CS_PayerProvider/Ryan/utilities/MH/2017_Apr_buckets_to_filter.txt
allcodemonth=Oct2017

#for i in `ls -d $directory/*/*/*/milestones | cut -d "/" -f 7-9 | grep -v Eval_Management/2016_08_08_PxDx_PED_EM/PEDS`
#do
#echo i: $i

#for testing:
#i="DB_GenSurg_General_PxDx/GenSurg_BreastSurg_OP_Px"

for i in `cat $filterlist | cut -d "/" -f 7-9`
#for i in `head -n1 $filterlist | cut -d "/" -f 7-9`
do
 echo i: $i
 
# continue

 ####this code was used to fix an old error, not needed 
 #line=""
 #line=`grep $i /vol/cs/CS_PayerProvider/Ryan/utilities/MH/buckets.csv`
 #status=`echo $line | cut -d "," -f 2`
 #echo status: $status
 #if [ "$status" == "completed" ];then
 # echo "$i already run"
 # continue
 #fi
 
 bucket=`echo $i | cut -d "/" -f 2`
 echo bucket: $bucket
 
 INA_path=""
 
 #if [ "X$status" == "X" ];then
 #decision made to only run allcodes automated
 # INA_path=/vol/cs/clientprojects/PxDxStandardizationTesting/QuarterlyAllCodes/$allcodemonth/INA_Expanded_AS/INA_Expanded_All_Codes_AS/Comb
  INA_path=/vol/cs/clientprojects/PxDxStandardizationTesting/MonthlyAllCodes/Oct2017/INA_Expanded/AllCodes_PIIDtoPIID_Expanded/Comb
 #else
 # INA_path=$directory/$status/Comb
 # echo "INA present or already run: $status"
 # printf "*****************\n\n"
 # continue
 #fi
 
 #continue
 
 test=`ls $INA_path/$date"_"$bucket/done.txt 2> /dev/null`
 [ "X$test" != "X" ] && printf "file $test already exists. filter for $i appears complete\n***********************\n\n" && continue
 
 cp /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs.txt /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs_"$bucket".txt
 
 sed -i s@"PATH_TO_REPLACE"@"$i"@g /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs_"$bucket".txt
 sed -i s@"BUCKET_NAME_TO_REPLACE"@"$bucket"@g /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs_"$bucket".txt
 sed -i s@"DIRECTORY_TO_REPLACE"@"$directory"@g /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs_"$bucket".txt
 
 Rscript /vol/cs/CS_PayerProvider/Ryan/R/makepiidlist_rdh.R /vol/cs/CS_PayerProvider/Ryan/utilities/MH/piidselectioninputs_"$bucket".txt $directory/$i
 
 echo "piidlist.txt written to $directory/$i"
 
 mkdir -p $INA_path/$date"_"$bucket
 
 echo INA: $INA_path/$date"_"$bucket
 
 type=Dx
 echo $bucket | grep -q "_Px_" && type=Px
 
 echo type: $type
 
 mkdir -p $INA_path/$date"_"$bucket
 
 ###decision was made to run these only on allcodes in an automated fashion
 #if [ $type == "Px" ];then
 # #for Px, only diff between allcodes and INA is in the piidlist. Actual filter step is the same.
 # template_location=$INA_path/$date"_"$bucket/filter_inputs_px_cohort.txt
 # cp /vol/cs/CS_PayerProvider/Ryan/utilities/MH/templates/px_allcodes_filter_template.txt $template_location
 #elif [ $type == "Dx" ];then
 # #printf "dx being tested\n*****************\n\n"
 # #continue
 # template_location=$INA_path/$date"_"$bucket/filter_inputs_dx_cohort.txt
 # if [ "X$status" == "X" ];then
 #  cp /vol/cs/CS_PayerProvider/Ryan/utilities/MH/templates/dx_allcodes_filter_template.txt $template_location
 # else
 #  cp /vol/cs/CS_PayerProvider/Ryan/utilities/MH/templates/dx_INA_filter_template.txt $template_location
 # fi
 #fi
 
 template_location=$INA_path/$date"_"$bucket/filter_inputs.txt
 cp /vol/cs/CS_PayerProvider/Ryan/utilities/MH/templates/filter_inputs_updated_INA.txt $template_location
 
 echo "template location: $template_location"
 
 #replace placeholders
 sed -i s@'BUCKET_NAME_REPLACE'@"$bucket"@g $template_location
 sed -i s@'PIIDLIST_PATH_REPLACE'@"$directory/$i/piidlist.txt"@g $template_location
 sed -i s@'PATH_REPLACE'@"$i"@g $template_location
 sed -i s@'DIRECTORY_REPLACE'@"$directory"@g $template_location
 
 echo "Running filter for $i"
 
 dir=`pwd`
 
 cd $INA_path/$date"_"$bucket
 nohup perl /vol/datadev/Statistics/Projects/HGWorkFlow/Prod_NewWH/INA/terrfilter_new.pl $template_location >| "$bucket"_stderrout_filter 2>&1
 cd $dir
 
 printf "*****************\n\n"
 
done


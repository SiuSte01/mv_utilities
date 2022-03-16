#must be run from plsas01

#purpose of this script is to filter a project into multiple regions for VGM. as in input, it takes the path to a directory of statelists, in the QA folder of the project you are filtering.

#files should be named Region#_statelist.txt

#input for filter should be present in QA

path=/vol/cs/clientprojects/VGM/2018_01_10_Townsend_Design_OTS_Bracing_CustomAFOKAFO/QA/lists
currdir=`pwd`
cd $path/..

#for i in `ls $path/*statelist.txt`
#for i in `ls $path/Region1_statelist.txt`
#for i in `ls $path/Region*_statelist.txt | grep -v Region1`
for i in `ls $path/Region*_statelist.txt`
do
 regionname=`basename $i | sed s@"_statelist.txt"@@g`
 echo $regionname
 cp $i $path/../statelist.txt
 Rscript /vol/cs/Training/Sales_Support/Filtering_for_MarketView_workbooks/regionalfilter.R
 ls $path/../../milestones/*_sample.tab
 for j in `ls $path/../../milestones/*_sample.tab`
 do
  filename=`basename $j | sed s@"_sample"@"_$regionname"@g`
  echo $filename
  mv $j $path/../../milestones/$filename
 done

 mv $path/../statelist.txt $path/../"$regionname"_statelist.txt

done

cd $currdir


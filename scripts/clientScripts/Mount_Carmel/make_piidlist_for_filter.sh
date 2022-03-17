[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1
current_dir=`pwd`

for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016_*INA/*/Comb`
#for i in `ls -d /vol/cs/clientprojects/Mount_Carmel/2016_05_18_Breast*INA/*/Comb`
do
 [ -e $i/Filter ] && echo "$i already filtered" && continue
 echo "*****running for $i"
 mkdir -p $i/Filter
 if [ ! -e $i/Filter/zips.txt ] ;then
  cp /vol/cs/CS_PayerProvider/Ryan/utilities/Mount_Carmel/piidselectioninputs.txt $i/Filter/
  cp /vol/cs/clientprojects/Mount_Carmel/2016_05_18_Pain_Px/spec_filter.txt $i/Filter/
  cp /vol/cs/clientprojects/Mount_Carmel/zips.txt $i/Filter/
 
 fi
 
 pxdx_dir=`echo $i | cut -d "/" -f 1-6 | sed s@"_INA"@""@g`
 [ ! -e $pxdx_dir ] && echo "$pxdx_dir not found" && continue

 indivs=`ls $pxdx_dir/*/QA/individuals.tab`
 pxdx=`ls $pxdx_dir/*/QA/pxdx.tab`

 [ "X$indivs" == "X" ] || [ "X$pxdx" == "X" ] && echo "no indivs or pxdx found" && continue

 #get column header
 count=$(for i in `head -n1 $indivs`;do echo $i | grep PRACTITIONER_NATL_RANK;done | wc -l)
 [ $count != 1 ] && echo "unable to identify column header" && head -n1 $indivs && continue
 header=$(for i in `head -n1 $indivs`;do echo $i | grep PRACTITIONER_NATL_RANK;done)

 sed -i s@"replace_indivs"@$indivs@g $i/Filter/piidselectioninputs.txt
 sed -i s@"replace_pxdx"@$pxdx@g $i/Filter/piidselectioninputs.txt
 sed -i s@"replace_col_header"@$header@g $i/Filter/piidselectioninputs.txt

 cd $i/Filter

 R CMD BATCH --vanilla  /vol/homes/drajagopalan/Network/DiagFocus/ABCode/makepiidlist.R

 cd $current_dir

done




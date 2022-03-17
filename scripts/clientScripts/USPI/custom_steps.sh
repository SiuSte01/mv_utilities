new_date="2016_10_03"
run_date="2016_09_20"

#[ -e /vol/cs/clientprojects/USPI/"$new_date"_PxDx ] && echo "directory already exists. check if run."
#
#mkdir -p /vol/cs/clientprojects/USPI/"$new_date"_PxDx
#
#cp /vol/cs/clientprojects/USPI/2016_05_10_PxDx/zip_cbsa.txt /vol/cs/clientprojects/USPI/"$new_date"_PxDx/
#
#for i in `ls -d /vol/cs/clientprojects/USPI/"$run_date"* |grep -v INA`
#do
#
# echo $i
# for j in `ls -d $i/*/codes`
# do
#  dir=`dirname $j`
#  cp -r $dir /vol/cs/clientprojects/USPI/"$new_date"_PxDx
# done
#
#done
#

currdir=`pwd`

#
#for i in `ls -d /vol/cs/clientprojects/USPI/"$new_date"_PxDx/* | grep -v ALL_SURG | grep -v zip`
#do
#
# echo $i
# cp /vol/cs/clientprojects/USPI/Repository/bucket/Makefile $i/
# cd $i
# make all >| stderrout 2>&1&
# cd $currdir
#
#done
#
#echo "waiting for makefiles to finish"
#while [ `ls /vol/cs/clientprojects/USPI/"$new_date"_PxDx/*/milestones/HMS_Ind* | wc -l` -lt 18 ];do sleep 300;done

echo "running all_surg makefile"
cp /vol/cs/clientprojects/USPI/Repository/ALL_SURGERY/Makefile /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/
cd /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/
make all >| stderrout 2>&1
cd $currdir

echo "running patch makefile"
mkdir -p /vol/cs/clientprojects/USPI/"$new_date"_PxDx/PATCH
cp /vol/cs/clientprojects/USPI/Repository/PATCH/Makefile /vol/cs/clientprojects/USPI/"$new_date"_PxDx/PATCH/
cd /vol/cs/clientprojects/USPI/"$new_date"_PxDx/PATCH/
make all >| stderrout 2>&1
cd $currdir

echo "running patched all_surg makefile"
mv /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/Makefile /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/makefile_old
cp /vol/cs/clientprojects/USPI/Repository/ALL_SURGERY/Makefile_patch /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/Makefile
cd /vol/cs/clientprojects/USPI/"$new_date"_PxDx/ALL_SURGERY/
make all >| stderrout_patch 2>&1
cd $currdir


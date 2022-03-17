for i in `cat $i`
do

 path=`echo $i | cut -d "/" -f 1-13`
 ls $path/settings.mak
 sed -i s@"ASCPROJ := 1"@"ASCPROJ := "@g $path/settings.mak
 echo $path/settings.mak >> /vol/cs/CS_PayerProvider/Ryan/utilities/HG/remove_ASC_from_makefile.log

done



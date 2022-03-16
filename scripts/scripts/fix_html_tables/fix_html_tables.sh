if [ $# == 1 ];then
 table_location=$1
elif [ $# == 0 ];then
 table_location=tables.html
else
 echo "This script can take one argument, the location of the html output of tableinfo. If none is supplied, the default tables.html is used."
 exit 1
fi

table_test=`ls $table_location 2> /dev/null`
[ "X$table_test" == "X" ] && echo "No table found. Either supply the path to a table or run this script from a directory containing a 'tables.html' file." && exit 2

sed -i s@"\*"@"ast_ast"@g $table_location
sed -i s@" "@"~"@g $table_location
sed -i s@"\&"@"amp_amp"@g $table_location

for i in `grep '<body>' $table_location | sed s@"/tr>"@"/tr>\n"@g`
 do
 echo $i | grep -q "_FAC_NATL_RANK".*"Decile~of~doctor~at~facility" && newline=`echo $i | sed s@"Decile~of~doctor~at~facility"@"Decile~of~facility~nationally"@g` && sed -i s@"$i"@"$newline"@g $table_location

 echo $i | grep -q "_FAC_TERR_RANK".*"Decile~of~doctor~at~facility" && newline=`echo $i | sed s@"Decile~of~doctor~at~facility"@"Decile~of~facility~in~territory"@g` && sed -i s@"$i"@"$newline"@g $table_location


 echo $i | grep -qv '"Comments"><' && continue
 echo "****"$i | cut -d ">" -f 3 | cut -d "<" -f 1
 while read line;do
  fn=`echo $line | cut -f 1 -d ","`
  desc=`echo $line | cut -f 2 -d ","`
  #echo $i
  #echo $line
  #echo $fn
  #echo $desc
  
  echo "$i" | grep -q $fn && newline=`echo $i | sed s@'"Comments"></td>'@"\"Comments\">$desc</td>"@g` && sed -i s@"$i"@"$newline"@g $table_location
 done < /vol/cs/CS_PayerProvider/Ryan/utilities/missing_fields.txt
done

sed -i s@"~"@" "@g $table_location
sed -i s@"’"@"\'"@g $table_location
sed -i s@"ast_ast"@"\*"@g $table_location
sed -i s@"amp_amp"@"\&"@g $table_location



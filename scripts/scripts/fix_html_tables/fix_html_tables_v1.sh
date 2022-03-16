sed -i s@"\*"@"ast_ast"@g tables.html
sed -i s@" "@"~"@g tables.html

for i in `grep '<body>' tables.html | sed s@"/tr>"@"/tr>\n"@g`
 do
 echo $i | grep -q "_FAC_NATL_RANK".*"Decile~of~doctor~at~facility" && echo $i && newline=`echo $i | sed s@"Decile~of~doctor~at~facility"@"Decile~of~facility~nationally"@g` && sed -i s@"$i"@"$newline"@g tables.html

 echo $i | grep -q "_FAC_TERR_RANK".*"Decile~of~doctor~at~facility" && echo $i && newline=`echo $i | sed s@"Decile~of~doctor~at~facility"@"Decile~of~facility~in~territory"@g` && sed -i s@"$i"@"$newline"@g tables.html


 echo $i | grep -qv '"Comments"><' && continue
 echo "****"$i
 while read line;do
  fn=`echo $line | cut -f 1 -d ","`
  desc=`echo $line | cut -f 2 -d ","`
  #echo $i
  #echo $line
  #echo $fn
  #echo $desc
  
  echo "$i" | grep $fn && newline=`echo $i | sed s@'"Comments"></td>'@"\"Comments\">$desc</td>"@g` && echo $newline && sed -i s@"$i"@"$newline"@g tables.html
 done < /vol/cs/CS_PayerProvider/Ryan/utilities/missing_fields.txt
done

sed -i s@"~"@" "@g tables.html
sed -i s@"’"@"\'"@g tables.html
sed -i s@"ast_ast"@"\*"@g tables.html




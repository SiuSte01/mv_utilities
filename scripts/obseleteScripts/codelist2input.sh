[ $# != 2 ] && echo "requires 2 args: infile and outfile" && exit 1

test=`ls -d $2 2> /dev/null`
[ "X$test" != "X" ] && echo "out file already exists" && exit 2

printf "CODE_GROUP\tCODE\tTYPE\tSCHEME\n" > $2

cat $1 | awk -F"\t" '{print $1"\t"$5"\t"$3"\t"$4}'| sed -n 2,'$'p | sed s/"\tDX\t"/"\tdx\t"/g | sed s/"\tPX\t"/"\tpx\t"/g >> $2


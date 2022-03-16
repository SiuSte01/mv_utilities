#[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1
[ $# != 1 ] && echo "This script requires the path to a codeGroupMembers.tab or codeGrpMembrs.tab file, created by DORY or INAB" && exit 2
echo $1 | grep -Eqv 'codeGroupMembers.tab|codeGrpMembrs.tab' && echo "This script requires the path to a codeGroupMembers.tab or codeGrpMembrs.tab file, created by DORY or INAB" && exit 2
[ ! -e $1 ] && echo "infile $1 not found. Please make sure you are providing the full path" && exit 3

echo running $1
Rscript /vol/cs/CS_PayerProvider/Ryan/R/make_appendix_A_from_code_list.R $1

dir=`dirname $1`
echo "appendixA created at $dirname/appendixA.tab. If copying into excel, make sure to format all cells as text to avoid dropped 0's."



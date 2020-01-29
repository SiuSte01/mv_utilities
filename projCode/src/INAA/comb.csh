#!/bin/csh

setenv rootdir `dirname $0`
echo "Utilizing SAS dir: $rootdir"

#read input file to determine how many bins to rank strength of relationship
#use default of quintile if not present in input file
set sorbin = `grep SORBins  ../inputs | awk '{print $2}'`
if ($sorbin == "")  then
  setenv SORBIN  5
else
 setenv SORBIN $sorbin
endif
echo "will use $sorbin bins for ranking strength of relationship"

#check if min shared patient count is specified in inputs
set minshrpat = `grep MinSharedPats ../inputs | awk '{print $2}'`
if ($minshrpat == "")  then
  setenv MINSHRPAT  2
else
 setenv MINSHRPAT $minshrpat
endif

#figure out if links are broken out by payer group
set linksbypayer = `grep INCLUDE_PAYER_TYPE_BREAK ../../config/settings.cfg | sed -e "s/ //g" | cut -d\= -f2`
echo $linksbypayer

#figure out the aggregation id to pull
set aggrid = `grep AggrID  ../inputs | awk '{print $2}'`
setenv AGGRID $aggrid

#figure out the database settings and set env variables
set dbname = `grep DBNAME  ../inputs | awk '{print $2}'`
setenv DBNAME $dbname
set dbuser = `grep DBUSER  ../inputs | awk '{print $2}'`
setenv DBUSER $dbuser
set dbpass = `grep DBPASS  ../inputs | awk '{print $2}'`
setenv DBPASS $dbpass
set bucket = `grep Bucket  ../inputs | awk '{print $2}'`
setenv BUCKET $bucket
set groups = `grep Groups  ../inputs | awk '{print $2}'`
setenv GROUPS $groups
set grp1type = `grep Grp1Type  ../inputs | awk '{print $2}'`
setenv GRP1TYPE $grp1type
set grp1ent = `grep Grp1Ent  ../inputs | awk '{print $2}'`
setenv GRP1ENT $grp1ent
set grp1codegrp = `grep Grp1CodeGrp  ../inputs | awk '{print $2}'`
setenv GRP1CODEGRP $grp1codegrp
if($groups == 2) then
 set grp2type = `grep Grp2Type  ../inputs | awk '{print $2}'`
 setenv GRP2TYPE $grp2type
 set grp2ent = `grep Grp2Ent  ../inputs | awk '{print $2}'`
 setenv GRP2ENT $grp2ent
 set grp2codegrp = `grep Grp2CodeGrp  ../inputs | awk '{print $2}'`
 setenv GRP2CODEGRP $grp2codegrp
endif


#run SAS code to combine the 3 links file together and do quintiling
if($linksbypayer == "Yes") then
 sas -memsize 8G -noterminal $rootdir/combinelinks_psplit.sas
else
 sas -memsize 8G -noterminal $rootdir/combinelinks.sas
endif

#read input file to determine whether to quintile or decile denom.   
#use default of quintile if not present in input file
set dbin = `grep DenomBins  ../inputs | awk '{print $2}'`
if ($dbin == "")  then
  setenv DBIN  5
else
 setenv DBIN $dbin
endif
echo "will use $dbin bins for ranking denom"


#run SAS code to combine the 3 denom file together and do quintiling
sas -memsize 8G -noterminal $rootdir/combinedenom.sas

#need to add the connectivity calc in perl
#
perl $rootdir/simplecomb.pl

#do the sphere calculation if 1 group
#set mygrp = `cut -f1 ../codes | grep -v Group | sort -u | wc -l`
#if($mygrp == 2) then
# perl $rootdir/calcn2.pl
#endif

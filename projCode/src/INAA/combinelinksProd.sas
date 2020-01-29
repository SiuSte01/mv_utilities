options mprint;
*pull the link counts from Oracle;
*do quintiles;

*macro to pull the link counts using env var of aggr id;
%macro getlinks;
 %let aggrid=%sysget(AGGRID);
 %let dbname=%sysget(DBNAME);
 %let dbuser=%sysget(DBUSER);
 %let dbpass=%sysget(DBPASS);
 %let bucket=%sysget(BUCKET);
 %let minshrpat=%sysget(MINSHRPAT);

 proc sql ;
  connect to oracle(user=&dbuser. password=&dbpass. path=&dbname.) ;
   create table links as
    select * from connection to oracle
     (select var1,count from
     (select provider1||':'||provider2 as var1,sum(ptnt_count) as count
      from INA_NETWORK_VW where job_id=&aggrid
      and provider1 <> 'NULL' and provider2 <> 'NULL'
      and network_name=%unquote(%str(%'&bucket%'))
      group by provider1||':'||provider2
      order by count desc
     ) where count >= &minshrpat);
 disconnect from oracle ;
 quit ;
%mend;

*call the getlinks macro;
%getlinks;

*macro to do input driven binning of link strength;
%macro linkbinning;
 %let sorbins=%sysget(SORBIN);
 proc rank data = links
   groups = &sorbins
   out=quint;
   var count;
   ranks cq;
 run;
%mend;

%linkbinning;

proc export data = quint file='links.txt' replace;
run;

proc sort data = quint;
by count;
run;

proc means data = quint noprint nway; 
by cq;
var count;
output out=linktab (drop = _TYPE_ _FREQ_) n=count median=median mean=mean min=min max=max;
run;

data linktab;
set linktab;
mean=round(mean,0.1);
run;

proc export data = linktab file='linksummarycounts.txt' replace;
run;

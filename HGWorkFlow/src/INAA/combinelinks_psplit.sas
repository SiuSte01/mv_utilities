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
     (select var1,var2,count from
     (select provider1||':'||provider2 as var1,payer_type as var2,
       sum(ptnt_count) as count
      from INA_NETWORKS_NEW where job_id=&aggrid
      and payer_type is not NULL 
      and provider1 <> 'NULL' and provider2 <> 'NULL'
      and network_name=%unquote(%str(%'&bucket%'))
      group by provider1||':'||provider2, payer_type
      order by count desc
     ) where count >= &minshrpat);
 disconnect from oracle ;
 quit ;
%mend;

*call the getlinks macro;
%getlinks;

proc export data = links file='links.txt' replace;
run;

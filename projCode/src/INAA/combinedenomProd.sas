options mprint;
*pull the denom data from Oracle aggr table;
*do quintiles or deciles or other ranking, depending on input;

*macro to do input driven binning of denom;
%macro binning;
 %let dbins=%sysget(DBIN);
 proc rank data = denom
   groups = &dbins
   out=quint (drop = patcnt);
   by var4;
   var patcnt;
   ranks cq;
 run;
%mend;

*macro to pull the denom counts using env var of aggr id;
%macro getdenom;
 %let aggrid=%sysget(AGGRID);
 %let dbname=%sysget(DBNAME);
 %let dbuser=%sysget(DBUSER);
 %let dbpass=%sysget(DBPASS);
 %let bucket=%sysget(BUCKET);
 %let groups=%sysget(GROUPS);
 %let grp1type=%sysget(GRP1TYPE);
 %let grp1ent=%sysget(GRP1ENT);
 %let grp1codegrp=%sysget(GRP1CODEGRP);
 %if &groups = 2 %then %do;
   %let grp2type=%sysget(GRP2TYPE);
   %let grp2ent=%sysget(GRP2ENT);
   %let grp2codegrp=%sysget(GRP2CODEGRP);
 %end;
  
 %if &groups = 2 %then 
   %do;
     proc sql ;
      connect to oracle(user=&dbuser. password=&dbpass. path=&dbname.) ;
       create table denom3 as
        select * from connection to oracle
         (select provider_id as hms_id, 'Grp1' as var4, count as patcnt
            from INA_DENOM t where job_id=&aggrid
            and network_name=%unquote(%str(%'&bucket%'))
            and bucket_type=%unquote(%str(%'&grp1type%')) 
            and bucket=%unquote(%str(%'&grp1codegrp%'))
            and substr(provider_id,1,2) = %unquote(%str(%'&grp1ent%'))
          union
           select provider_id as hms_id, 'Grp2' as var4, count as patcnt
            from INA_DENOM t where job_id=&aggrid
            and network_name=%unquote(%str(%'&bucket%'))
            and bucket_type=%unquote(%str(%'&grp2type%')) 
            and bucket=%unquote(%str(%'&grp2codegrp%'))
            and substr(provider_id,1,2) = %unquote(%str(%'&grp2ent%'))
         );
     disconnect from oracle ;
     quit ;
   %end;
 %else %if &groups = 1 %then
   %do;
     proc sql ;
      connect to oracle(user=&dbuser. password=&dbpass. path=&dbname.) ;
       create table denom3 as
        select * from connection to oracle
         (select provider_id as hms_id, 'Grp1' as var4, count as patcnt
            from INA_DENOM t where job_id=&aggrid
            and network_name=%unquote(%str(%'&bucket%'))
            and bucket_type=%unquote(%str(%'&grp1type%'))
            and bucket=%unquote(%str(%'&grp1codegrp%'))
            and substr(provider_id,1,2) = %unquote(%str(%'&grp1ent%')))
   %end;

%mend;

*call the macro to get the denom;
%getdenom;

proc sort data = denom3;
by hms_id var4;
run;

proc means data = denom3 noprint;
by hms_id var4;
var patcnt;
output out=denom sum=patcnt;
run;

proc sort data = denom;
by var4;
run;

%binning;

proc sort data = denom;
by hms_id;
run;

proc transpose data = denom out=denomtr (drop = _NAME_ _LABEL_
     rename = (Grp1 = Grp1Cnt Grp2 = Grp2Cnt));
by hms_id;
id var4;
var patcnt;
run;

proc contents data = denomtr;
run;


proc sort data = quint;
by hms_id;
run;

proc transpose data = quint out=quinttr (drop = _LABEL_ _NAME_);
by hms_id;
id var4;
var cq;
run;

proc contents data = denomtr;
run;

data _null_;
 dsid=open("denomtr");
 check=varnum(dsid, "Grp2Cnt");
 call symput('checkval',check);
 if(check eq 0) then 
    call symput('vardef','HMS_ID $ 10 Grp1Cnt 8 Grp1 8');
 else 
    call symput('vardef','HMS_ID $ 10 Grp1Cnt 8 Grp2Cnt 8 Grp1 8 Grp2 8');
 rc= close(dsid);
 run ;

%put &checkval;
%put &vardef;

data rankeddenom;
length &vardef;
merge denomtr quinttr;
by hms_id;
run;

proc sort data = rankeddenom;
by descending Grp1Cnt ;
run;

proc export data = rankeddenom file='rankeddenom.txt' replace;
run;

*calc mean median n by rank;
*grp1 first;
proc sort data = rankeddenom;
by Grp1Cnt;
run;

proc means data = rankeddenom noprint nway;
by Grp1;
var Grp1Cnt;
where Grp1Cnt ne .;
output out=den1tab (drop = _TYPE_ _FREQ_) n=count median=median mean=mean min=min max=max;
run;

data den1tab;
set den1tab;
mean=round(mean,0.1);
run;

proc export data = den1tab file='den1summarycounts.txt' replace;
run;

*check if group 2 exists and do summary for that too;
%macro dogrp2();

 data _null_;
  dsid=open("rankeddenom");
  check=varnum(dsid, "Grp2");
  call symput("newcheckval",trim(left(check)));
  rc=close(dsid);
 run;

 data _null_;
  %let varcheck = 0;
  %if &newcheckval gt 0 %then
  %do;
    %let varcheck = 1;
  %end;
 run ;

 %put ***varcheck=&varcheck**;
 %put ***newcheckval=&newcheckval**;

 %if &varcheck eq 1 %then %do;

   proc sort data = rankeddenom;
   by Grp2Cnt;
   run;

   proc means data = rankeddenom noprint nway;
   by Grp2;
   var Grp2Cnt;
   where Grp2Cnt ne .;
   output out=den2tab (drop = _TYPE_ _FREQ_) n=count median=median mean=mean min=min max=max;
   run;

   data den2tab;
   set den2tab;
   mean=round(mean,0.1);
   run;
 
   proc export data = den2tab file='den2summarycounts.txt' replace;
   run;


 %end;

%mend;

%dogrp2();


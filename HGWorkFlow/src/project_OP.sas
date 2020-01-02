options /*linesize=256 nocenter*/ nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      input_op.sas
PURPOSE:           run workflow
PROGRAMMER:		   Jin Qian
CREATION DATE:	   06/9/2012
NOTES:			   
INPUT FILES:
output files:
****************************************************************************************** */


data inputs;
   infile "input.txt" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
   format Parameter	$50. ;
   format Value 	$200. ;
   informat Parameter	$50. ;
   informat Value 	$200. ;
   input Parameter $ Value $ ;
run;

data _null_;
	set inputs;

        if Parameter EQ 'COUNTTYPE' and VALUE = 'PATIENT' then call symput('counttype','CLAIM');
        else if Parameter EQ 'COUNTTYPE' and VALUE ~= 'PATIENT' then call symput('counttype',trim(left(compress(value))));

if Parameter eq 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
if Parameter eq 'BUCKET' then  call symput('Bucket', trim("'"||trim(value)||"'"));

if Parameter eq 'AGGREGATION_ID' then call symput('AGGRID', trim(left(compress(value))));
if Parameter eq 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
if Parameter eq 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
if Parameter eq 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
if Parameter eq 'AGGREGATION_TABLE' then call symput('AGGR', trim(left(compress(value))));
if Parameter eq 'CLAIM_PATIENT_TABLE' then call symput('AGGRP', trim(left(compress(value))));
if Parameter eq 'FXFILES' then call symput('FXFILES', trim("'"||left(compress(value))||"'"));
if Parameter eq 'AddRefDoc' then call symput('AddRefDoc', trim(left(compress(value))));

if Parameter eq 'BUCKET' then  call symput('Bucketn', trim(trim(value)));
if Parameter eq 'CODETYPE' then  call symput('CODETYPE', trim(trim(value)));

if Parameter eq 'INSTANCE' and value='pldwhdbr' then do;
	call symput('TOTAL_COUNT', 'TOTAL_COUNT');
	call symput('FRAC_COUNT', 'FRAC_COUNT');
	call symput('MDCR_COUNT', 'MDCR_COUNT');

end;

run;

data _null_;

if %unquote(%str(%'&INSTANCE%')) = 'pldwh2dbr' then do;

	if %unquote(%str(%'&COUNTTYPE%'))= 'CLAIM' then do;
			call symput('TOTAL_COUNT','CLAIM_CNT');
			call symput('FRAC_COUNT', 'CLAIM_FRAC_CNT');
			call symput('MDCR_COUNT','MDCR_CLAIM_CNT');
		end;

		else if %unquote(%str(%'&COUNTTYPE%'))= 'PROC' then do;
			call symput('TOTAL_COUNT', 'PROC_CNT');
			call symput('FRAC_COUNT', 'PROC_FRAC_CNT');
			call symput('MDCR_COUNT', 'MDCR_PROC_CNT');
		end;
end;

run;

%put 'CountType:' &CountType;
%put 'Vintage:' &Vintage;
%put 'Bucket:' &Bucket;
%put 'Bucketn:' &Bucketn;

%put 'AGGREGATION_ID:' &AGGRID;
%put 'USERNAME:' &USERNAME;
%put 'PASSWORD:' &PASSWORD;
%put 'INSTANCE:' &INSTANCE;
%put 'AGGREGATION_TABLE:' &AGGR;
%put 'CLAIM_PATIENT_TABLE:' &AGGRP;
%put 'FXFILES:' &FXFILES;
%put 'AddRefDoc:' &AddRefDoc;

%put 'TOTAL_COUNT:' &TOTAL_COUNT;
%put 'FRAC_COUNT:' &FRAC_COUNT;
%put 'MDCR_COUNT:' &MDCR_COUNT;
%put 'CODETYPE:'  &CODETYPE;

/*****assign libname***/
 
libname  fxfiles  &FXFILES;
libname claim '.'; 
/* effective Sept 2016, matrix dataset will be in current directory
 not in fxfiles */
libname matrloc '.';


/* Consolidate all external macros here*/



/* This part comes from opclaims.sas */
%macro piidcnt(src=, aggrname=);

proc sql;
	connect to oracle(user=&USERNAME password=&PASSWORD path=&INSTANCE);
	create table claim.&src._op
	as select * from connection to oracle
		(select
		h.doc_id as hms_piid,
		h.org_id as hms_poid,
		&total_count as &counttype._count,
		&frac_count as &counttype._fraction
		from
		&AGGR h
		where h.bucket_name=&Bucket
		and h.aggr_name=&aggrname
		and h.aggr_level='DOCORGLEVEL'
		and h.job_id=&AGGRID
		);
	disconnect from oracle ;
quit ;

%mend;

%piidcnt(src=WKUB, aggrname='WKUB_OP');
%piidcnt(src=WKMX, aggrname='WKMX_OP');
%piidcnt(src=CMS,  aggrname='CMS_OP');
%piidcnt(src=NY,   aggrname='NY_OP');
%piidcnt(src=FL,   aggrname='FL_OP');


data claim.WKUB_op_migs;
set claim.WKUB_op;
if hms_piid='MISSING' then hms_piid='MISSINGDOC';
run;
data claim.WKMX_op_migs;
set claim.WKMX_op;
if hms_piid='MISSING' then hms_piid='MISSINGDOC';
run;
data claim.CMS_op_migs;
set claim.CMS_op;
if hms_piid='MISSING' then hms_piid='MISSINGDOC';
run;
data claim.state_op_migs;
set claim.fl_op claim.ny_op ;
if hms_piid='MISSING' then hms_piid='MISSINGDOC';
run;
quit;

/* This part comes form factor.sas */
%macro payer(src=, aggrname=);

proc sql ;
	connect to oracle(user=&username password=&password path=&instance) ;
	create table claim.&src._payer
	as select * from connection to oracle
		(select    
		h.org_id as hms_poid ,					 
		&mdcr_count as med_counts,
		&total_count as all_counts 
		from &AGGR h
		where h.bucket_name=&Bucket
		and h.aggr_name=&aggrname
		and h.aggr_level='ORGLEVEL'
		and h.job_id=&AGGRID
		);
	disconnect from oracle ;
quit ;

%mend;

%payer(src=NY,   aggrname='NY_OP');
%payer(src=FL,   aggrname='FL_OP');
%payer(src=NJ,   aggrname='NJ_OP');
%payer(src=CA,   aggrname='CA_OP');
%payer(src=CMS,  aggrname='CMS_OP');
%payer(src=WKUB, aggrname='WKUB_OP');
%payer(src=WKMX, aggrname='WKMX_OP');

/* This part comes from opclaims_adj.sas - macros possibly used in oppred macro */
%macro poidcnt(src=, aggrname=);

proc sql ;
	connect to oracle(user=&username password=&password path=&instance) ;
	create table claim.&src._op_poid_migs
	as select * from connection to oracle
		(select
		h.org_id as hms_poid,
		h.&counttype._cnt as &counttype._count
		from
		&AGGR h
		where h.bucket_name=&Bucket
		and h.aggr_name=&aggrname
		and h.aggr_level='ORGLEVEL'
		and h.job_id=&AGGRID
		);
	disconnect from oracle ;
quit ;

%mend;
quit;

%macro actcount;

%poidcnt(src=FL, 	aggrname='FL_OP');
%poidcnt(src=NY, 	aggrname='NY_OP');
%poidcnt(src=CA,    aggrname='CA_OP');
%poidcnt(src=WKMX,  aggrname='WKMX_OP');
%poidcnt(src=WKUB,  aggrname='WKUB_OP');

%if %upcase(&CODETYPE) EQ CPM or %upcase(&CODETYPE) EQ AB %then %do;
data claim.state_op_poid_migs;
set claim.fl_op_poid_migs claim.ny_op_poid_migs ;
run;
%end;

%else %do;
data claim.state_op_poid_migs;
set claim.fl_op_poid_migs claim.ny_op_poid_migs claim.ca_op_poid_migs;
run;
%end;


/***change: 12/16/2016 do poid level first to determine which source to use at piidpoid level**/

proc sort data=claim.wkub_op_poid_migs out=ubop;
by hms_poid ;
run;

proc sort data=claim.wkmx_op_poid_migs out=mxop;
by hms_poid ;
run;

/****no MX claims for AdvisoryBoard***/;

%if %upcase(&CODETYPE)= AB %then %do;

data claim.wk_op_poid_migs;
length source $4.;
set ubop(rename=(&counttype._count=wkub_count)) ;
wk_count=wkub_count;
source='wkub';
run;

%end;
%else %do;

data claim.wk_op_poid_migs;
length source $4.;
merge ubop(rename=(&counttype._count=wkub_count)) mxop(rename=(&counttype._count=wk1500_count));
by hms_poid ;
if max(wkub_count, wk1500_count)=wkub_count then do;
	wk_count=wkub_count;
	source='wkub';
end;
else do;
	wk_count=wk1500_count;
	source='wkmx';
end;	
run;

%end;

proc sort data=claim.wk_op_poid_migs out=poid_source(keep=hms_poid source) nodupkey;
by hms_poid;
run;

proc sort data=claim.wkub_op_migs out=ubop;
by hms_poid hms_piid;
run;

proc sort data=claim.wkmx_op_migs out=mxop;
by hms_poid hms_piid;
run;

data wk_op_migs;
merge ubop(rename=(&counttype._count=wkub_count)) mxop(rename=(&counttype._count=wk1500_count)) ;
by hms_poid hms_piid;
run;

proc sort data=wk_op_migs;
by hms_poid;
run;

data claim.wk_op_migs(drop=source);
merge wk_op_migs poid_source;
by hms_poid;
if source='wkub' then do;
	if wkub_count^=. then wk_count=wkub_count;
	else wk_count=max(wk1500_count,wkub_count);
end;

else if source='wkmx' then do;
	if wk1500_count^=. then wk_count=wk1500_count;
	else wk_count=max(wk1500_count,wkub_count);
end;
run;
%mend;

/* This part comes from execute_nproj_op.sas - used in oppred macro when execute not used */
%macro nproj;

proc sort data=claim.wk_op_migs ;
by hms_poid ;
run;

proc sort data=claim.wk_op_migs out=wk_poid(keep=hms_poid ) nodupkey;
by hms_poid ;
run;


proc sort data=claim.state_op_migs out=state_op_migs(rename=(&counttype._count=state_count ));
by hms_poid;
run;

%if %upcase(&CODETYPE)= CPM %then %do;

data State_poidlist;
set matrloc.op_poids;
if vendor_code  in ('FLOP','NYOP');
run;

proc sort data=State_poidlist;
by hms_poid;	
run;

data state_op_migs;
merge state_op_migs(in=a) State_poidlist(in=b);
by hms_poid;	
run;
%end;

data state_op(where=(allpayer_count^=.));
merge state_op_migs(in=s where=(hms_piid^='MISSINGDOC')) wk_poid(in=w);
by hms_poid;

if s;
	allpayer_count=state_count;
drop state_count;
run;


proc sort data=state_op_migs out=state_poid(keep=hms_poid) nodupkey;
by hms_poid;
run;

data wk_op;
merge claim.wk_op_migs(in=w where=(hms_piid^='MISSINGDOC')) state_poid(in=s);
by hms_poid;
if w and not s ;
	allpayer_count=wk_count;

drop wk_count;
run;


data claims_piidpoid(where=(hms_piid^=''));
set state_op
	  wk_op;
run;


proc sql;
create table claims_piidpoid1
as
select a.hms_piid, a.hms_poid, a.allpayer_count as PractFacProjCount

from claims_piidpoid a 
where a.hms_piid is not null
;
quit;

/******poid******/

proc sort data=claim.wk_op_poid_migs;
by hms_poid ;
run;

proc sort data=claim.wk_op_poid_migs out=wk_poid(keep=hms_poid) nodupkey;
by hms_poid ;
run;

proc sort data=claim.state_op_poid_migs out=state_op_poid(rename=(&counttype._count=state_count ));
by hms_poid;
run;

%if %upcase(&CODETYPE)= CPM %then %do;

proc sort data=State_poidlist ;
by hms_poid;
run;

data state_op_poid;
merge state_op_poid State_poidlist ;
by hms_poid;
run;
%end;

proc sort data=state_op_poid;
by hms_poid;
run;

/***change: exclude state poid that doesn't have piidpoid count**/
data state_op_poid;
merge state_op_poid(in=a) state_poid(in=b);
by hms_poid;
if a and b;
run;

proc sort data=state_op_poid;
by hms_poid;
run;

data state_op(where=(allpayer_count^=.));
merge state_op_poid(in=s) wk_poid(in=w);
by hms_poid;
if s ;
allpayer_count=state_count;
drop state_count;
run;

proc sort data=state_op_poid out=state_poid(keep=hms_poid) nodupkey;
by hms_poid ;
run;


data wk_op;
merge claim.wk_op_poid_migs(in=w ) state_poid(in=s);
by hms_poid;
if w and not s;

allpayer_count=wk_count;
	drop wk_count ;

run;


data claims_poid(rename=(allpayer_count=FacProjCount));
set state_op
	  wk_op;
run;


/***merge data sets***/
/****change: datamatrix excluding wk1500 unique hospitals so can not use matrix ***/

proc sort data=claims_poid ;
by hms_poid ;
run;

proc sort data=claims_piidpoid1 ;
by hms_poid ;
run;

%if %upcase(&CODETYPE)= AB %then %do;
proc sort data=matrloc.op_datamatrix out=poid(keep=hms_poid) nodupkey;
/* MODIFICATION 8.14.2018: Removed vintage from sas dataset */
by hms_poid;
run;

data claims_piidpoid1;
merge claims_piidpoid1(in=a) poid(in=b);
by hms_poid;
if a and b;

run;

/*****poid level***/

data claims_poid;
merge claims_poid(in=a) poid(in=b);
by hms_poid;
if a and b;

run;

proc sort data=claims_piidpoid1 ;
by hms_poid ;
run;

proc sort data=claims_poid ;
by hms_poid ;
run;

%end;

proc means data= claims_piidpoid1 noprint nway sum;
class hms_piid;
var PractFacProjCount ;
output out=claims_piid (drop=_type_ _freq_) sum=PractNatlProjCount;
run;

proc sort data=claims_piid ;
by hms_piid ;
run;


data claim_delvry;
merge claims_piidpoid1(in=a) claims_poid(in=b);
by hms_poid;
/* MODIFICATION 9.30.2019: remove MISSING poids from this step to get them out of specific scenarios */
where HMS_POID ~= 'MISSING';
run;

proc sort data=claim_delvry ;
by hms_piid ;
run;


data claim.claim_delvry;
length Bucket $50.;

merge claim_delvry(in=a) claims_piid(in=b);
by hms_piid;

if (hms_piid^='' and PractNatlProjCount in (.,0, -1) and PractFacProjCount not in (.,0, -1)) or (hms_piid^='' and PractFacProjCount in (.,0, -1))
	or (hms_poid^='' and FacProjCount in (.,0, -1)) then delete;

Bucket="&Bucketn";
run;


data claim.claim_delvry_reset;
set claim.claim_delvry;

if PractFacProjCount<=10 and PractFacProjCount^=. then PractFacProjCount=5.5;
if FacProjCount<=10 and FacProjCount^=. then FacProjCount=5.5;
if PractNatlProjCount<=10 and PractNatlProjCount^=. then PractNatlProjCount=5.5;

run;


%if %upcase(&CODETYPE)= AB %then %do;
proc sql;
create table output
as
select a.Bucket, a.hms_piid as HMS_PIID, hms_poid as HMS_POID, PractFacProjCount , PractNatlProjCount,  FacProjCount

from claim.claim_delvry_reset a
;
quit;


proc sql;
create table output2
as
select a.Bucket, a.hms_piid as HMS_PIID, hms_poid as HMS_POID, PractFacProjCount ,  PractNatlProjCount, FacProjCount

from claim.claim_delvry a
;
quit;
%end;

%else %do;

proc sql;
create table output
as
select a.Bucket, a.hms_piid, a.hms_poid, PractFacProjCount ,  PractNatlProjCount, FacProjCount

from claim.claim_delvry_reset a,

	fxfiles.Orginfo_&vintage b 

where a.hms_poid=b.hms_poid 
	and b.org_name is not null
	and b.address_line1 is not null
;
quit;

proc sql;
create table output2
as
select a.Bucket, a.hms_piid, a.hms_poid, PractFacProjCount , PractNatlProjCount,  FacProjCount

from claim.claim_delvry a,

	fxfiles.Orginfo_&vintage b 

where a.hms_poid=b.hms_poid 
	and b.org_name is not null
	and b.address_line1 is not null
;
quit;
%end;
            
proc export data=output
outfile='hospital_projections.txt'
dbms=tab replace;
run;

proc export data=output2
outfile='hospital_projections_nostar.txt'
dbms=tab replace;
run;

%mend;

/* This part comes from execute_proj_op.sas - used in oppred macro when nproj not used */
%macro excute;

proc sort data= claim.estimated_factor ;
by hms_poid;
run;

proc means data=claim.estimated_factor median noprint nway ;
var factorhat;
output out=med_factor median=;
run;


data _null_;
set med_factor;
call symput('factorhat', factorhat);
run;

%put **********median projection factor***********: &factorhat;

proc sort data=claim.cms_payer;
by hms_poid;
run;

/*****project on poid level***/
data proj_cms;
	merge claim.cms_payer(in=a )  claim.estimated_factor(in=b keep=hms_poid factorhat);
	by hms_poid;
	if a ;

	if factorhat=. then do;
		proj_cms=round(med_counts*&factorhat, 1.0);
	end;

	else do;
		proj_cms=round(med_counts*factorhat, 1.0);
	end;

run;

proc sort data=proj_cms out=proj_cms(keep=hms_poid proj_cms );
by hms_poid ;
run;


proc sort data=claim.wkub_payer ;
by hms_poid ;
run;



/****change: not include wkmx at facility level****/;

%if %upcase(&CODETYPE) EQ CPM or %upcase(&CODETYPE) EQ AB %then %do;
data claim.state_payer;
set  claim.ny_payer claim.fl_payer  ;
run;

proc sort data=claim.state_payer ;
by hms_poid ;
run;
%end;

%else %do;
data claim.state_payer;
set  claim.ny_payer claim.fl_payer  claim.ca_payer;
run;

proc sort data=claim.state_payer ;
by hms_poid ;
run;
%end;

data claim.facility_counts_output(keep=hms_poid claim_dlvry);
merge proj_cms
	  claim.wkub_payer(keep=hms_poid all_counts rename=(all_counts=wk_count ))
	  claim.state_payer(keep=hms_poid all_counts rename=(all_counts=state_count ));
	
by hms_poid ;

	claim_dlvry=max(proj_cms, state_count, wk_count);
run;


proc sort data=claim.facility_counts_output out=facility_counts_output;
by hms_poid;
run;

proc sort data=claim.wkmx_payer ;
by hms_poid;
run;


data claim_dlvry_poid(keep=hms_poid claim_dlvry);
merge claim.wkmx_payer(in=a ) facility_counts_output(in=b);
by hms_poid;
if a and not b then claim_dlvry=all_counts;
run;


proc sort data=claim.state_op_migs(where=(hms_piid^='MISSINGDOC')) out= state_op_migs;
by hms_poid hms_piid;
run;

proc sort data=claim.cms_op_migs(where=(hms_piid^='MISSINGDOC')) out= cms_op_migs;
by hms_poid hms_piid;
run;

proc sort data=claim.wkub_op_migs(where=(hms_piid^='MISSINGDOC')) out= wkub_op_migs ;
by hms_poid hms_piid ;
run;

proc sort data=claim.wkmx_op_migs(where=(hms_piid^='MISSINGDOC')) out= wkmx_op_migs ;
by hms_poid hms_piid ;
run;

proc sort data=claim.wkub_op_migs(where=(hms_piid='MISSINGDOC') ) 
	out=wkub_piid_miss(drop=hms_piid rename=(&CountType._count=wkub_count_miss ));
by hms_poid  ;
run;

proc sort data=claim.state_op_migs(where=(hms_piid='MISSINGDOC')) 
out= state_piid_miss(drop=hms_piid rename=(&CountType._count=state_count_miss ));
by hms_poid ;
run;

proc sort data=claim.cms_op_migs(where=(hms_piid='MISSINGDOC') ) 
	out=cms_piid_miss(drop=hms_piid rename=(&CountType._count=cms_miss ));
by hms_poid  ;
run;

data allpayer_miss(keep=hms_poid allpayer_miss) ;
merge state_piid_miss wkub_piid_miss ;
by hms_poid;

if state_count_miss=. then state_count_miss=0;
if wkub_count_miss=. then wkub_count_miss=0;

  allpayer_miss=max(state_count_miss, wkub_count_miss);
run;

proc sort data=allpayer_miss;
by hms_poid;
run;

data allpayer_piidatpoid;
merge wkub_op_migs(where=(hms_poid^='MISSING') rename=(&counttype._count=wkub_count &counttype._fraction=wkub_fraction ))
	  state_op_migs(where=(hms_poid^='MISSING') rename=(&counttype._count=state_count &counttype._fraction=state_fraction))
	  wkmx_op_migs(where=(hms_poid^='MISSING') rename=(&counttype._count=wkmx_count &counttype._fraction=wkmx_fraction ));
	
by hms_poid hms_piid ;
run;

proc sort data=allpayer_piidatpoid;
by hms_poid ;
run;

proc sort data=claim_dlvry_poid;
by hms_poid ;
run;

/*** no need set wkmx to missing 
if wkmx>claim_delvry when codetype=CPM***/

%if %upcase(&CODETYPE) EQ CPM %then %do;

data allpayer_piidatpoid1;
merge claim_dlvry_poid
	  allpayer_piidatpoid;
by hms_poid ;

if claim_dlvry=. then claim_dlvry=0;	
run;
%end;

%else %do;

data allpayer_piidatpoid1;
merge claim_dlvry_poid
	  allpayer_piidatpoid;
by hms_poid ;

if claim_dlvry=. then claim_dlvry=0;
	
if wkmx_count> claim_dlvry then do;
	wkmx_count=.;
	wkmx_fraction=.;
end;
run;
%end;

proc sort data=allpayer_piidatpoid1 ;
by hms_poid;
run;

data allpayer_piidatpoid2(drop= claim_dlvry);
set allpayer_piidatpoid1(in=a) ;

if max(state_count,  wkub_count,  wkmx_count)=state_count then do;
			allpayer_count=state_count ;
			allpayer_fraction=state_fraction;
		end;

	    else if max(state_count,  wkub_count,  wkmx_count)=wkub_count then do;
			allpayer_count=wkub_count ;
			allpayer_fraction=wkub_fraction;
		end;

		else if max(state_count, wkub_count, wkmx_count)=wkmx_count then do;
			allpayer_count=wkmx_count ;
			allpayer_fraction=wkmx_fraction;
		end;

	    else if max(state_count, wkub_count, wkmx_count, 0)=0 then do;
			allpayer_count=0 ;
			allpayer_fraction=0;
		end;
run;


proc sort data=allpayer_piidatpoid2;
by hms_poid hms_piid;
run;

data claim.allpayer_count;
merge cms_op_migs(where=(hms_poid^='') rename=(&counttype._count=pxdx_count &counttype._fraction=pxdx_fraction))
	  allpayer_piidatpoid2;
by hms_poid hms_piid;

		/****no cms valid flag*****/

		cms_count=pxdx_count;
		cms_fraction=pxdx_fraction;

if allpayer_count < pxdx_count then do;
	allpayer_count=0;
	allpayer_fraction=0;
end;


else if allpayer_count >= pxdx_count then do;
	cms_count=0;
	cms_fraction=0;
end;

run;

proc sql;
create table allpayer_count
as
select a.*

from claim.allpayer_count a 

where hms_piid is not null
;
quit;

proc means data= allpayer_count noprint nway sum;
var allpayer_count allpayer_fraction cms_count cms_fraction pxdx_count pxdx_fraction ;
output out=total_counts (drop=_type_ _freq_) sum=;
run;


data _null_;
set total_counts;

call symput('allpayer', allpayer_count);
call symput('cms', cms_count);
run;

%put **********Total number of allpayer counts**********: &allpayer;
%put **********Total number of cms counts**********: &cms;


proc means data= allpayer_count noprint nway sum;
class hms_poid;
var allpayer_count allpayer_fraction cms_count cms_fraction pxdx_count pxdx_fraction ;
output out=claim.poid_sum (drop=_type_ _freq_) sum=;
run;

proc sort data=claim.poid_sum ;
by hms_poid;
run;

proc sort data=claim.facility_counts_output ;
by hms_poid;
run;



data estimated_allpayer;
merge   claim.facility_counts_output(in=a) claim.poid_sum(in=b);
by hms_poid;

if not a and b then do;
claim_dlvry=allpayer_count;
end;

run;

proc sort data=estimated_allpayer;
by hms_poid;
run;


data estimated_allpayer_count;
merge estimated_allpayer 	  allpayer_miss   cms_piid_miss(where=(hms_poid^='') keep=hms_poid cms_miss);
by hms_poid;

run;

/****calculate 99 percentile for poids****/

/* Let cutoff equal something arbitrarily high in case of empty set */
%let cutoff = 10000;

proc means data=estimated_allpayer_count(where=(claim_dlvry^=0))  noprint nway p99;
var claim_dlvry;
output out=poid_p99 (drop=_type_ _freq_) p99=;
run;

data _null_;
set poid_p99;

cutoff=round(0.25*claim_dlvry, 1.0);

call symput('cutoff', cutoff);

run;

%put cutoff: &cutoff;

/****increase claim_dlvry to allpayer_count for negative factor***/

data estimated_allpayer_count1 ;
length source $ 3;
set estimated_allpayer_count;

	if claim_dlvry=. then claim_dlvry=0;
	if allpayer_miss=. then allpayer_miss=0;
	if cms_miss=. then cms_miss=0;
	if allpayer_fraction=. then allpayer_fraction=0;

	if claim_dlvry=. then claim_dlvry=0;

		claim_dlvry1=claim_dlvry;

		if claim_dlvry < (allpayer_fraction+allpayer_miss) then do;

			if (allpayer_fraction+allpayer_miss)<= max(claim_dlvry+&cutoff, 1.25*claim_dlvry) then do;
			
				claim_dlvry=round(allpayer_fraction+allpayer_miss, 1.0);
			end;
			else do;
				if &error. ~= 1 then source='cms';
				else source='';
			end;
		end;
run;


data _null_;
set claim.actual_factor_op;

call symput('lpfmax', pfmax);
run;

%put ************lpfmax =&lpfmax;



/****adjust for factor<1****/

data estimated_allpayer_count2;
set estimated_allpayer_count1(where=(source^='cms'));

	if allpayer_miss=. then allpayer_miss=0;
	if cms_miss=. then cms_miss=0;
	if allpayer_fraction=. then allpayer_fraction=0;
	if cms_fraction=. then cms_fraction=0;

	diff=claim_dlvry-round(allpayer_fraction+allpayer_miss, 1.0);

		if diff>=0 and  diff < (cms_fraction+cms_miss) then do;

			diff2=diff-(cms_fraction+cms_miss);

				if claim_dlvry+abs(diff2) <= max(claim_dlvry+&cutoff, 1.25*claim_dlvry) then do;

					claim_dlvry=round(claim_dlvry+abs(diff2), 1.0);
				end;
				
			else do;
				if &error. ~= 1 then source='cms';
				else source='';
				claim_dlvry=claim_dlvry1;
			end;
		end;
	
		allpayer_fraction1=round(allpayer_fraction+allpayer_miss, 1.0);

		if (cms_fraction+cms_miss)^=0 and claim_dlvry>allpayer_fraction1 then  

			factor=round((claim_dlvry-allpayer_fraction1)/(cms_fraction+cms_miss), 0.0001);
	
		else if (cms_fraction+cms_miss)^=0 and claim_dlvry=allpayer_fraction1 then factor=1;
		else if (cms_fraction+cms_miss)^=0 and claim_dlvry<allpayer_fraction1 then factor=1;
		else if (cms_fraction+cms_miss)=0  then factor=0;


run;


/****any poid with source 'cms' use pxdx data to project without any all payer***/

proc sort data=estimated_allpayer_count2(where=(source^='cms')) out=factor(keep=hms_poid factor claim_dlvry);
by hms_poid;
run;

proc sort data=claim.actual_factor_op;
by hms_poid;
run;


data claim.factor_merged;
merge claim.actual_factor_op(in=a keep=hms_poid mypf pfmax) factor(in=b);
by hms_poid;

if factor>&lpfmax then do;

	lmaxpf=max(mypf,&lpfmax);

		if factor>lmaxpf then factor=lmaxpf;
end;

run;

proc sort data=claim.factor_merged;
by hms_poid;
run;

proc sort data=allpayer_count ;
by hms_poid;
run;


data cms_only_poid(keep=hms_poid  pxdx_fraction claim_dlvry factor)/* rename=(pxdx_count=poid_count) )*/;

set estimated_allpayer_count1(where=(source='cms') )
	estimated_allpayer_count2(where=(source='cms') );

if claim_dlvry < pxdx_fraction then do;
		
			claim_dlvry=round(pxdx_fraction, 1.0);
	
		factor=1;
end;

else do;
	factor=round(claim_dlvry/(pxdx_fraction+cms_miss), 0.0001);

	if factor>&lpfmax then factor=&lpfmax;
end;

run;

/******project on poids not cms only poid ***/
proc sort data= cms_only_poid  nodupkey;
by hms_poid;
run;

proc sort data=allpayer_count ;
by hms_poid;
run;

data allpayer_count1;
merge allpayer_count(in=a) cms_only_poid(in=b keep=hms_poid);
by hms_poid;
if a and not b;
run;

proc sort data=allpayer_count1;
by hms_poid;
run;

data claim_delvry;
merge allpayer_count1(in=a) claim.factor_merged(in=b);
by hms_poid;
if  a and b;

if allpayer_count=0 and cms_count=0 then do;
	projected_counts=0;
end;

else if allpayer_count^=0 then do;
	projected_counts=round(allpayer_count, 1.0);
end;

else if cms_fraction^=0 then do;			
	
	projected_counts=round(pxdx_count*factor, 1.0);
	/*proj=1;*/
end;

run;



/****project cms only hospitals***/
/***divide pxdx count **/

data claim_delvry_cms_only;
merge allpayer_count(in=a ) cms_only_poid(in=b where=(factor^=. ) keep=hms_poid factor claim_dlvry);
by hms_poid;

if a and b;

if pxdx_fraction=. then pxdx_fraction=0;
if pxdx_count=. then pxdx_count=0;

	projected_counts=round(pxdx_count*factor, 1.0);
/*	proj=1;*/
run;


data claim_delvry1(keep=hms_poid hms_piid projected_counts proj );
set claim_delvry claim_delvry_cms_only;
run;

/*
proc sort data=claim_delvry1(where=(proj=1)) out=proj_piids(keep=hms_piid) nodupkey;
by hms_piid;
run;
*/

/****piid count**/

proc means data=claim_delvry1 noprint nway sum;
class hms_piid;
var projected_counts;
output out=piid_count(drop=_type_ _freq_) sum=PractNatlProjCount;
run;


/**poid count consist two portion***/

proc sort data=claim_delvry out=poid_count(keep=hms_poid claim_dlvry rename=(claim_dlvry=poid_count)) ;
by hms_poid descending claim_dlvry  ;
run;

data poid_count;
set poid_count;
by hms_poid;

if first.hms_poid=1;
run;

proc sort data=claim_delvry_cms_only out=poid_count_cms(keep=hms_poid claim_dlvry rename=(claim_dlvry=poid_count));
by hms_poid descending claim_dlvry  ;
run;


data poid_count_cms;
set poid_count_cms;
by hms_poid;

if first.hms_poid=1;
run;

data poid_count;
set poid_count poid_count_cms;	
run;

proc sort data=poid_count (where=(poid_count>0)) out=claim.proj_facility_count nodupkey;
by hms_poid ;
run;


/***merge data sets***/

proc sort data=claim_delvry1 nodupkey;
by   hms_poid hms_piid;
run;

data claim.claim_delvry(rename=(projected_counts=PractFacProjCount poid_count=FacProjCount));
merge claim_delvry1(in=a) claim.proj_facility_count(in=b);
by hms_poid;
if a and b ;
run;

proc sort data=claim.claim_delvry out=claim_delvry ;
by hms_poid;
run;

proc sort data=claim.facility_counts_output out=facility_counts_output nodupkey;
by hms_poid;
run;


proc sql ;
	   connect to oracle(user=&USERNAME password=&PASSWORD path=&INSTANCE) ;
    	  create table wkmx_poids
              as
                select *
                   from connection to oracle
                     (select distinct  h.org_id as hms_poid 
                        
                      	from &AGGR h
                                                where h.aggr_name='WKMX_OP'
								and h.aggr_level='ORGLEVEL'
								and h.job_id=&AGGRID					
							                       );
                      disconnect from oracle ;
             quit ;
          %put &sqlxmsg ;

proc sql;
create table claim.wkmx_poids
as
select a.*
from wkmx_poids a,
	fxfiles.Orginfo_&Vintage b 
where a.hms_poid=b.hms_poid 
	
;
quit;


data poid1;
set claim.wkmx_poids matrloc.op_datamatrix;
/* MODIFICATION 8.14.2018: Removed vintage from sas dataset */
run;

proc sort data=poid1 out=poid(keep=hms_poid) nodupkey;
by hms_poid;
run;

data facility_counts_output;
merge facility_counts_output(in=a) poid(in=b);
by hms_poid;
if a and b;
run;

proc sort data=facility_counts_output nodupkey;
by hms_poid;
run;



data claim_delvry;
merge claim_delvry(in=a) poid(in=b);
by hms_poid;
if a and b;
run;

proc sort data=claim_delvry;
by hms_poid;
run;


data claim.claim_delvry(drop=claim_dlvry);
merge claim_delvry(in=a) facility_counts_output(in=b);
by hms_poid;

if not a and b then do;
	FacProjCount= claim_dlvry;
end;

run;


proc sort data=claim.claim_delvry;
by hms_piid;
run;


proc sort data=piid_count nodupkey;
by hms_piid;
run;

data claim.claim_delvry ;
merge claim.claim_delvry(in=a  keep=hms_poid hms_piid PractFacProjCount FacProjCount) 
	  piid_count(in=b where=(PractNatlProjCount>0) );
by hms_piid;
run;

/******randomly adjust projected counts base on 10th highest all payer counts***/

proc sql;
create table allpayer_piidatpoid3
as
select a.*

from allpayer_piidatpoid2 a 

where a.hms_piid is not null 
;
quit;

proc means data=allpayer_piidatpoid3(where=(hms_piid^='MISSINGDOC')) noprint nway sum;
class hms_piid;
var allpayer_count;
output out=allpayer_piid(drop=_type_ _freq_) sum=piid_total;
run;

proc sort data=allpayer_piid;
by descending piid_total;
run;



proc sql;
create table cms_piidatpoid2
as
select a.*

from cms_op_migs a 

where a.hms_piid is not null 
;
quit;

proc means data=cms_piidatpoid2(where=(hms_piid^='MISSINGDOC')) noprint nway sum;
class hms_piid;
var &counttype._count;
output out=cms_piid(drop=_type_ _freq_) sum=piid_total;
run;

proc sort data=cms_piid;
by descending piid_total;
run;


/******if the highest all payer count less than the highest cms count, no capping needed***/

data _null_;
set allpayer_piid;
if _n_=1;
call symput('allcnt', piid_total);

run;


data _null_;
set cms_piid;
if _n_=1;
call symput('cmscnt', piid_total);

run;


%put 'Highest AllCnt:' &allcnt;
%put 'Highest CMSCnt:' &cmscnt;

data _null_;
if &cmscnt<&allcnt then do;
	call symput('phys_error', '1') ;
end;

else do ;
	call symput('phys_error', '0') ;
end ;
run;

%put 'phys_error:' &phys_error;

%if %upcase(&CODETYPE)= AB and &phys_error.=0 %then %do;

%put *****no capping*****;
 
data claim_delvry1;
set claim.claim_delvry;

if (hms_piid^='' and PractNatlProjCount in (.,0) and PractFacProjCount not in (.,0)) or (hms_piid^='' and PractFacProjCount in (.,0))
	or (hms_poid^='' and FacProjCount in (.,0)) then delete;

run;

%end;

%else %do;

%put *****capping*****;

option obs=10;

data claim.top10;
set allpayer_piid end=num;
if num then call symput('maxnum', piid_total);
run;

%put *********maxnum: &maxnum***********;

option obs=max;


proc sort data=claim.claim_delvry;
by hms_piid;
run;


data claim_delvry_adj;
set claim.claim_delvry(in=a) ;

if PractNatlProjCount>&maxnum ;

run;


data claim_delvry;
set claim.claim_delvry(in=a) ;

if  PractNatlProjCount<=&maxnum ;

run;


proc sort data=claim_delvry_adj out=adj_piid_count (keep=hms_piid PractNatlProjCount) nodupkey;
by hms_piid;
run;

/****only cap the piids having projected counts***/


data claim_delvry_cap;
set adj_piid_count;

x=ranuni(1);

 if x< 1/11 then cap=round(0.90*&maxnum, 1.0);
else if x< 2/11 then cap=round(0.91*&maxnum, 1.0);
else if x< 3/11 then cap=round(0.92*&maxnum, 1.0);
else if x< 4/11 then cap=round(0.93*&maxnum, 1.0);
else if x< 5/11 then cap=round(0.94*&maxnum, 1.0);
else if x< 6/11 then cap=round(0.95*&maxnum, 1.0);
else if x< 7/11 then cap=round(0.96*&maxnum, 1.0);
else if x< 8/11 then cap=round(0.97*&maxnum, 1.0);
else if x< 9/11 then cap=round(0.98*&maxnum, 1.0);
else if x< 10/11 then cap=round(0.99*&maxnum, 1.0);
else if x< 1 then cap=&maxnum;
output;

run;


proc sort data=claim_delvry_adj;
by hms_piid ;
run;


proc sort data=claim_delvry_cap;
by hms_piid ;
run;

data claim_delvry_adj1(keep=hms_piid hms_poid cap PractFacProjCount1 FacProjCount 
	rename=(PractFacProjCount1=PractFacProjCount cap=PractNatlProjCount));
merge claim_delvry_adj(keep=hms_piid hms_poid PractFacProjCount  FacProjCount PractNatlProjCount) claim_delvry_cap;
by hms_piid;

	PractFacProjCount1=round(PractFacProjCount*cap/PractNatlProjCount, 1.0);

run;

data claim_delvry1;
set claim_delvry(keep=hms_piid hms_poid PractNatlProjCount PractFacProjCount FacProjCount)  claim_delvry_adj1;

if (hms_piid^='' and PractNatlProjCount in (.,0) and PractFacProjCount not in (.,0)) or (hms_piid^='' and PractFacProjCount in (.,0))
	or (hms_poid^='' and FacProjCount in (.,0)) then delete;

run;


%end;


proc sort data=claim_delvry1;
by hms_poid;
run;

proc sort data=facility_counts_output;
by hms_poid;
run;

data claim.claim_delvry(drop=claim_dlvry);
length Bucket $50.;
merge claim_delvry1(in=a) facility_counts_output(in=b keep=hms_poid claim_dlvry );
by hms_poid;

if not a and b then do;
	FacProjCount= claim_dlvry;
end;
Bucket="&Bucketn";

run;

data claim.claim_delvry_reset;
set claim.claim_delvry;

	if PractFacProjCount^=. then do;
		if PractFacProjCount<=10 then PractFacProjCount=5.5;
	end;

	if PractNatlProjCount^=. then do;
		if PractNatlProjCount<=10 then PractNatlProjCount=5.5;
	end;

	if FacProjCount^=. then do;
		if FacProjCount<=10 then FacProjCount=5.5;
	end;
run;

proc sql;
create table output
as
select a.Bucket, a.hms_piid as HMS_PIID, hms_poid as HMS_POID, PractFacProjCount ,  PractNatlProjCount, FacProjCount

from claim.claim_delvry_reset a
;
quit;

proc export data=output
outfile='hospital_projections.txt'
dbms=tab replace;
run;


proc sql;
create table output2
as
select a.Bucket, a.hms_piid as HMS_PIID, hms_poid as HMS_POID, PractFacProjCount , PractNatlProjCount,  FacProjCount

from claim.claim_delvry a
;
quit;

proc export data=output2
outfile='hospital_projections_nostar.txt'
dbms=tab replace;
run;

%mend;












/* This part comes from oppred.sas */
*%macro oppred;

/***change: exclude 'MISSING' poids in current aggregation pull 11/11/2016***/ ;
proc sort data=claim.wkub_payer(where=(hms_poid^='MISSING')) out=wk_op;
by hms_poid;
run;

/* Only include CA claims for CPM and AB jobs */
%macro state_payer;

%if %upcase(&CODETYPE) EQ CPM or %upcase(&CODETYPE) EQ AB %then %do;
data claim.state_payer;
set claim.nj_payer claim.ny_payer claim.fl_payer ;
run;
%end;
%else %do;
data claim.state_payer;
set claim.nj_payer claim.ny_payer claim.fl_payer claim.ca_payer;
run;
%end;

%mend;

%state_payer;

proc sort data=claim.state_payer(where=(hms_poid^='MISSING')) out=state_op;
by hms_poid;
run;

data factor_op;
merge wk_op(in=w) state_op(in=s);
by hms_poid;
if s or (not s and w);

medcapture=round(med_counts/all_counts,0.0001);

if medcapture gt 0 and medcapture < 1 then do;
	medcaptrans=log(medcapture/(1-medcapture));
end;
else do;
	medcaptrans=.;
end;

run;

%put 'CODETYPE:'  &CODETYPE;
quit;

/* Initialize error macro variable */
%let error=0;

/***calculate overall factor by sum of all claims and medicare claims***/;
proc means data=factor_op noprint nway sum;
var med_counts all_counts;
output out=total_claims sum=;
run;

/***calculate overall factor by sum of all claims and medicare claims***/;
proc means data=factor_op noprint nway sum;
var med_counts all_counts;
output out=total_claims sum=;
run;
/***if overall factor is greater than 20 for AB, then pull actual data, no projection***/;
data _null_;
set total_claims;
factor=all_counts/med_counts;
call symput('overall_factor', factor);
run;

/* HOT FIX: if dataset is empty, use -1 to bypass errors */
proc sql;
create table total_claim_count as select count(*) as records from total_claims;
quit;
data _null_;
set total_claim_count;
if records = 0 then do;
	call symput('overall_factor', '-1');
	call symput('error', '-1');
end;
run;

data overall_factor;
set total_claim_count;
overall_factor = &overall_factor.;
keep overall_factor;
run;
proc export data=overall_factor outfile= 'overall_factor.txt';
run;

%put 'error': &error;
%put *****overall_factor: &overall_factor******;
/* Apply AB rule to all jobs now, make it 10 instead of 20 */
data _null_;

if &error ~= -1 then do;
	if &overall_factor > 10 then call symput('error', '1') ;
end;

run;

%put 'error': &error;

/***check if the dataset is empty after sorting without missing medcapttrans***/;
proc sort data=factor_op(where=(medcaptrans^=.)) out=test;
by hms_poid;
run;

data _null_;
		
*if &error = 0 then do;
if 0 then set test nobs=nobs;
call symput('_num_obs', trim(left(put(nobs,8.)))) ;
if nobs eq 0 then do ;
	put '***** input data set is empty *****' ;
	call symput('error', '2') ;
end ;
else do ;
	call symput('error', "&error") ;
end ;
stop;
*end ;

run;

%put obs:&_num_obs;
%put 'error': &error;

proc sort data=factor_op;
by hms_poid;
run;

proc sort data=claim.cms_payer;
by hms_poid;
run;

/****claim.pxdx_medclaims to compare pxdx medicare with medicare claims from allpayer data***/
data claim.factor_op_adj;
merge claim.cms_payer(in=a keep=hms_poid med_counts rename=(med_counts=pxdx_counts) )  factor_op(in=b);
by hms_poid;
if b;
if (a and b) and  med_counts^=0 then do;
	if pxdx_counts/med_counts> 2 then delete;
end;
run;

/***check if dataset is empty after delete any obs**/
data _null_;
if &error in (1,0) then do;
	if 0 then set claim.factor_op_adj nobs=nobs;
	call symput('_num_obs', trim(left(put(nobs,8.)))) ;
	if nobs eq 0 then do ;
		put '***** input data set is empty *****' ;
		call symput('error', '3') ;
	end ;
	else do ;
		call symput('error', "&error.") ;
	end ;
end;
	stop;
run;
%put 'error': &error;

proc means data=claim.factor_op_adj nway q1 q3;
var medcaptrans;
output out=claim.quartile_op q1=q1 q3=q3;
run;

data _null_;
set claim.quartile_op;
call symput ('q1', q1);
call symput ('q3', q3);
call symput ('freq', _freq_);
run;

%put 'q1:' &q1;
%put 'q3:' &q3;
%put 'freq:' &freq;

/* HOT FIX: if dataset is empty, use -1 to bypass errors */
proc sql;
create table total_claim_count as select count(*) as records from claim.quartile_op;
quit;
data _null_;
set total_claim_count;
if records = 0 then do;
	call symput('q1', '-1');
	call symput('q3', '-1');
	call symput('error', '-1');
end;
run;

%put 'error': &error;

data _null_;
if &error in (0,1) then do;
if &q1=&q3 then call symput('error', '4') ;
end;
run;
%put 'error': &error;

data claim.actual_factor_op;
set claim.factor_op_adj ;

low1=&q1-1.5*(&q3-&q1);
high1=&q3 +1.5*(&q3-&q1);
low=1/(1+exp(-low1));
high=1/(1+exp(-high1));

if  medcapture < low or  medcapture > high then delete;

mypf=1/medcapture;
pfmax=1/low;
pfmin=1/high;

run;


/****check obs again for model***/
/***if the number of obs less than 20 then use intercept only model***/

data _null_;
if &error in(0,1) then do;
	if 0 then set claim.actual_factor_op nobs=nobs;
	call symput('_num_obs', trim(left(put(nobs,8.)))) ;
	if nobs eq 0 then do ;
		put '***** input data set is empty *****' ;
		call symput('error', '5') ;
	end ;
	else do ;
		call symput('error', "&error.") ;
	end ;
end;
stop;
run;

%put 'error': &error;

/* Initialize mobs */
%let mobs=0;
data _null_;
set claim.actual_factor_op end=last;	

call symput('lpfmax', pfmax);
call symput('lpfmin', pfmin);

if last then call symput('mobs', _n_);
run;

data _null_;
if &error in (0,1) then do;
	if &mobs < 11 then do;
		if &overall_factor > 20 then call symput('error', '7') ; /* Handles rare cases where datasets are very small, yet we shouldn't project */
		else call symput('error', '6') ;
	end;
	else do ;
		call symput('error', "&error.") ;
	end;
end;
run;

%put obs:&mobs;
%put 'error': &error;

%put max allowable projection factor = &lpfmax;
%put highpf &lpfmax;
%put lowpf &lpfmin;

/* MODIFICATION 10.1.2018: Looking for PROJECTOP variable and adding new error code here */
data _null_;
set inputs;
if Parameter = 'PROJECTOP' then do;
	if VALUE = 'N' then call symput('error', '8');
end;
run;

%put 'error': &error;
%put 'final_error': &error;

%macro error_choose;

%if &error = 2 | &error = 3 | &error = 4 | &error = 5 | &error = 7 | &error = 8 %then %do;

	%actcount;
	%nproj;

%end;

%else %if &error = -1 %then %do;

	%actcount;
	%nproj;

%end;

%else %if &error=0 %then %do;

proc sort data=claim.actual_factor_op;
by hms_poid;
run;

proc sort data=matrloc.op_datamatrix out=demo_poid;
/* MODIFICATION 8.14.2018: Removed vintage from sas dataset */
by hms_poid;
run;

data _null_;
set demo_poid end=eof;

if eof then do;
	call symput('obs',_n_);
end;
run;

data claim.model_op;
merge claim.actual_factor_op demo_poid;
by hms_poid;
argum = ((&lpfmax- mypf)/(mypf - 1));
if argum > 0 then  y=-log10( argum );
else y=.;
run;

data _null_;
set claim.cms_payer end=eof;

if eof then do;
call symput('obs',_n_);
end;
run;

ods output "Number of Observations"=nobs;
     proc glmselect data = claim.model_op;

     model y = U65Pct MAPenet TactInsField Unemp
                        / selection=stepwise(select=SL) stats=all slentry= .05 slstay= .1;

     output out=predicted_factor p= yhat;

run;
quit;
ods output close;

data _null_;
set nobs;

call symput('nobs', NObsUsed);

run;

%put **********Total number of observations************: &obs;

%put 'number of observations used=' &nobs;

%end;

%else %if &error = 1 %then %do;

proc sort data=claim.actual_factor_op;
by hms_poid;
run;

proc sort data=matrloc.op_datamatrix out=demo_poid;
/* MODIFICATION 8.14.2018: Removed vintage from sas dataset */
by hms_poid;
run;

data _null_;
set demo_poid end=eof;

if eof then do;
	call symput('obs',_n_);
end;
run;

data claim.model_op;
merge claim.actual_factor_op demo_poid;
by hms_poid;
argum = ((&lpfmax- mypf)/(mypf - 1));
if argum > 0 then  y=-log10( argum );
else y=.;
run;

data _null_;
set claim.cms_payer end=eof;

if eof then do;
call symput('obs',_n_);
end;
run;

ods graphics on;
ods output ParameterEstimates = work.ParameterEstimates;
proc robustreg data=claim.model_op method=mm outest=robust;
model y = U65Pct MAPenet TactInsField Unemp
/ leverage;
output out=POID_Prediction p=log_claim_pred;
run;
quit;
ods output close;
ods graphics off;

data good_robust;
set ParameterEstimates;
where ProbChiSq < 0.05 and Parameter not in ('Intercept','Scale');
keep parameter;
run;

%let numvars_robust = ;
data robust_vars;
set good_robust;
length x1 $256;
retain x1 '';
x1 = catx(' ',x1,parameter);
call symput("numvars_robust", TRANWRD(compbl(x1),'allp','adj'));
run;
%put &numvars_robust;

ods graphics on;
ods output "Number of Observations"=nobs;
ods output ParameterEstimates = work.ParameterEstimates2;
proc robustreg data=claim.model_op method=mm outest=robust(drop=_MODEL_);
model y = &numvars_robust. / leverage;
output out=predicted_factor p=yhat;
run;
quit;
ods output close;
ods graphics off;

data _null_;
set nobs;

call symput('nobs', NObsUsed);

run;

%put **********Total number of observations************: &obs;

%put 'number of observations used=' &nobs;

%end;

%else %if &error=6 %then %do;

proc sort data=claim.actual_factor_op;
by hms_poid;
run;

proc sort data=matrloc.op_datamatrix out=demo_poid;
/* MODIFICATION 8.14.2018: Removed vintage from sas dataset */
by hms_poid;
run;

data _null_;
set demo_poid end=eof;

if eof then do;
	call symput('obs',_n_);
end;
run;

data claim.model_op;
merge claim.actual_factor_op demo_poid;
by hms_poid;
argum = ((&lpfmax- mypf)/(mypf - 1));
if argum > 0 then  y=-log10( argum );
else y=.;
run;

ods output "Number of Observations"=nobs;
proc glm data = claim.model_op;

model y = ; 

output out=predicted_factor p= yhat;

run;
quit;
ods output close;

%end;

%if &error = 0 | &error = 1 | &error = 6 %then %do;

data claim.estimated_factor;
set predicted_factor;

test_factor=all_counts/med_counts;

%if medcapture^=.  and test_factor <&lpfmax %then %do;
	 	
factorhat=round(all_counts/med_counts, 0.0001);

%end;

%else %do;

factorhat = 1 + ( &lpfmax - 1 ) / (1 + 10** (-yhat));

%end;

run;

proc sort data=claim.estimated_factor out=estimated_factor;
by hms_poid;
run;

data estimated_factor;
merge estimated_factor(in=a) claim.cms_payer(in=b keep=hms_poid);
by hms_poid;
if a and b;
run;


proc means data=estimated_factor noprint min median max;
var factorhat;
output out=est_factor min=min_factor median=median_factor max=max_factor;
run;

data _null_;
set est_factor;

call symput('min_factor', min_factor);
call symput('median_factor', median_factor);
call symput('max_factor', max_factor);

run;

%put **********min estimated factor: &min_factor;
%put **********median estimated factor: &median_factor;
%put **********max estimated factor: &max_factor;

/* Check to see if there exists CMS data; if not, then do nproj macro */
proc sql;
create table cms_obs as select count(*) as cms_obs from claim.CMS_op_migs;
quit;

data _null_;
set cms_obs;
if cms_obs = 0 then call symput('cms_obs','0');
else call symput('cms_obs','1');
run;

%put **********CMS_OP observations: &cms_obs;

	%if &cms_obs = 1 %then %do;
	%excute;
	%end;
	%else %do;
	%actcount;
	%nproj;
	%end;

%end;

%mend;

%error_choose;


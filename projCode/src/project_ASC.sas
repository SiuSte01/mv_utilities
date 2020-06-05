/* **************************************************************************************************************************
PROGRAM NAME:				new_asc_projections.sas
PURPOSE:					Pull ASC data from aggragations tables to project
							Compile ASC predictions (by PIID/POID)
PROGRAMMER:					Mark Piatek
CREATION DATE:				08/14/2015
UPDATED:					10/27/2015
NOTES:						Runs on new DB only
							Updated 10/27 to restrict on bucket since multiple buckets exist per job ID
INPUT FILES:				input.txt
							../../codes.tab
OUTPUT FILES:				asc_projections.txt
MACROS USED:				[none]
RUN BEFORE THIS PROGRAM:	Aggregations Projections Code
RUN AFTER THIS PROGRAM:		
************************************************************************************************************************** */

options mprint;
libname ASC '.';

/* Use the RUNQUIT macro to end program if error occurs */
%macro runquit;
; run; quit;
%if &syserr. ne 0 %then %do;
%abort cancel;
%end;
%mend runquit;

/* Read in inputs file */
data inputs(compress=yes);
infile 'input.txt'
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	informat Parameter $125. ;
	informat Value $200. ;
	format Parameter $125. ;
	format Value $200. ;
input
			Parameter $
			Value $
;
run;

/* Create macro variables based on inputs */
data _null_;
set inputs;

if Parameter = 'COUNTTYPE' then do;
call symput('Counting', trim(left(compress(value))));
if VALUE = 'CLAIM' then call symput('NameType','CLAIM');
else if VALUE = 'PROC' then call symput('NameType','PROC');
else if VALUE = 'PATIENT' then call symput('NameType','PATIENT');
end;

if Parameter = 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
if Parameter = 'CODETYPE' then call symput('Codetype', trim(left(compress(value))));
if Parameter = 'BUCKET' then call symput('Bucket', trim(left(value)));
if Parameter = 'AddRefDoc' then call symput('AddRefDoc', trim(left(compress(value))));
if Parameter = 'AGGREGATION_ID' then call symput('job_id', trim(left(compress(value))));
if Parameter = 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
if Parameter = 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
if Parameter = 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
if Parameter = 'AGGREGATION_TABLE' then call symput('AGGREGATION_TABLE', trim(left(compress(value))));
if Parameter = 'CLAIM_PATIENT_TABLE' then call symput('CLAIM_PATIENT_TABLE', trim(left(compress(value))));
if Parameter = 'FXFILES' then call symput('FXFILES', trim(left(compress(value))));

if Parameter = 'COUNTTYPE' then do;
	if VALUE = 'CLAIM' then do;
		call symput('TOTAL_COUNT','CLAIM_CNT');
		call symput('MDCR_COUNT','MDCR_CLAIM_CNT');
		call symput('TOTAL_FRAC_COUNT','CLAIM_FRAC_CNT');
		call symput('MDCR_FRAC_COUNT','MDCR_CLAIM_FRAC_CNT');
	end;
	else if VALUE = 'PROC' then do;
		call symput('TOTAL_COUNT','PROC_CNT');
		call symput('MDCR_COUNT','MDCR_PROC_CNT');
		call symput('TOTAL_FRAC_COUNT','PROC_FRAC_CNT');
		call symput('MDCR_FRAC_COUNT','MDCR_PROC_FRAC_CNT');
	end;
	else if VALUE = 'PATIENT' then do;
		call symput('TOTAL_COUNT','PTNT_CNT');
		call symput('MDCR_COUNT','MDCR_PTNT_CNT');
		call symput('TOTAL_FRAC_COUNT','PTNT_FRAC_CNT');
		call symput('MDCR_FRAC_COUNT','MDCR_PTNT_FRAC_CNT');
	end;
end;

run;

/* Create PX check variable based on inputs */
/* This was moved from ratio step below */
data _null_;
set inputs;

if Parameter = 'CODETYPE' then do;
	if VALUE = 'PX' then call symput('px_check',1);
	else if VALUE = 'ALL' then call symput('px_check',2);
	else call symput('px_check',0);
end;

run;
/* Create a National Count aggr name */
%let Natl_Aggr = WKUB_ASC;

%put Counting = &Counting;
%put Vintage = &Vintage;
%put Codetype = &Codetype;
%put Bucket = &Bucket;
%put NameType = &NameType;
%put AddRefDoc = &AddRefDoc;
%put job_id = &job_id;
%put Natl_Aggr = &Natl_Aggr;
%put USERNAME = &USERNAME;
%put PASSWORD = &PASSWORD;
%put INSTANCE = &INSTANCE;
%put AGGREGATION_TABLE = &AGGREGATION_TABLE;
%put CLAIM_PATIENT_TABLE = &CLAIM_PATIENT_TABLE;
%put FXFILES = &FXFILES;

%put TOTAL_COUNT = &TOTAL_COUNT;
%put MDCR_COUNT = &MDCR_COUNT;
%put TOTAL_FRAC_COUNT = &TOTAL_FRAC_COUNT;
%put MDCR_FRAC_COUNT = &MDCR_FRAC_COUNT;

libname Inputs %unquote(%str(%'&FXFILES%'));
/* effective Sept 2016, matrix dataset will be in current directory
 not in fxfiles */
libname matrloc '.';

/****modify: 2020/06/04 keep poids from asc only****/
data asc_poids;
set matrloc.asc_datamatrix(keep=hms_poid) Inputs.asc_poids_&Vintage(keep=hms_poid);
run;

proc sort data=asc_poids nodupkey;
by HMS_POID; 
run;

/* Pull data from aggregations tables */
/* 11.18.2016 the % at beginning and end of ASC does not cause problems
 because in a subsequent step, only WKUB_ASC, FL_ASC, CA_ASC, and NY_ASC are
 retained for modeling
*/

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table Org_counts(compress=yes) as 
	select *
	from connection to oracle
		(select * from &AGGREGATION_TABLE.
		where job_id = &job_id. and aggr_level = 'ORGLEVEL'
		and (aggr_name like '%ASC%'
		or aggr_name like '%FL%' or aggr_name like '%NY%' or aggr_name like '%CA%')
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		order by org_id
		)
		;

	disconnect from oracle ;
quit ;


proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table Doc_Org_counts(compress=yes) as 
	select *
	from connection to oracle
		(select * from &AGGREGATION_TABLE.
		where job_id = &job_id. and aggr_level = 'DOCORGLEVEL'
		and (aggr_name like '%ASC%')
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		order by org_id
		)
		;

	disconnect from oracle ;
quit ;

/****Note: keep asc poids ***/

data Org_counts;
merge Org_counts(in=a) asc_poids(in=b rename=(hms_poid=org_id));
by org_id;
if a and b;
run;

data Doc_Org_counts;
merge Doc_Org_counts(in=a) asc_poids(in=b rename=(hms_poid=org_id));
by org_id;
if a and b;
run;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table NATL_RATIO(compress=yes) as 
	select *
	from connection to oracle
		(select CLAIM_CNT, MDCR_CLAIM_CNT,
		PTNT_CNT, MDCR_PTNT_CNT,
		PROC_CNT, MDCR_PROC_CNT
		from &AGGREGATION_TABLE.
		where job_id = &job_id. and aggr_level = 'NATL'
		and aggr_name = %unquote(%str(%'&Natl_Aggr%'))
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		)
		;
	disconnect from oracle ;
quit ;

/* MODIFICATION 11/14/2016: Backwards compatible check for old aggr_name */
%macro old_natl_count;

proc sql;
create table check_natl as
select count(*) as natl_count from NATL_RATIO;
quit;
data _null_;
set check_natl;
if natl_count = 0 then call symput('natl_check',0);
else call symput('natl_check',1);
run;

%put natl_check = &natl_check;

%if &natl_check = 0 %then %do;

%let Natl_Aggr = WKUB_NATL_ASC;
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table NATL_RATIO(compress=yes) as 
	select *
	from connection to oracle
		(select CLAIM_CNT, MDCR_CLAIM_CNT,
		PTNT_CNT, MDCR_PTNT_CNT,
		PROC_CNT, MDCR_PROC_CNT
		from &AGGREGATION_TABLE.
		where job_id = &job_id. and aggr_level = 'NATL'
		and aggr_name = %unquote(%str(%'&Natl_Aggr%'))
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		)
		;
	disconnect from oracle ;
quit ;

%end;

%mend;

%old_natl_count;

proc export data=NATL_RATIO outfile='natl_counts_emd.txt' replace;
run;

/* Establish claim and patient ratios */

data CLAIM_PROC_RATIO;
set NATL_RATIO;
CLAIM_PROC_RATIO = CLAIM_CNT/PROC_CNT;
PAT_PROC_RATIO = PTNT_CNT/PROC_CNT;
PAT_CLAIM_RATIO = PTNT_CNT/CLAIM_CNT;
code_type = %unquote(%str(%'&Codetype%'));
run;

/* initialize error check macro variable */
%let error_check = 1;
data _null_; /* PX check removed from this step (error check remains) */
set CLAIM_PROC_RATIO;
call symput('CLAIM_PROC_RATIO',CLAIM_PROC_RATIO);
call symput('PAT_PROC_RATIO',PAT_PROC_RATIO);
call symput('PAT_CLAIM_RATIO',PAT_CLAIM_RATIO);

if code_type = 'PX' then do;
	if CLAIM_PROC_RATIO = . or PAT_PROC_RATIO = . or PAT_CLAIM_RATIO = . then call symput('error_check',1);
	else call symput('error_check',0);
end;
else do;
	if PAT_CLAIM_RATIO = . then call symput('error_check',1);
	else call symput('error_check',0);
end;

run;

%put CLAIM_PROC_RATIO = &CLAIM_PROC_RATIO;
%put PAT_PROC_RATIO = &PAT_PROC_RATIO;
%put PAT_CLAIM_RATIO = &PAT_CLAIM_RATIO;
%put error_check = &error_check;
%put px_check = &px_check;

/* Cancel program if a ratio is missing with this macro */
%macro error_out;

%if &error_check = 1 %then %do;
	data _null_; =;
	%runquit;
%end;

%mend error_out;

%error_out;

/* MODIFICATION 9.13.2018: Adding PROJECTASC variable and initialize PROJECTASC and do_cms_projection variable here */
%let do_cms_projection = yes;
%let projectasc = Y;
data _null_;
set inputs;
if Parameter = 'PROJECTASC' then do;
	call symput('projectasc', trim(left(compress(value))));
	if VALUE = 'N' then call symput('do_cms_projection','no');
	else if VALUE = 'Y' then call symput('do_cms_projection','yes');
end;
run;
%put 'PROJECTASC :' &projectasc;
%put do_cms_projection = &do_cms_projection;

/* Frist facility-level switch table */
data SWITCH;
length HMS_POID $10.;
set Org_counts;
where AGGR_NAME = 'WKUB_ASC';
HMS_POID = ORG_ID;
keep HMS_POID &TOTAL_COUNT. &MDCR_COUNT.;
run;

/* Facility-level state table */
data STATE;
set Org_counts(drop=PTNT_CNT MDCR_PTNT_CNT);
where substr(AGGR_NAME,1,6) in ('FL_ASC','NY_ASC','CA_ASC');
HMS_POID = ORG_ID;
PTNT_CNT = ceil(CLAIM_CNT*&PAT_CLAIM_RATIO.);
MDCR_PTNT_CNT = ceil(MDCR_CLAIM_CNT*&PAT_CLAIM_RATIO.);
keep HMS_POID AGGR_NAME &TOTAL_COUNT. &MDCR_COUNT.;
run;

/*
data migrate_poids;
set inputs.poidmigration_lookup_&Vintage.;
run;

proc sort data=STATE;
by HMS_POID;
run;
proc sort data=migrate_poids;
by HMS_POID;
run;

data STATE_migr;
merge migrate_poids STATE(in=a);
by HMS_POID;
if a;
if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
else if poid_migration_status ~= '' then delete;
drop poid_migration_status new_POID;
run;
*/

proc means data=STATE sum noprint nway;
class HMS_POID AGGR_NAME / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=STATE_sum(drop=_TYPE_ _FREQ_) sum=;
run;

/* First Check - make sure there are state Medicare counts */
/* If not, set model factors equal to the median pf during post-model selection */
%let replacement_factor = 0;
proc sql;
create table check1 as select sum(&MDCR_COUNT.) as medicare_sum from STATE_sum;
quit;
data _null_;
set check1;
if medicare_sum = 0 then call symput('replacement_factor',1);
run;
%put replacement_factor = &replacement_factor;

/*
proc sort data=SWITCH;
by HMS_POID;
run;
proc sort data=migrate_poids;
by HMS_POID;
run;

data SWITCH_migr;
merge migrate_poids SWITCH(in=a);
by HMS_POID;
if a;
if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
else if poid_migration_status ~= '' then delete;
drop poid_migration_status new_POID;
run;
*/

proc means data=SWITCH sum noprint nway;
class HMS_POID / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=SWITCH_sum(drop=_TYPE_ _FREQ_) sum=;
run;

data NPI_POID;
set inputs.orgid2poid_&Vintage.;
ORG_NPI=ORG_ID;
drop ORG_ID;
run;

/* CMS ratio calculations need to be in a macro */

%macro CMS_file;

%if &px_check = 1 %then %do;

/* Import CMS File */
data CMS_ASC_procs;
infile %unquote(%str(%'&FXFILES/CMS_ASC_ProcedureData.txt%'))
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	informat HCPCS $15. ;
	informat MODIFIER_1 $2. ;
	informat MODIFIER_2 $2. ;
	informat ALLOWED_CHARGES best32. ;
	informat ALLOWED_SERVICES best32. ;
	informat CARRIER best32. ;
	informat SUPPLIER_ID_NUMBER $10. ;
	informat SUPPLIER_COUNTY best32. ;
	informat SUPPLIER_STATE best32. ;
	informat SUPPLIER_STATE_ABBREV $2. ;
	informat CBSA best32. ;
	informat WAGE_INDEX best32. ;
	informat DISCOUNTED_ALLOWED_SERVICES best32. ;
	format HCPCS $15. ;
	format MODIFIER_1 $2. ;
	format MODIFIER_2 $2. ;
	format ALLOWED_CHARGES best12. ;
	format ALLOWED_SERVICES best12. ;
	format CARRIER best12. ;
	format SUPPLIER_ID_NUMBER $10. ;
	format SUPPLIER_COUNTY best12. ;
	format SUPPLIER_STATE best12. ;
	format SUPPLIER_STATE_ABBREV $2. ;
	format CBSA best12. ;
	format WAGE_INDEX best12. ;
	format DISCOUNTED_ALLOWED_SERVICES best12. ;
input
	HCPCS $
	MODIFIER_1 $
	MODIFIER_2 $
	ALLOWED_CHARGES
	ALLOWED_SERVICES
	CARRIER
	SUPPLIER_ID_NUMBER $
	SUPPLIER_COUNTY
	SUPPLIER_STATE
	SUPPLIER_STATE_ABBREV $
	CBSA
	WAGE_INDEX
	DISCOUNTED_ALLOWED_SERVICES
;
ORG_NPI = SUPPLIER_ID_NUMBER;
keep HCPCS ORG_NPI ALLOWED_SERVICES;
run;

/* MODIFICATION 4.25.2017 - no longer using proc import
   Import data assuming there are two columns in codes.tab */
data codes;
infile '../../codes/codes.tab'
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=1 ;
	informat code $15. ;
	informat scheme $15. ;
	format code $15. ;
	format scheme $15. ;
input code $ scheme $ ;
run;

data codes;
set codes;
codetype = %unquote(%str(%'&Codetype%'));
run;

/* Just get HCPCS */
data code_procs;
set codes;
where scheme = 'HCPCS';
HCPCS = code;
drop code scheme codetype;
run;

/* Merge to CMS ASC Procs file */
proc sort data=CMS_ASC_procs;
by HCPCS;
run;
proc sort data=code_procs;
by HCPCS;
run;

data CMS_ASC_proc_codes;
merge CMS_ASC_procs(in=a) code_procs(in=b);
if a and b;
by HCPCS;
run;

proc sort data=CMS_ASC_proc_codes;
by ORG_NPI;
run;
proc sort data=NPI_POID;
by ORG_NPI;
run;

data CMS_procs_poid;
merge NPI_POID CMS_ASC_proc_codes(in=a);
by ORG_NPI;
if a;
drop ORG_NPI;
run;

proc means data=CMS_procs_poid sum nway noprint;
class HMS_POID;
var ALLOWED_SERVICES;
output out=CMS_PROC_CNT(drop=_TYPE_ _FREQ_) sum=PROC_CMS;
run;

/* These tables will be used for claim or patient facility projection */
data CMS_CLAIM_CNT;
set CMS_PROC_CNT;
CLAIM_CMS = ceil(PROC_CMS*&CLAIM_PROC_RATIO.);
drop PROC_CMS;
run;
data CMS_PTNT_CNT;
set CMS_PROC_CNT;
PATIENT_CMS = ceil(PROC_CMS*&PAT_PROC_RATIO.);
drop PROC_CMS;
run;

%end;

%else %if &px_check = 2 %then %do;

/* Import CMS File */
data CMS_ASC_procs;
infile %unquote(%str(%'&FXFILES/CMS_ASC_ProcedureData.txt%'))
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	informat HCPCS $15. ;
	informat MODIFIER_1 $2. ;
	informat MODIFIER_2 $2. ;
	informat ALLOWED_CHARGES best32. ;
	informat ALLOWED_SERVICES best32. ;
	informat CARRIER best32. ;
	informat SUPPLIER_ID_NUMBER $10. ;
	informat SUPPLIER_COUNTY best32. ;
	informat SUPPLIER_STATE best32. ;
	informat SUPPLIER_STATE_ABBREV $2. ;
	informat CBSA best32. ;
	informat WAGE_INDEX best32. ;
	informat DISCOUNTED_ALLOWED_SERVICES best32. ;
	format HCPCS $15. ;
	format MODIFIER_1 $2. ;
	format MODIFIER_2 $2. ;
	format ALLOWED_CHARGES best12. ;
	format ALLOWED_SERVICES best12. ;
	format CARRIER best12. ;
	format SUPPLIER_ID_NUMBER $10. ;
	format SUPPLIER_COUNTY best12. ;
	format SUPPLIER_STATE best12. ;
	format SUPPLIER_STATE_ABBREV $2. ;
	format CBSA best12. ;
	format WAGE_INDEX best12. ;
	format DISCOUNTED_ALLOWED_SERVICES best12. ;
input
	HCPCS $
	MODIFIER_1 $
	MODIFIER_2 $
	ALLOWED_CHARGES
	ALLOWED_SERVICES
	CARRIER
	SUPPLIER_ID_NUMBER $
	SUPPLIER_COUNTY
	SUPPLIER_STATE
	SUPPLIER_STATE_ABBREV $
	CBSA
	WAGE_INDEX
	DISCOUNTED_ALLOWED_SERVICES
;
ORG_NPI = SUPPLIER_ID_NUMBER;
keep HCPCS ORG_NPI ALLOWED_SERVICES;
run;

proc sort data=CMS_ASC_procs;
by ORG_NPI;
run;
proc sort data=NPI_POID;
by ORG_NPI;
run;

data CMS_procs_poid;
merge NPI_POID CMS_ASC_procs(in=a);
by ORG_NPI;
if a;
drop ORG_NPI;
run;

proc means data=CMS_procs_poid sum nway noprint;
class HMS_POID;
var ALLOWED_SERVICES;
output out=CMS_PROC_CNT(drop=_TYPE_ _FREQ_) sum=PROC_CMS;
run;

/* These tables will be used for claim or patient facility projection */
data CMS_CLAIM_CNT;
set CMS_PROC_CNT;
CLAIM_CMS = ceil(PROC_CMS*&CLAIM_PROC_RATIO.);
drop PROC_CMS;
run;
data CMS_PTNT_CNT;
set CMS_PROC_CNT;
PATIENT_CMS = ceil(PROC_CMS*&PAT_PROC_RATIO.);
drop PROC_CMS;
run;

%end;

%else %if &px_check = 0 %then %do;

/* Create empty tables */

data CMS_PROC_CNT;
length HMS_POID $10.;
length PROC_CMS 8.;
if HMS_POID = '' then delete;
run;
data CMS_CLAIM_CNT;
length HMS_POID $10.;
length CLAIM_CMS 8.;
if HMS_POID = '' then delete;
run;
data CMS_PTNT_CNT;
length HMS_POID $10.;
length PATIENT_CMS 8.;
if HMS_POID = '' then delete;
run;

%end;

%mend CMS_file;

%CMS_file;

/* Second Check - make sure there are CMS counts */
/* If not, do not run model projection */
*%let do_cms_projection = yes;
proc sql;
create table check2 as select count(*) as CMS_count from CMS_PROC_CNT;
quit;
data _null_;
set check2;
if CMS_count = 0 then call symput('do_cms_projection','no');
run;
%put do_cms_projection = &do_cms_projection;

data STATE_medicare_pct;
set STATE_sum;
where HMS_POID ~= '';
Medicare_Pct = round(100*&MDCR_COUNT./&TOTAL_COUNT.,.01);
run;

proc sort data=STATE_medicare_pct;
by HMS_POID;
run;
proc sort data=SWITCH_sum;
by HMS_POID;
run;
proc sort data=CMS_&TOTAL_COUNT.;
by HMS_POID;
run;
proc sort data=matrloc.asc_datamatrix out=matrix; /* MODIFICATION 8.20.2018: removed vintage from datamatrix */
by HMS_POID;
run;

/* Calculations */
data STATE_medicare_percents;
merge STATE_medicare_pct(in=a) matrix(in=b);
by HMS_POID;
if a and b;
Log_Counts = log10(&TOTAL_COUNT.);
Med_fraction = &MDCR_COUNT./&TOTAL_COUNT.;
if &MDCR_COUNT. ~= 0 then projection_factor = &TOTAL_COUNT./&MDCR_COUNT.;
proj_factor_log = log10(projection_factor);
Boxplot = 'States';
run;

/* Append covariates to all sources */
data All_sources;
merge STATE_medicare_pct(rename=(&TOTAL_COUNT.=COUNTS_STATE &MDCR_COUNT.=COUNTS_MED_STATE))
SWITCH_sum(rename=(&TOTAL_COUNT.=COUNTS_SWITCH &MDCR_COUNT.=COUNTS_MED_SWITCH))
CMS_&TOTAL_COUNT.;
by HMS_POID;
if HMS_POID = 'MISSING' then delete;
drop AGGR_NAME Medicare_pct;
run;
proc datasets lib=work memtype=data nolist;
modify All_sources; 
attrib _all_ label=''; 
run;
quit;

data All_sources_wcov;
merge All_sources(in=a) matrix(in=b);
by HMS_POID;
if a and b;
run;

proc export data=All_sources_wcov outfile='facilities_wcov.txt' replace;
run;

/* Calculate and remove outliers */
proc means data=STATE_medicare_percents noprint q1 q3;
var Log_Counts;
output out=iqr_out_vol q1=q1 q3=q3;
run;
/* Check to see if this dataset is empty */
proc sql;
create table empty_set as select count(*) as empty from iqr_out_vol;
quit;
data _null_;
set empty_set;
if empty = 0 then call symput('Vol_Outlier_Low',0);
run;
%put Vol_Outlier_Low = &Vol_Outlier_Low;
data _null_;
set iqr_out_vol;
if _TYPE_ = 0 then call symput('Vol_Outlier_Low',(q1 - 1.5*(q3-q1)));
if _TYPE_ = 0 then call symput('Vol_Outlier_High',(q3 + 1.5*(q3-q1)));
run;
%put Vol_Outlier_Low = &Vol_Outlier_Low;
%put Vol_Outlier_High = &Vol_Outlier_High;
data remove_out1;
set STATE_medicare_percents;
if Log_Counts < &Vol_Outlier_Low. then delete;
if &MDCR_COUNT. = 0 then delete;
run;

proc means data=remove_out1 noprint q1 q3;
var proj_factor_log;
output out=iqr_out_med q1=q1 q3=q3;
run;
%let Med_Outlier_Low = 0;
%let Med_Outlier_High = 0;
%let PF_Low = 0;
%let PF_High = 0;
data _null_;
set iqr_out_med;
if _TYPE_ = 0 then call symput('Med_Outlier_Low',(q1 - 1.5*(q3-q1)));
if _TYPE_ = 0 then call symput('Med_Outlier_High',(q3 + 1.5*(q3-q1)));
if _TYPE_ = 0 then call symput('PF_Low',10**(q1 - 1.5*(q3-q1)));
if _TYPE_ = 0 then call symput('PF_High',10**(q3 + 1.5*(q3-q1)));
run;
%put Med_Outlier_Low = &Med_Outlier_Low;
%put Med_Outlier_High = &Med_Outlier_High;
%put PF_Low = &PF_Low;
%put PF_High = &PF_High;

/* Create modeling dataset */
data model_set;
set remove_out1;
if proj_factor_log < &Med_Outlier_Low. then delete;
else if proj_factor_log >= &Med_Outlier_High. then delete;
else if projection_factor = 1 then delete;
y=log10((projection_factor-1)/(10**&Med_Outlier_High.-projection_factor));
run;

/* Third Check - must be more than 10 observations in the modeling set */
/* If not, projections will run, but use median factor */
proc sql;
create table check3 as select count(*) as model_count from model_set;
quit;
data _null_;
set check3;
if model_count < 10 then call symput('replacement_factor',1);
run;
%put replacement_factor = &replacement_factor;

/* Check for empty model set */
proc sql;
create table model_set_empty as select count(*) as check_model_set from model_set;
quit;
data _null_;
set model_set_empty;
if check_model_set = 0 then call symput('model_set','STATE_medicare_percents');
else call symput('model_set','model_set');
run;
%put model_set = &model_set;

/* Fourth Check - median factor must not be greater than 20 */
proc means data=&model_set. median noprint;
where projection_factor ~= .;
var projection_factor;
output out=check4 median=median_factor;
run;
%let median_pf_fac = 3.117; /* Based on NY & FL ASC claims */
data _null_;
set check4;
if median_factor > 20 then call symput('do_cms_projection','no');
call symput('median_pf_fac',median_factor);
run;
%put do_cms_projection = &do_cms_projection;
%put median_pf_fac = &median_pf_fac;

/* Fifth Check - do not attempt to project if modeling set is empty */
proc sql;
create table check5 as select count(*) as modeling_count from model_set;
quit;
data _null_;
set check5;
if modeling_count = 0 then call symput('do_cms_projection','no');
run;
%put do_cms_projection = &do_cms_projection;

/* Facility Projection Macro */
%macro Fac_Proj_yes();  

/* Use Reg procedure to get full model estimates */
proc reg data=model_set;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT / vif;
run;
quit;

/* Get selected model */
proc glmselect data=model_set;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT
/ selection=stepwise(select=SL) stats=all slentry= .15 slstay= .15; /* default start/stop values */
score data=All_sources_wcov
out=projected_factors predicted=yhat;
run;

proc means data=model_set noprint median;
var Med_fraction;
output out=median_value median=median_value;
run;
data _null_;
set median_value;
if _TYPE_ = 0 then call symput('Median_Med_fraction',median_value);
run;
%put Median_Med_fraction = &Median_Med_fraction;

data CMS_temp;
set CMS_&TOTAL_COUNT.;
where &NameType._CMS ~= 0;
run;

/* Score records accordingly */
data All_sources_scored;
merge projected_factors
model_set(in=model_state keep=HMS_POID)
CMS_temp(in=cms keep=HMS_POID)
SWITCH_sum(in=emd keep=HMS_POID)
STATE_medicare_percents(in=st keep=HMS_POID)
;
by HMS_POID;

if &replacement_factor = 0 then 
model_factor = ((10**(yhat))*(10**&Med_Outlier_High.)+1)/((10**(yhat))+1);
else model_factor = &median_pf_fac.;

if model_state then FAC_COUNT = COUNTS_STATE;
else if emd and not (model_state or cms or st) then FAC_COUNT = COUNTS_SWITCH;
else if st and not (model_state or cms or emd) then FAC_COUNT = COUNTS_STATE;
else if st and emd and not (model_state or cms) then FAC_COUNT = COUNTS_STATE;
else if cms and not (model_state or emd or st) then FAC_COUNT = model_factor*&NameType._CMS;
else if cms and st and not (model_state or emd) then FAC_COUNT = model_factor*&NameType._CMS;
else if cms and emd and not (model_state or st) then do;
	if (COUNTS_SWITCH-COUNTS_MED_SWITCH) > 0.5*(&NameType._CMS*(1-&Median_Med_fraction.)/&Median_Med_fraction.)
	then FAC_COUNT = COUNTS_SWITCH-COUNTS_MED_SWITCH+&NameType._CMS;
	else FAC_COUNT = model_factor*&NameType._CMS;
end;
else if cms and emd and st and not model_state then do;
	if (COUNTS_SWITCH-COUNTS_MED_SWITCH) > 0.5*(&NameType._CMS*(1-&Median_Med_fraction.)/&Median_Med_fraction.)
	then FAC_COUNT = COUNTS_SWITCH-COUNTS_MED_SWITCH+&NameType._CMS;
	else FAC_COUNT = model_factor*&NameType._CMS;
end;

FINAL_FACILITY_COUNT = ceil(FAC_COUNT);
if FINAL_FACILITY_COUNT = . then delete;

run;

%mend Fac_Proj_yes;

/* Facility Non-Projection Macro */
%macro Fac_Proj_no();  

%let Median_Med_fraction = 0.3208; /* Based on NY & FL ASC claims */
proc means data=&model_set. noprint median;
*where Med_fraction ~= .;
var Med_fraction;
output out=median_value median=median_value;
run;
data _null_;
set median_value;
if _TYPE_ = 0 then call symput('Median_Med_fraction',median_value+.0001);
run;
%put Median_Med_fraction = &Median_Med_fraction;

data CMS_temp;
set CMS_&TOTAL_COUNT.;
where &NameType._CMS ~= 0;
run;

data All_sources_scored;
merge All_sources_wcov(keep=HMS_POID COUNTS_STATE COUNTS_SWITCH &NameType._CMS COUNTS_MED_SWITCH)
model_set(in=model_state keep=HMS_POID)
CMS_&TOTAL_COUNT.(in=cms keep=HMS_POID)
SWITCH_sum(in=emd keep=HMS_POID)
STATE_medicare_percents(in=st keep=HMS_POID)
;
by HMS_POID;

if model_state then FAC_COUNT = COUNTS_STATE;
else if emd and not (model_state or cms or st) then FAC_COUNT = COUNTS_SWITCH;
else if st and not (model_state or cms or emd) then FAC_COUNT = COUNTS_STATE;
else if st and emd and not (model_state or cms) then FAC_COUNT = COUNTS_STATE;

/* MODIFICATION 12.11.2018: When PROJECTASC is N as decided by user, do not use median as multipliers */
%if &projectasc = N %then %do;
else if cms and not (model_state or emd or st) then FAC_COUNT = 1*&NameType._CMS;
else if cms and st and not (model_state or emd) then FAC_COUNT = max(1*&NameType._CMS,COUNTS_STATE);
%end;
%else %do;
else if cms and not (model_state or emd or st) then FAC_COUNT = &median_pf_fac.*&NameType._CMS;
else if cms and st and not (model_state or emd) then FAC_COUNT = &median_pf_fac.*&NameType._CMS;
%end;

else if cms and emd and not (model_state or st) then do;
	if (COUNTS_SWITCH-COUNTS_MED_SWITCH) > 0.5*(&NameType._CMS*(1-&Median_Med_fraction.)/&Median_Med_fraction.)
	then FAC_COUNT = COUNTS_SWITCH-COUNTS_MED_SWITCH+&NameType._CMS;
	else FAC_COUNT = &NameType._CMS;
end;
else if cms and emd and st and not model_state then do;
	if (COUNTS_SWITCH-COUNTS_MED_SWITCH) > 0.5*(&NameType._CMS*(1-&Median_Med_fraction.)/&Median_Med_fraction.)
	then FAC_COUNT = COUNTS_SWITCH-COUNTS_MED_SWITCH+&NameType._CMS;
	else FAC_COUNT = &NameType._CMS;
end;

FINAL_FACILITY_COUNT = ceil(FAC_COUNT);
if FINAL_FACILITY_COUNT = . then delete;

run;

%mend Fac_Proj_no;

%Fac_Proj_&do_cms_projection.();

/* Cap unusually high facility projections */
data logs;
set All_sources_scored;
log_fac = log10(FINAL_FACILITY_COUNT);
run;
proc means data=logs noprint q1 q3;
var log_fac;
output out=iqr_out_log q1=q1 q3=q3;
run;
%let Projection_High = 1000; /* Initialize in case of empty set */
data _null_;
set iqr_out_log;
if _TYPE_ = 0 then call symput('Projection_High',(q3 + 1.5*(q3-q1)));
run;
%put Projection_High = &Projection_High;
data ASC.All_sources_scored;
set All_sources_scored;
if log10(FINAL_FACILITY_COUNT) > &Projection_High. then
FINAL_FACILITY_COUNT = ceil((10**&Projection_High.)*(0.98+ranuni(0)*0.02));
run;



/* Part B projections at the Doctor level */

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table Doc_counts(compress=yes) as 
	select *
	from connection to oracle
		(select * from &AGGREGATION_TABLE.
		where job_id = &job_id. and aggr_level = 'DOCLEVEL'
		and (aggr_name like '%ASC%')
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		)
		;

	disconnect from oracle ;
quit ;

data SWITCH_docs;
length HMS_PIID $10.;
set Doc_counts;
where AGGR_NAME = 'WKMX_ASC';
HMS_PIID = DOC_ID;
keep HMS_PIID &TOTAL_COUNT. &MDCR_COUNT.;
run;

data PTB_docs;
length HMS_PIID $10.;
set Doc_counts;
where AGGR_NAME = 'PTB_ASC';
HMS_PIID = DOC_ID;
keep HMS_PIID &TOTAL_COUNT. &MDCR_COUNT.;
run;

/* no longer migrating piids */
/*data migrate_piids;
set inputs.piidmigr_&Vintage.(rename=(HMS_PIID=NEW_PIID));
HMS_PIID = OLD_PIID;
drop OLD_PIID;
run;
*/
proc sort data=SWITCH_docs;
by HMS_PIID;
run;
proc sort data=PTB_docs;
by HMS_PIID;
run;

/*proc sort data=migrate_piids;
by HMS_PIID;
run;

data PIID_SWITCH_migr;
merge migrate_piids SWITCH_docs(in=a);
by HMS_PIID;
if a;
if piid_migration_status = 'MOVED' then HMS_PIID = NEW_PIID;
else if piid_migration_status ~= '' then HMS_PIID = '';
drop piid_migration_status NEW_PIID;
run;

proc means data=PIID_SWITCH_migr sum noprint nway;
class HMS_PIID / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=PIID_SWITCH_sum(drop=_TYPE_ _FREQ_)
sum=&TOTAL_COUNT._sw &MDCR_COUNT._sw;
run;
*/
data PIID_SWITCH_sum;
set SWITCH_docs;
if HMS_PIID = 'MISSING' then delete;
rename &TOTAL_COUNT. = &TOTAL_COUNT._sw;
rename &MDCR_COUNT. = &MDCR_COUNT._sw;
run;
/*
data PIID_PTB_migr;
merge migrate_piids PTB_docs(in=a);
by HMS_PIID;
if a;
if piid_migration_status = 'MOVED' then HMS_PIID = NEW_PIID;
else if piid_migration_status ~= '' then HMS_PIID = '';
drop piid_migration_status NEW_PIID;
run;

proc means data=PIID_PTB_migr sum noprint nway;
class HMS_PIID / missing;
var &TOTAL_COUNT.;
output out=PIID_PTB_sum(drop=_TYPE_ _FREQ_)
sum=&TOTAL_COUNT._ptb;
run;
*/
data PIID_PTB_sum;
set PTB_docs;
if HMS_PIID = 'MISSING' then delete;
rename &TOTAL_COUNT. = &TOTAL_COUNT._ptb;
run;

/* First Check - make sure there are switch Medicare counts */
/* If not, set model factors equal to 1 post-model selection */
%let replacement_factor = 0;
proc sql;
create table check1 as select sum(&MDCR_COUNT._sw) as medicare_sum from PIID_SWITCH_sum;
quit;
data _null_;
set check1;
if medicare_sum = 0 then call symput('replacement_factor',1);
run;
%put replacement_factor = &replacement_factor;

/* Second Check - make sure there are Part B counts */
/* If not, do not run model projection */
%let do_ptb_projection = yes;
proc sql;
create table check2 as select count(*) as PtB_count from PIID_PTB_sum;
quit;
data _null_;
set check2;
if PtB_count = 0 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;

/* Make sure ID lengths are same as WK table */
data IndivID2PIID_&Vintage.;
length HMS_PIID $ 14.;
set Inputs.IndivID2PIID_&Vintage.;
run;

proc sort data=IndivID2PIID_&Vintage. nodupkey;
by HMS_PIID;
run;
proc sort data=PIID_SWITCH_sum;
by HMS_PIID;
run;
proc sort data=PIID_PTB_sum;
by HMS_PIID;
run;

data PIID_SWITCH_zip;
merge IndivID2PIID_&Vintage.(in=a) PIID_SWITCH_sum(in=b);
by HMS_PIID;
if b;
ZIP = RANK1ZIP;
drop INDIV_ID RANK1ZIP;
run;

data PIID_PTB_zip;
merge IndivID2PIID_&Vintage.(in=a) PIID_PTB_sum(in=b);
by HMS_PIID;
if b;
ZIP = RANK1ZIP;
drop INDIV_ID RANK1ZIP;
run;

proc sort data=PIID_SWITCH_zip;
by HMS_PIID;
run;
proc sort data=PIID_PTB_zip;
by HMS_PIID;
run;

data PIID_all_zip;
merge PIID_SWITCH_zip PIID_PTB_zip;
by HMS_PIID;
if &TOTAL_COUNT._sw = . then &TOTAL_COUNT._sw = 0;
if &MDCR_COUNT._sw = . then &MDCR_COUNT._sw = 0;
if &TOTAL_COUNT._ptb = . then &TOTAL_COUNT._ptb = 0;
run;

/* Merge in covariates */
data zips;
format FIPS Z5.;
set inputs.zip2fips(rename=(fips=fipscode));
FIPS = fipscode*1;
drop fipscode;
run;
proc sort data=zips nodupkey;
by ZIP;
run;
proc sort data=PIID_all_zip out=temp;
by ZIP;
run;
proc sort data=inputs.covar_under65 out=covar_under65;
by ZIP;
run;

data PIID_all_fips(compress=yes);
merge temp(in=a) zips covar_under65;
by ZIP;
if a;
run;

proc sort data=PIID_all_fips;
by FIPS;
run;
proc sort data=inputs.covar_County_Unemp out=covar_County_Unemp;
by FIPS;
run;
proc sort data=inputs.covar_MA_penetration out=covar_MA_penetration;
by FIPS;
run;
proc sort data=inputs.covar_HI_expend out=covar_HI_expend;
by FIPS;
run;

data PIID_all_wcov(compress=yes);
merge PIID_all_fips(in=a)
covar_County_Unemp(keep=FIPS Rate)
covar_MA_penetration(keep=FIPS Penetration)
covar_HI_expend(keep=FIPS IHXCYHC1)
;
by FIPS;
if a;
rename Rate = UNEMPLOYMENT;
rename Penetration = MA_PENETRATION;
rename IHXCYHC1 = TACTINS_EXPEND;
if PERCENT_POP_UNDER_65 < .0001 then PCT_UNDER65 = .;
else PCT_UNDER65 = round(PERCENT_POP_UNDER_65,.01);
drop POP_UNDER_65 PERCENT_POP_UNDER_65 FIPS;
if HMS_PIID = '' then delete;
run;

proc export data=PIID_all_wcov outfile='physicians_wcov.txt' replace;
run;

/* Make the tenth-largest Switch count value the cap */
proc sort data=PIID_all_wcov out=first10;
by descending &TOTAL_COUNT._sw;
run;
data first10;
set first10(obs=10);
temp_value=&TOTAL_COUNT._sw + (ranuni(0)); /* needed in case 9th and 10th are the same */
keep &TOTAL_COUNT._sw temp_value;
run;
proc rank data=first10 descending out=first10;
var temp_value;
ranks rank;
run;
data first10;
set first10;
if rank = 10 then call symput('Cap',&TOTAL_COUNT._sw);
run;
%put Cap = &Cap;

/* Set up training subset */
data PIID_all_train(compress=yes);
set PIID_all_wcov;
where &MDCR_COUNT._sw >= 5;
SW_ratio = &TOTAL_COUNT._sw/&MDCR_COUNT._sw;
if SW_ratio = 1 then delete;
run;

proc means data=PIID_all_train noprint q1 median q3;
var SW_ratio;
output out=iqr_out q1=q1 median=median q3=q3;
run;

/* If training set is empty, default macro variables to 1 so program doesn't fail */
proc sql;
create table train_empty as select count(*) as check_empty from PIID_all_train;
quit;
data _null_;
set train_empty;
if check_empty = 0 then do;
call symput('Outlier',1);
call symput('Median_pf_phys',1);
end;
run;
%put Outlier = &Outlier;
%put Median_pf_phys = &Median_pf_phys;

data _null_;
set iqr_out;
if _TYPE_ = 0 then call symput('Outlier',(q3 + 1.5*(q3-q1)));
if _TYPE_ = 0 then call symput('Median_pf_phys',median);
run;
%put Outlier = &Outlier;
%put Median_pf_phys = &Median_pf_phys;

/* Create dependent variable for model */
data PIID_all_train;
set PIID_all_train;
where SW_ratio < &Outlier.;
y = log10(SW_ratio - 1);
run;

/* Third check - must be more than 10 observations in training set */
/* If not, projections macro will run, but produce model factors of 1 */
proc sql;
create table check3 as select count(*) as Training_Count from PIID_all_train;
quit;
data _null_;
set check3;
if Training_Count < 10 then call symput('replacement_factor',1);
run;
%put replacement_factor = &replacement_factor;

/* Fourth check - median WK allpayer/medicare ratio must be no greater than 20 */
proc means data=PIID_all_train median noprint;
var SW_ratio;
output out=check4 median=median_ratio;
run;
data _null_;
set check4;
if median_ratio > 20 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;

/* Fifth check - do not attempt to project if training set is empty */
proc sql;
create table check5 as select count(*) as training_count from check4;
quit;
data _null_;
set check5;
/* MODIFICATION 10.01.2019: also check for existence of cap value for specific situations */
if training_count = 0 or %symexist(Cap) = 0 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;


/* Part B Projection Macro */
%macro Phys_Proj_yes();  

/* Use Reg procedure to get full model estimates */
proc reg data=PIID_all_train;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT / vif;
run;
quit;

/* Get selected model */
proc glmselect data=PIID_all_train;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT
/ selection=stepwise(select=SL) stats=all slentry= .15 slstay= .15; /* default start/stop values */
score data=PIID_all_wcov
out=PIID_all_new predicted=yhat;
run;

/* Score records where CMS Count is greater than the WK count */
data PIID_all_new;
set PIID_all_new;
if &replacement_factor. = 1 then model_factor = &Median_pf_phys.;
else model_factor = 10**(yhat) + 1;
run;

%let Median = 1;
/* Find the median model factor for imputation */
proc means data=PIID_all_new n median noprint;
where 0 < &TOTAL_COUNT._ptb;
var model_factor;
output out=median median=;
run;
data _null_;
set median;
call symput('Median',model_factor);
run;
%put Median = &Median;

/* Impute median for null model factors */
data PIID_all_new;
set PIID_all_new;

if &TOTAL_COUNT._ptb <= 5 then count_factor = 10;
else count_factor = 15;

/* Records above the cap must get a uniformly-distributed
   random factor no less than 80% of the cap */
if model_factor = . then model_factor = &Median.;
final_proj = &TOTAL_COUNT._ptb * count_factor * model_factor;
if final_proj > &Cap. then final_cms_proj = floor(&Cap.*(0.2*ranuni(0) + 0.8));
else final_cms_proj = floor(final_proj);

if final_proj > &Cap. then final_cms_cap = 1;
else final_cms_cap = 0;

/* Blending Factor macro variable removed */
if &TOTAL_COUNT._ptb ~= 0 then r = &TOTAL_COUNT._sw/&TOTAL_COUNT._ptb;
if 0 <= r < 1 then f = 0;
else if 1 <= r <= 10 then f = (r-1)/9;
else if r > 10 then f = 1;

if f = . then est_count = &TOTAL_COUNT._sw;
else est_count = floor(f*&TOTAL_COUNT._sw + (1-f)*final_cms_proj);

if &TOTAL_COUNT._sw > 0 and &TOTAL_COUNT._ptb = 0 then group = 'WK only ';
else if &TOTAL_COUNT._sw = 0 and &TOTAL_COUNT._ptb > 0 then group = 'PtB only';
else if &TOTAL_COUNT._sw > 0 and &TOTAL_COUNT._ptb > 0 then group = 'Both';

run;

%mend Phys_Proj_yes;

/* Part B Non-Projection Macro */
%macro Phys_Proj_no();  

data PIID_all_new;
set PIID_all_wcov;
*est_count = &TOTAL_COUNT._sw;

if &TOTAL_COUNT._ptb <= 5 then count_factor = 10;
else count_factor = 15;

final_proj = &TOTAL_COUNT._ptb * count_factor;
final_cms_proj = floor(final_proj);

if &TOTAL_COUNT._ptb ~= 0 then r = &TOTAL_COUNT._sw/&TOTAL_COUNT._ptb;
if 0 <= r < 1 then f = 0;
else if 1 <= r <= 10 then f = (r-1)/9;
else if r > 10 then f = 1;

if f = . then est_count = &TOTAL_COUNT._sw;
else est_count = floor(f*&TOTAL_COUNT._sw + (1-f)*final_cms_proj);

run;

%mend Phys_Proj_no;

/* Choose appropriate macro */
%Phys_Proj_&do_ptb_projection.();


/* Distribute among professional claims */
data Doc_Org_1500;
length HMS_POID $10.;
length HMS_PIID $10.;
set Doc_Org_counts;
where AGGR_NAME = 'WKMX_ASC';
if ORG_ID = 'NULL' then ORG_ID = '';
else if ORG_ID = 'MISSING' then ORG_ID = '';
if DOC_ID = 'MISSING' then delete;
HMS_POID = ORG_ID;
HMS_PIID = DOC_ID;
keep HMS_PIID HMS_POID AGGR_NAME &TOTAL_COUNT. &MDCR_COUNT.;
run;

/*
proc sort data=Doc_Org_1500;
by HMS_POID;
run;
data Doc_Org_1500_poidmigr;
merge migrate_poids Doc_Org_1500(in=a);
by HMS_POID;
if a;
if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
else if poid_migration_status ~= '' then delete;
drop poid_migration_status new_POID;
run;

proc sort data=Doc_Org_1500_poidmigr;
by HMS_PIID;
run;

data Doc_Org_1500_migr;
merge migrate_piids Doc_Org_1500_poidmigr(in=a);
by HMS_PIID;
if a;
if piid_migration_status = 'MOVED' then HMS_PIID = NEW_PIID;
else if piid_migration_status ~= '' then HMS_PIID = '';
drop piid_migration_status NEW_PIID;
run;
*/
proc means data=Doc_Org_1500 sum noprint nway;
class HMS_POID HMS_PIID / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=Doc_Org_1500_sum(drop=_TYPE_ _FREQ_)
sum=&TOTAL_COUNT._15 &MDCR_COUNT._15 &TOTAL_FRAC_COUNT._15 &MDCR_FRAC_COUNT._15;
run;

data ORG_TYPE;
set inputs.asc_poids_&Vintage.;
run;
data POID_est;
set ASC.All_sources_scored;
POID_EST = FINAL_FACILITY_COUNT;
keep HMS_POID POID_EST;
run;
proc sort data=ORG_TYPE;
by HMS_POID;
run;
proc sort data=POID_est(keep=HMS_POID) out=POID_ascstep;
by HMS_POID;
run;
data ORG_TYPE_ASC;
merge ORG_TYPE POID_ascstep;
by HMS_POID;
run;

/* PIID counts must distribute among respective POIDS */
proc means data=Doc_Org_1500_sum sum noprint;
class HMS_PIID / missing;
var &TOTAL_COUNT._15;
output out=temp sum=PIID_total;
run;
proc sort data=Doc_Org_1500_sum;
by HMS_PIID;
run;
proc sort data=temp;
where _TYPE_ = 1;
by HMS_PIID;
run;
proc sort data=PIID_all_new;
by HMS_PIID;
run;
data PIID_withPOID(compress=yes);
merge Doc_Org_1500_sum(in=a) temp(keep=HMS_PIID PIID_total) PIID_all_new(in=b);
by HMS_PIID;
if a;
est_at_poid = max(round((&TOTAL_COUNT._15/PIID_total)*est_count,1),1);
drop count_factor model_factor final_proj r f;
run;

data ASC.PIID_withPOID;
set PIID_withPOID;
run;

/* Get CMS PIIDs only */
data PIID_cms_new;
set PIID_all_new;
where &TOTAL_COUNT._sw = 0;
run;

/* Get estimates for CMS only records */
proc sort data=PIID_cms_new;
by HMS_PIID;
run;
proc sort data=inputs.estpoidasc_&Vintage. out=estpoid;
by HMS_PIID HMS_POID;
run;
data PIID_cms_POID;
merge PIID_cms_new(in=a) estpoid;
by HMS_PIID;
if a;
est_at_poid = est_count;
run;

data piid_at_poid_predictions(compress=yes);
set PIID_withPOID(keep=HMS_PIID HMS_POID est_at_poid)
PIID_cms_POID(keep=HMS_PIID HMS_POID est_at_poid);
if HMS_POID = 'MISSING' then HMS_POID = '';
if HMS_PIID = '' then delete;
run;


/* Bring in the rest of the Docs */
data Doc_Org_State;
set Doc_Org_counts(drop=PTNT_CNT MDCR_PTNT_CNT);
where substr(AGGR_NAME,1,6) in ('FL_ASC','NY_ASC','CA_ASC');
HMS_POID = ORG_ID;
HMS_PIID = DOC_ID;
PTNT_CNT = ceil(CLAIM_CNT*&PAT_CLAIM_RATIO.);
MDCR_PTNT_CNT = ceil(MDCR_CLAIM_CNT*&PAT_CLAIM_RATIO.);
PTNT_FRAC_CNT = ceil(CLAIM_CNT*&PAT_CLAIM_RATIO.);
MDCR_PTNT_FRAC_CNT = ceil(MDCR_CLAIM_CNT*&PAT_CLAIM_RATIO.);
keep HMS_POID HMS_PIID AGGR_NAME &TOTAL_COUNT. &MDCR_COUNT. &TOTAL_FRAC_COUNT. &MDCR_FRAC_COUNT.;
run;

proc sort data=Doc_Org_State;
by HMS_POID;
run;

/*
data PIID_State_migr_poid;
merge migrate_poids Doc_Org_State(in=a);
by HMS_POID;
if a;
if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
else if poid_migration_status ~= '' then delete;
drop poid_migration_status new_POID;
run;

data migrate_piids;
set inputs.piidmigr_&Vintage.(rename=(HMS_PIID=NEW_PIID));
HMS_PIID = OLD_PIID;
drop OLD_PIID;
run;

proc sort data=Doc_Org_State;
by HMS_PIID;
run;

proc sort data=migrate_piids;
by HMS_PIID;
run;
data PIID_State_migr;
merge migrate_piids PIID_State_migr_poid(in=a);
by HMS_PIID;
if a;
if piid_migration_status = 'MOVED' then HMS_PIID = NEW_PIID;
else if piid_migration_status ~= '' then HMS_PIID = '';
drop piid_migration_status NEW_PIID;
run;
*/

proc means data=Doc_Org_State sum noprint nway;
class HMS_POID HMS_PIID AGGR_NAME / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=PIID_State_sum(drop=_TYPE_ _FREQ_)
sum=&TOTAL_COUNT._st &MDCR_COUNT._st;
run;

data PIID_State_sum;
set PIID_State_sum;
if HMS_POID = 'NULL' then delete;
else if HMS_POID = 'MISSING' then delete;
if HMS_PIID = 'MISSING' then delete;
run;

data Doc_Org_UB;
length HMS_POID $10.;
length HMS_PIID $10.;
set Doc_Org_counts;
where AGGR_NAME = 'WKUB_ASC';
if ORG_ID = 'NULL' then delete;
else if ORG_ID = 'MISSING' then delete;
if DOC_ID = 'MISSING' then delete;
HMS_POID = ORG_ID;
HMS_PIID = DOC_ID;
keep HMS_PIID HMS_POID AGGR_NAME &TOTAL_COUNT. &MDCR_COUNT.;
run;

proc sort data=Doc_Org_UB;
by HMS_POID;
run;

/*
data Doc_Org_UB_poidmigr;
merge migrate_poids Doc_Org_UB(in=a);
by HMS_POID;
if a;
if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
else if poid_migration_status ~= '' then delete;
drop poid_migration_status new_POID;
run;

proc sort data=Doc_Org_UB_poidmigr;
by HMS_PIID;
run;

data Doc_Org_UB_migr;
merge migrate_piids Doc_Org_UB_poidmigr(in=a);
by HMS_PIID;
if a;
if piid_migration_status = 'MOVED' then HMS_PIID = NEW_PIID;
else if piid_migration_status ~= '' then HMS_PIID = '';
drop piid_migration_status NEW_PIID;
run;
*/

proc means data=Doc_Org_UB sum noprint nway;
class HMS_POID HMS_PIID / missing;
var &TOTAL_COUNT. &MDCR_COUNT.;
output out=Doc_Org_UB_sum(drop=_TYPE_ _FREQ_)
sum=&TOTAL_COUNT._ub &MDCR_COUNT._ub;
run;

/* Use Org Type to eliminate non-ASCs from 1500 data */
data ORG_TYPE;
set inputs.asc_poids_&Vintage.;
run;
data POID_est;
set ASC.All_sources_scored;
POID_EST = FINAL_FACILITY_COUNT;
keep HMS_POID POID_EST;
run;
proc sort data=ORG_TYPE;
by HMS_POID;
run;
proc sort data=POID_est(keep=HMS_POID) out=POID_ascstep;
by HMS_POID;
run;
data ORG_TYPE_ASC;
merge ORG_TYPE POID_ascstep matrix(keep=HMS_POID);
by HMS_POID;
run;

proc sort data=piid_at_poid_predictions;
by HMS_POID;
run;
proc sort data=ORG_TYPE_ASC;
by HMS_POID;
run;
data Doc_Org_1500_amb;
merge piid_at_poid_predictions(in=a) ORG_TYPE_ASC(in=b);
by HMS_POID;
if a and b;
run;


proc sort data=PIID_State_sum;
by HMS_POID HMS_PIID;
run;
proc sort data=Doc_Org_UB_sum;
by HMS_POID HMS_PIID;
run;
proc sort data=Doc_Org_1500_amb;
by HMS_POID HMS_PIID;
run;

/* Select appropriate count */
data PIID_Selection;
merge PIID_State_sum(in=a) Doc_Org_UB_sum(in=b) Doc_Org_1500_amb(in=c);
by HMS_POID HMS_PIID;
drop AGGR_NAME;
Doc_Cnt = max(&TOTAL_COUNT._st,&TOTAL_COUNT._ub,est_at_poid);
run;

data fracs;
set PIID_Selection;
keep HMS_POID Doc_Cnt;
run;
proc means data=fracs noprint sum nway;
class HMS_POID / missing;
var Doc_Cnt;
output out=frac_sums(drop=_FREQ_ _TYPE_) sum=doc_sum;
run;

proc sort data=frac_sums;
by HMS_POID;
run;
proc sort data=ASC.All_sources_scored;
by HMS_POID;
run;
proc sort data=PIID_Selection;
by HMS_POID;
run;

/* Establish 99th percentile */
proc univariate data=ASC.All_sources_scored noprint;
var FINAL_FACILITY_COUNT;
output out=temp p99=p99;
run;
%let P99 = 1000; /* Initialize in case of empty set */
data _null_;
set temp;
call symput('P99',round(p99*.25,1));
run;
%put P99 = &P99;

data PIIDPOID_Selection;
merge PIID_Selection ASC.All_sources_scored(in=a keep=HMS_POID FINAL_FACILITY_COUNT) frac_sums;
by HMS_POID;
*if a;
if doc_sum = . then POID_COUNT = FINAL_FACILITY_COUNT;
else if doc_sum <= FINAL_FACILITY_COUNT then POID_COUNT = FINAL_FACILITY_COUNT;
/* MODIFICATION 4.25.2017 - output doc sum where that sum exceeds the poid count */
else POID_COUNT = ceil(doc_sum);
/*else if doc_sum/FINAL_FACILITY_COUNT < 20 then POID_COUNT = ceil(doc_sum);
else if doc_sum-FINAL_FACILITY_COUNT < &P99. then POID_COUNT = ceil(doc_sum);
else POID_COUNT = FINAL_FACILITY_COUNT;
flag_record = (doc_sum/FINAL_FACILITY_COUNT > 1.25 and frac_sum-FINAL_FACILITY_COUNT >= &P99.);*/
run;

data PIIDPOID_final;
set PIIDPOID_Selection;
PIID_COUNT=Doc_Cnt;
keep HMS_POID HMS_PIID POID_COUNT PIID_COUNT;
run;


/* Split up into five columns needed */
proc means data=PIIDPOID_final sum nway noprint;
class HMS_PIID / missing;
var PIID_COUNT;
output out=piid_final_sum(drop=_FREQ_ _TYPE_) sum=piid_sum;
run;
proc sort data=PIIDPOID_final nodupkey out=poid_final_sum;
by HMS_POID;
run;
data poid_final_sum;
set poid_final_sum;
keep HMS_POID POID_COUNT;
run;

proc sort data=PIIDPOID_final;
by HMS_PIID;
run;
proc sort data=piid_final_sum;
by HMS_PIID;
run;
data temp1;
merge PIIDPOID_final piid_final_sum;
by HMS_PIID;
run;

proc sort data=temp1;
by HMS_POID;
run;
proc sort data=poid_final_sum;
by HMS_POID;
run;
data temp2;
length HMS_POID $10.;
merge temp1 poid_final_sum;
by HMS_POID;
run;

data ASC.asc_projections;
set temp2;
PractFacProjCount = PIID_COUNT;
PractNatlProjCount = piid_sum;
FacProjCount = POID_COUNT;
drop PIID_COUNT piid_sum POID_COUNT;
run;

/* Modification 3/21/2017: No longer deleting records with a POID that has no name/address */
/* Final Step - null out POIDs that have no name or no address */
/* Must keep PIIDs that don't have POIDs */
data piids_w_poids;
set ASC.asc_projections;
where HMS_POID ~= '';
run;
data piids_wo_poids;
set ASC.asc_projections;
where HMS_POID = '';
run;

/*proc sort data=inputs.orginfo_&vintage. out=good_orgs(keep=HMS_POID);
by HMS_POID;
run;*/
data piids_w_poids;
merge piids_w_poids(in=a) inputs.orginfo_&vintage.(in=b keep=HMS_POID); /* orginfo must be sorted by poid */
by HMS_POID;
if a;
if not b then HMS_POID = '';
run;

data allpreds;
set piids_w_poids piids_wo_poids;
run;

/* Need to sum in case a PIID has no POID and a nulled-out POID */
/* MODIFICATION 7.24.2018: Corrected to sum only at PIID-POID level */
proc means data=allpreds noprint nway sum;
class HMS_POID HMS_PIID / missing;
var PractFacProjCount;
output out=allpreds_sum(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=allpreds nodupkey out=allpreds_poid;
by HMS_POID FacProjCount;
run;
proc means data=allpreds_poid noprint nway sum;
class HMS_POID / missing;
var FacProjCount;
output out=allpreds_poid_sum(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=allpreds nodupkey out=allpreds_piid;
by HMS_PIID PractNatlProjCount;
run;
proc means data=allpreds_piid noprint nway sum;
class HMS_PIID / missing;
var PractNatlProjCount;
output out=allpreds_piid_sum(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=allpreds_sum;
by HMS_PIID;
run;
proc sort data=allpreds_piid_sum;
by HMS_PIID;
run;
proc sort data=allpreds_poid_sum;
by HMS_POID;
run;

data allpreds1;
merge allpreds_sum allpreds_piid_sum;
by HMS_PIID;
run;
proc sort data=allpreds1;
by HMS_POID;
run;

data ASC.asc_projections;
merge allpreds1 allpreds_poid_sum;
by HMS_POID;
run;

proc sort data=ASC.asc_projections;
by HMS_POID HMS_PIID;
run;

proc export data=ASC.asc_projections outfile='asc_projections.txt' replace;
run;

/* MODIFICATION 3.18.2018: New file formats */

data temp;
set ASC.asc_projections;
if HMS_POID = '' then HMS_POID = 'MISSING';
if HMS_PIID = '' then HMS_PIID = 'MISSING';
run;

proc means data=temp nway sum noprint;
class HMS_PIID / missing;
var PractFacProjCount;
output out=prac_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc means data=temp nway sum noprint;
class HMS_POID / missing;
var PractFacProjCount;
output out=org_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc means data=temp nway sum noprint;
class HMS_PIID HMS_POID / missing;
var PractFacProjCount;
output out=prac_org_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc export data=prac_proj outfile='prac_proj.txt' replace;
run;
proc export data=org_proj outfile='org_proj.txt' replace;
run;
proc export data=prac_org_proj outfile='prac_org_proj.txt' replace;
run;

/* **************************************** END OF LINE *************************************** */

options mprint;

/* Read in inputs file */
data inputs(compress=yes);
infile '../inputs.txt' delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
	informat PARAMETER $100. ;
	informat VALUE $200. ;
	format PARAMETER $100. ;
	format VALUE $200. ;
input PARAMETER $ VALUE $;
run;

/* Set default DB credentials */
%let USERNAME = claims_aggr;
%let PASSWORD = Hydr0gen2014;
%let INSTANCE = PLDWH2DBR;

data _null_;
set inputs;

if PARAMETER = 'USERNAME' then do;
	if VALUE ~= '' then call symput('USERNAME', trim(left(compress(value))));
end;
if PARAMETER = 'PASSWORD' then do;
	if VALUE ~= '' then call symput('PASSWORD', trim(left(compress(value))));
end;
if PARAMETER = 'INSTANCE' then do;
	if VALUE ~= '' then call symput('INSTANCE', trim(left(compress(value))));
end;
if PARAMETER = 'START_DATE' then call symput('start_date',trim(left(compress(value))));
if PARAMETER = 'MAX_DATE' then call symput('max_date',trim(left(compress(value))));
if PARAMETER = 'VINTAGE' then call symput ("vintage",trim(left(compress(value))));
if PARAMETER = 'PERIOD' then do;
if VALUE = 'WEEK' then call symput('week_flag',1);
else if VALUE = 'MONTH' then call symput('week_flag',2);
else if VALUE = 'YEAR' then call symput('week_flag',3);
end;
if PARAMETER = 'QA' then call symput('QA',trim(left(compress(value))));;

run;

%let facility = 0;
%let practitioner = 0;
data _null_;
set inputs;

if PARAMETER = 'FACILITY' then do;
	if VALUE = 'Y' then call symput('facility',1);
	else call symput('facility',0);
end;

if PARAMETER = 'PRACTITIONER' then do;
	if VALUE = 'Y' then call symput('practitioner',1);
	else call symput('practitioner',0);
end;

run;
%put &facility.;
%put &practitioner.;
%put &USERNAME.;
%put &PASSWORD.;
%put &INSTANCE.;

data roles;
set inputs;
where PARAMETER = 'ROLES';
keep VALUE;
run;

data role_array;
set roles;
array parsed(*) role1-role5 _char_;

i=1;
do while(scan(VALUE, i, ",")~="");
parsed(i)=scan(VALUE, i, ",");
i+1;
end;

drop VALUE i;
run;

proc transpose data=role_array out=role_list;
var role1-role5;
run;

data role_list;
set role_list;
role = COL1;
if role = '' then delete;
keep role;
run;

data role_list;
set role_list;
if role = 'ATTENDING' then do;
	ROLE_ID = 1;
	ROLE_TYPE = 'INST';
end;
else if role = 'OPERATING' then do;
	ROLE_ID = 2;
	ROLE_TYPE = 'INST';
end;
else if role = 'OTHER' then do;
	ROLE_ID = 3;
	ROLE_TYPE = 'INST';
end;
else if role = 'RENDERING' then do;
	ROLE_ID = 5;
	ROLE_TYPE = 'PROF';
end;
else if role = 'REFERRING' then do;
	ROLE_ID = 6;
	ROLE_TYPE = 'PROF';
end;
keep ROLE_ID ROLE_TYPE;
run;

proc sql;
create table role_count as select count(*) as roles from role_list;
quit;
data _null_;
set role_count;
call symput('ROLES',trim(left(compress(roles))));
run;
%put &ROLES.;

data role_list_default;
input ROLE_ID 1. ROLE_TYPE $4.;
datalines;
0BOTH
1INST
2INST
3INST
5PROF
6PROF
;
run; 

data role_list_zero;
input ROLE_ID 1. ROLE_TYPE $4.;
datalines;
0BOTH
;
run; 

%macro role_count;
%if &ROLES. = 0 %then %do;
data role_list;
set role_list_default;
run; 
%end;
%else %do;
data role_list;
set role_list_zero role_list;
run; 
%end;
%mend;
%role_count;

data vendors;
set inputs;
where PARAMETER = 'INCLUDE';
keep VALUE;
run;

data vendor_array;
set vendors;
array parsed(*) vendor1-vendor10 _char_;

i=1;
do while(scan(VALUE, i, ",")~="");
parsed(i)=scan(VALUE, i, ",");
i+1;
end;

drop VALUE i;
run;

proc transpose data=vendor_array out=vendor_list;
var vendor1-vendor10;
run;

data vendor_list;
set vendor_list;
vendor = COL1;
if vendor = '' then delete;
keep vendor;
run;

data vendor_list_masked;
set vendor_list;
where substr(vendor,1,3) ~= 'CMS';
run;
data vendor_list_exempt;
set vendor_list;
where substr(vendor,1,3) = 'CMS';
run;

%put _USER_;

/* Read in inputs file */
data buckets_co(compress=yes);
infile '../buckets_co.txt'
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
	informat CODE $15. ;
	informat SCHEME $10. ;
	informat TYPE $2. ;
	informat BUCKET $100. ;
	format CODE $15. ;
	format SCHEME $10. ;
	format TYPE $2. ;
	format BUCKET $100. ;
input CODE $ SCHEME $ TYPE $ BUCKET $ ;
run;

data buckets_co;
set buckets_co;
CODE = compress(CODE,'.');
run;

proc sort data=buckets_co;
by TYPE BUCKET;
run;
proc sort data=buckets_co nodupkey out=just_buckets_co;
by TYPE BUCKET;
run;
data just_buckets_co;
set just_buckets_co;
num=_n_;
call symput('bucket_'||left(_N_),BUCKET);
call symput('type_'||left(_N_),TYPE);
run;
data buckets_co;
merge buckets_co just_buckets_co;
by TYPE BUCKET;
run;

/* Generate 4-digit random table suffix to avoid overwrite existing table in Oracle */
data _null_;
call symput ("rand_digit", put(ranuni(0)*10000,Z4.));
run;

libname pe oracle user=&USERNAME. password=&PASSWORD. path=&INSTANCE.;
proc delete data=PE.trend_buckets_&rand_digit.;
run;
/* Import codes to Oracle */
data pe.trend_buckets_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.buckets_co;
run ;

proc delete data=PE.trend_vendors_exempt_&rand_digit.;
run;
/* Import vendor list to Oracle */
data pe.trend_vendors_exempt_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.vendor_list_exempt;
run ;
proc delete data=PE.trend_vendors_masked_&rand_digit.;
run;
/* Import vendor list to Oracle */
data pe.trend_vendors_masked_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.vendor_list_masked;
run ;

proc delete data=PE.trend_roles_&rand_digit.;
run;
/* Import vendor list to Oracle */
data pe.trend_roles_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.role_list;
run ;

/* This section deals with the setting filter */
data settings_all;
length SETTING $200.;
set inputs;
SETTING = 'ALL';
where PARAMETER = 'SETTING' and VALUE in ('ALL','');
keep SETTING;
run;

data setting;
set inputs;
where PARAMETER = 'SETTING';
SETTING1 = scan(VALUE,1,',');
SETTING2 = scan(VALUE,2,',');
SETTING3 = scan(VALUE,3,',');
SETTING4 = scan(VALUE,4,',');
SETTING5 = scan(VALUE,5,',');
SETTING6 = scan(VALUE,6,',');
SETTING7 = scan(VALUE,7,',');
SETTING8 = scan(VALUE,8,',');
SETTING9 = scan(VALUE,9,',');
keep SETTING1-SETTING9;
run;
proc transpose data=setting out=settings;
var SETTING1-SETTING9;
run;
data settings;
set settings;
SETTING = COL1;
if COL1 = '' then delete;
keep SETTING;
run;
data settings;
set settings settings_all;
run;

data settings_asc;
set settings;
where SETTING = 'ASC';
	BILL_CODE = 22; /* As it appears in claimswh.bill_classifications */
	POS_CODE = 24;
run;
data settings_hha;
set settings;
where SETTING = 'HHA';
	BILL_CODE = 10; /* As it appears in claimswh.bill_classifications */
run;
data settings_home;
set settings;
where SETTING = 'HOME';
	POS_CODE = 12;
run;
data settings_ip;
set settings;
where SETTING = 'IP';
	BILL_CODE = 1; /* As it appears in claimswh.bill_classifications */
	POS_CODE = 21;
run;
data settings_op1;
set settings;
where SETTING = 'OP';
	BILL_CODE = 3; /* As it appears in claimswh.bill_classifications */
	POS_CODE = 22;
run;
data settings_op2;
set settings;
where SETTING = 'OP';
	POS_CODE = 19; /* New code added 7.11.2018 */
run;
data settings_lab;
set settings;
where SETTING = 'LAB';
	POS_CODE = 81;
run;
data settings_snf;
set settings;
where SETTING = 'SNF';
	BILL_CODE = 6; /* As it appears in claimswh.bill_classifications */
	POS_CODE = 31;
run;
data settings_office;
set settings;
where SETTING = 'OFFICE';
	POS_CODE = 11;
run;

data settings_main;
set settings_all settings_asc settings_hha settings_home settings_ip
settings_op1 settings_op2 settings_lab settings_snf settings_office;
run;

data settings_all_bill;
do BILL_CODE = 0 to 99;
output;
end;
run;
data settings_other_bill;
length SETTING $200.;
set settings_all_bill;
if BILL_CODE in (22,10,1,6,3) then delete;
SETTING = 'OTHER';
run;
data settings_all_bill;
length SETTING $200.;
set settings_all_bill;
SETTING = 'ALL';
run;

data settings_all_pos;
do POS_CODE = 0 to 99;
output;
end;
run;
data settings_other_pos;
length SETTING $200.;
set settings_all_pos;
if POS_CODE in (24,12,21,81,31,11,22,19) then delete;
SETTING = 'OTHER';
run;
data settings_all_pos;
length SETTING $200.;
set settings_all_pos;
SETTING = 'ALL';
run;

proc sort data=settings_main;
by SETTING;
run;
data settings_total;
merge settings_main(in=a) settings_other_bill settings_all_bill settings_other_pos settings_all_pos;
by SETTING;
if a;
run;

data settings_bill;
set settings_total;
where BILL_CODE ~= .;
keep BILL_CODE;
run;
data settings_pos;
set settings_total;
where POS_CODE ~= .;
keep POS_CODE;
run;

proc delete data=PE.trend_bill_&rand_digit.;
run;
data pe.trend_bill_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.settings_bill;
run ;
proc delete data=PE.trend_pos_&rand_digit.;
run;
data pe.trend_pos_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.settings_pos;
run ;

/* Read in co-occur file */
data cooccur(compress=yes);
infile '../cooccur.txt' delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
	informat BUCKET1 $100. ;
	informat TYPE1 $2. ;
	informat BUCKET2 $100. ;
	informat TYPE2 $2. ;
	informat COUNTING $10. ;
	format BUCKET1 $100. ;
	format TYPE1 $2. ;
	format BUCKET2 $100. ;
	format TYPE2 $2. ;
	format COUNTING $10. ;
input BUCKET1 $ TYPE1 $ BUCKET2 $ TYPE2 $ COUNTING $;
run;

data cooccur;
set cooccur;
num=_n_;
call symput('bucket1_'||left(_N_),BUCKET1);
call symput('type1_'||left(_N_),TYPE1);
call symput('bucket2_'||left(_N_),BUCKET2);
call symput('type2_'||left(_N_),TYPE2);
call symput('counting_'||left(_N_),COUNTING);
run;

proc sort data=cooccur nodupkey out=just_bucket1(keep=BUCKET1 TYPE1 COUNTING);
by BUCKET1 TYPE1 COUNTING;
run;
proc sort data=cooccur nodupkey out=just_bucket2(keep=BUCKET2 TYPE2 COUNTING);
by BUCKET2 TYPE2 COUNTING;
run;

proc delete data=PE.trend_bucket1_&rand_digit.;
run;
proc delete data=PE.trend_bucket2_&rand_digit.;
run;
/* Import defined buckets to Oracle */
data pe.trend_bucket1_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.just_bucket1;
run ;
data pe.trend_bucket2_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.just_bucket2;
run ;
quit;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

	create table pe.trend_job_pxdx_&rand_digit.
		(BUCKET1 varchar(200), BUCKET2 varchar(200), COUNTING varchar(20), CLAIM_ID num(30), CLAIM_DATE num(20),
		HMS_POID varchar(80), HMS_PIID varchar(80), COUNT_ID varchar(255)
		);
	create table pe.trend_job_dxdx_&rand_digit.
		(BUCKET1 varchar(200), BUCKET2 varchar(200), COUNTING varchar(20), CLAIM_ID num(30), CLAIM_DATE num(20),
		HMS_POID varchar(80), HMS_PIID varchar(80), COUNT_ID varchar(255)
		);
	create table pe.trend_job_pxpx_&rand_digit.
		(BUCKET1 varchar(200), BUCKET2 varchar(200), COUNTING varchar(20), CLAIM_ID num(30), CLAIM_DATE num(20),
		HMS_POID varchar(80), HMS_PIID varchar(80), COUNT_ID varchar(255)
		);
	create table pe.trend_job_px1_&rand_digit.
		(BUCKET1 varchar(200), COUNTING varchar(20), CLAIM_ID num(30), CLAIM_DATE num(20),
		HMS_POID varchar(80), HMS_PIID varchar(80), COUNT_ID varchar(255)
		);
	create table pe.trend_job_px2_&rand_digit.
		(BUCKET2 varchar(200), COUNTING varchar(20), CLAIM_ID num(30), CLAIM_DATE num(20),
		HMS_POID varchar(80), HMS_PIID varchar(80), COUNT_ID varchar(255)
		);

quit;


%macro pull(vendorlist=, xwalk=);

/* Pull the data */
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PROF_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.prof_claim_procs a,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.LINE_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.CLAIM_DIAG_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.CLAIM_PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PROF_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.prof_claim_procs a,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.LINE_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.CLAIM_DIAG_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.CLAIM_PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PATIENT_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PATIENT_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.INST_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.inst_claim_procs a,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.CLAIM_DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.INST_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.inst_claim_procs a,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.CLAIM_DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PATIENT_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and px.BUCKET=b1.BUCKET1
		and dx.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PATIENT_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg,
		claimswh.procedures p,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg.PROCEDURE_GROUP_ID
		and pg.PROCEDURE_ID=p.PROCEDURE_ID
		and p.ADDNL_PROCEDURE_CODE=px.CODE and p.CODE_SCHEME=px.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=dx.CODE and d.CODE_SCHEME=dx.SCHEME
		and dx.BUCKET=b1.BUCKET1
		and px.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

		execute(insert /*+ append */ into trend_job_pxpx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg1,
		claimswh.procedures p1,
		claimswh.procedure_group_members pg2,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg1.PROCEDURE_GROUP_ID
		and pg1.PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and a.PROCEDURE_GROUP_ID=pg2.PROCEDURE_GROUP_ID
		and pg2.PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxpx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members pg1,
		claimswh.procedures p1,
		claimswh.procedure_group_members pg2,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg1.PROCEDURE_GROUP_ID
		and pg1.PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and a.PROCEDURE_GROUP_ID=pg2.PROCEDURE_GROUP_ID
		and pg2.PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxpx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg1,
		claimswh.procedures p1,
		claimswh.procedure_group_members pg2,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg1.PROCEDURE_GROUP_ID
		and pg1.PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and a.PROCEDURE_GROUP_ID=pg2.PROCEDURE_GROUP_ID
		and pg2.PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_pxpx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members pg1,
		claimswh.procedures p1,
		claimswh.procedure_group_members pg2,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'px') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.PROCEDURE_GROUP_ID=pg1.PROCEDURE_GROUP_ID
		and pg1.PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and a.PROCEDURE_GROUP_ID=pg2.PROCEDURE_GROUP_ID
		and pg2.PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

		execute(insert /*+ append */ into trend_job_dxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.diagnosis_group_members dg1,
		claimswh.diagnosis d1,
		claimswh.diagnosis_group_members dg2,
		claimswh.diagnosis d2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.DIAGNOSIS_GROUP_ID=dg1.DIAGNOSIS_GROUP_ID
		and dg1.DIAGNOSIS_ID=d1.DIAGNOSIS_ID
		and d1.ADDNL_DIAGNOSIS_CODE=dx1.CODE and d1.CODE_SCHEME=dx1.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg2.DIAGNOSIS_GROUP_ID
		and dg2.DIAGNOSIS_ID=d2.DIAGNOSIS_ID
		and d2.ADDNL_DIAGNOSIS_CODE=dx2.CODE and d2.CODE_SCHEME=dx2.SCHEME
		and dx1.BUCKET=b1.BUCKET1
		and dx2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_dxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		PATIENT_ID as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.diagnosis_group_members dg1,
		claimswh.diagnosis d1,
		claimswh.diagnosis_group_members dg2,
		claimswh.diagnosis d2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.DIAGNOSIS_GROUP_ID=dg1.DIAGNOSIS_GROUP_ID
		and dg1.DIAGNOSIS_ID=d1.DIAGNOSIS_ID
		and d1.ADDNL_DIAGNOSIS_CODE=dx1.CODE and d1.CODE_SCHEME=dx1.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg2.DIAGNOSIS_GROUP_ID
		and dg2.DIAGNOSIS_ID=d2.DIAGNOSIS_ID
		and d2.ADDNL_DIAGNOSIS_CODE=dx2.CODE and d2.CODE_SCHEME=dx2.SCHEME
		and dx1.BUCKET=b1.BUCKET1
		and dx2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_dxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.diagnosis_group_members dg1,
		claimswh.diagnosis d1,
		claimswh.diagnosis_group_members dg2,
		claimswh.diagnosis d2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'CLAIM' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'CLAIM' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.DIAGNOSIS_GROUP_ID=dg1.DIAGNOSIS_GROUP_ID
		and dg1.DIAGNOSIS_ID=d1.DIAGNOSIS_ID
		and d1.ADDNL_DIAGNOSIS_CODE=dx1.CODE and d1.CODE_SCHEME=dx1.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg2.DIAGNOSIS_GROUP_ID
		and dg2.DIAGNOSIS_ID=d2.DIAGNOSIS_ID
		and d2.ADDNL_DIAGNOSIS_CODE=dx2.CODE and d2.CODE_SCHEME=dx2.SCHEME
		and dx1.BUCKET=b1.BUCKET1
		and dx2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_dxdx_&rand_digit.(BUCKET1,BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b2.BUCKET2, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		PATIENT_ID as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.diagnosis_group_members dg1,
		claimswh.diagnosis d1,
		claimswh.diagnosis_group_members dg2,
		claimswh.diagnosis d2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx1,
		(select * from trend_buckets_&rand_digit. where TYPE = 'dx') dx2,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PATIENT' and TYPE1 = 'dx') b1,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PATIENT' and TYPE2 = 'dx') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.DIAGNOSIS_GROUP_ID=dg1.DIAGNOSIS_GROUP_ID
		and dg1.DIAGNOSIS_ID=d1.DIAGNOSIS_ID
		and d1.ADDNL_DIAGNOSIS_CODE=dx1.CODE and d1.CODE_SCHEME=dx1.SCHEME
		and a.DIAGNOSIS_GROUP_ID=dg2.DIAGNOSIS_GROUP_ID
		and dg2.DIAGNOSIS_ID=d2.DIAGNOSIS_ID
		and d2.ADDNL_DIAGNOSIS_CODE=dx2.CODE and d2.CODE_SCHEME=dx2.SCHEME
		and dx1.BUCKET=b1.BUCKET1
		and dx2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

/* For special cases where pxpx jobs are counting procedures */
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

		execute(insert /*+ append */ into trend_job_px1_&rand_digit.(BUCKET1,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PROF_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.prof_claim_procs a,
		claimswh.procedures p1,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'px') b1
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.LINE_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.CLAIM_PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px1_&rand_digit.(BUCKET1,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET1, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b1.BUCKET1, b1.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.INST_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.inst_claim_procs a,
		claimswh.procedures p1,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px1,
		(select * from trend_bucket1_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE1 = 'px') b1
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p1.PROCEDURE_ID
		and p1.ADDNL_PROCEDURE_CODE=px1.CODE and p1.CODE_SCHEME=px1.SCHEME
		and px1.BUCKET=b1.BUCKET1
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

		execute(insert /*+ append */ into trend_job_px2_&rand_digit.(BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b2.BUCKET2, b2.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PROF_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.prof_claim_procs a,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.LINE_POS_ID=s.POS_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.CLAIM_PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px2_&rand_digit.(BUCKET2,COUNTING,CLAIM_ID,CLAIM_DATE,
		HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET2, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select b2.BUCKET2, b2.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.INST_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.inst_claim_procs a,
		claimswh.procedures p2,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.&xwalk. pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&vendorlist._&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where TYPE = 'px') px2,
		(select * from trend_bucket2_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE2 = 'px') b2
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_PROCEDURE_ID=p2.PROCEDURE_ID
		and p2.ADDNL_PROCEDURE_CODE=px2.CODE and p2.CODE_SCHEME=px2.SCHEME
		and px2.BUCKET=b2.BUCKET2
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

%mend;

%pull(vendorlist=masked, xwalk=practitioner_id_crosswalk_masked);
%pull(vendorlist=exempt, xwalk=practitioner_id_crosswalk);

%put &facility.;
%put &practitioner.;
%macro trend_count;  

%if &facility. = 0 & &practitioner. = 0 %then %do;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

	create table buckets_pxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxdx_&rand_digit. a);

	create table buckets_pxpx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxpx_&rand_digit. a);

	create table buckets_dxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_dxdx_&rand_digit. a);

	create table buckets_pxpx_proc as 
	select *
	from connection to oracle
		(select a.BUCKET1, b.BUCKET2, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_px1_&rand_digit. a, trend_job_px2_&rand_digit. b
		where a.CLAIM_ID=b.CLAIM_ID);

disconnect from oracle ;
quit ;

%end;

%else %if &facility. = 1 & &practitioner. = 0 %then %do;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

	create table buckets_pxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxdx_&rand_digit. a);

	create table buckets_pxpx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxpx_&rand_digit. a);

	create table buckets_dxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_dxdx_&rand_digit. a);

	create table buckets_pxpx_proc as 
	select *
	from connection to oracle
		(select a.BUCKET1, b.BUCKET2, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_px1_&rand_digit. a, trend_job_px2_&rand_digit. b
		where a.CLAIM_ID=b.CLAIM_ID);

disconnect from oracle ;
quit ;

%end;

%else %if &facility. = 0 & &practitioner. = 1 %then %do;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

	create table buckets_pxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxdx_&rand_digit. a);

	create table buckets_pxpx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxpx_&rand_digit. a);

	create table buckets_dxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_dxdx_&rand_digit. a);

	create table buckets_pxpx_proc as 
	select *
	from connection to oracle
		(select a.BUCKET1, b.BUCKET2, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_px1_&rand_digit. a, trend_job_px2_&rand_digit. b
		where a.CLAIM_ID=b.CLAIM_ID);

disconnect from oracle ;
quit ;

%end;

%else %if &facility. = 1 & &practitioner. = 1 %then %do;

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE. PRESERVE_COMMENTS) ;

	create table buckets_pxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxdx_&rand_digit. a);

	create table buckets_pxpx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_pxpx_&rand_digit. a);

	create table buckets_dxdx as 
	select *
	from connection to oracle
		(select a.BUCKET1, a.BUCKET2, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_dxdx_&rand_digit. a);

	create table buckets_pxpx_proc as 
	select *
	from connection to oracle
		(select a.BUCKET1, b.BUCKET2, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
		from trend_job_px1_&rand_digit. a, trend_job_px2_&rand_digit. b
		where a.CLAIM_ID=b.CLAIM_ID);

disconnect from oracle ;
quit ;

%end;

proc sort data=cooccur nodupkey out=cobuckets(keep=BUCKET1 BUCKET2);
by BUCKET1 BUCKET2;
run;
proc sort data=buckets_pxdx;
by BUCKET1 BUCKET2;
run;
proc sort data=buckets_pxpx;
by BUCKET1 BUCKET2;
run;
proc sort data=buckets_dxdx;
by BUCKET1 BUCKET2;
run;
proc sort data=buckets_pxpx_proc;
by BUCKET1 BUCKET2;
run;

data buckets_pxdx;
merge buckets_pxdx(in=a) cobuckets(in=b);
by BUCKET1 BUCKET2;
if a and b;
run;
data buckets_pxpx;
merge buckets_pxpx(in=a) cobuckets(in=b);
by BUCKET1 BUCKET2;
if a and b;
run;
data buckets_dxdx;
merge buckets_dxdx(in=a) cobuckets(in=b);
by BUCKET1 BUCKET2;
if a and b;
run;
data buckets_pxpx_proc;
merge buckets_pxpx_proc(in=a) cobuckets(in=b);
by BUCKET1 BUCKET2;
if a and b;
run;

%if &week_flag = 1 %then %do;

data buckets_pxdx1;
set buckets_pxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_pxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_pxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK
	order by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK;
quit ;

data buckets_pxpx1;
set buckets_pxpx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_pxpx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK
	order by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK;
quit ;

data buckets_dxdx1;
set buckets_dxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_dxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_dxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK
	order by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK;
quit ;

data buckets_pxpx_proc1;
set buckets_pxpx_proc;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_pxpx_proc2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx_proc1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK
	order by BUCKET1, BUCKET2, COUNTING, YEAR, WEEK;
quit ;

/* Add in Week Of */
data weekdays;
do DATE = 1262304000 to 1924992000 by 86400;
YEAR = YEAR(datepart(DATE));
MONTH = MONTH(datepart(DATE));
WEEK = WEEK(datepart(DATE),'u');
DAY = DAY(datepart(DATE));
if WEEKDAY(datepart(DATE)) = 1 then WEEKDAY = 'Sunday   ';
else if WEEKDAY(datepart(DATE)) = 2 then WEEKDAY = 'Monday   ';
else if WEEKDAY(datepart(DATE)) = 3 then WEEKDAY = 'Tuesday  ';
else if WEEKDAY(datepart(DATE)) = 4 then WEEKDAY = 'Wednesday';
else if WEEKDAY(datepart(DATE)) = 5 then WEEKDAY = 'Thursday ';
else if WEEKDAY(datepart(DATE)) = 6 then WEEKDAY = 'Friday   ';
else if WEEKDAY(datepart(DATE)) = 7 then WEEKDAY = 'Saturday ';
output;
end;
run;
data weekdays1;
set weekdays;
by YEAR WEEK;
if first.week = 1;
WEEK_OF = trim(WEEKDAY)||','||trim(left(MONTH))||'/'||trim(left(DAY))||'/'||trim(left(YEAR));
keep YEAR MONTH DAY WEEK WEEK_OF;
run;

proc sort data=buckets_pxdx2;
by YEAR WEEK;
run;
data buckets_pxdx3;
merge buckets_pxdx2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_pxdx4 as
select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxdx3;
quit;

proc sort data=buckets_pxpx2;
by YEAR WEEK;
run;
data buckets_pxpx3;
merge buckets_pxpx2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_pxpx4 as
select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx3;
quit;

proc sort data=buckets_dxdx2;
by YEAR WEEK;
run;
data buckets_dxdx3;
merge buckets_dxdx2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_dxdx4 as
select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dxdx3;
quit;

proc sort data=buckets_pxpx_proc2;
by YEAR WEEK;
run;
data buckets_pxpx_proc3;
merge buckets_pxpx_proc2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_pxpx_proc4 as
select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx_proc3;
quit;

data buckets_all_co;
set buckets_pxdx4 buckets_pxpx4 buckets_dxdx4 buckets_pxpx_proc4;
run;

proc sort data=buckets_all_co;
by COUNTING BUCKET1 BUCKET2 YEAR MONTH DAY;
run;

	%if &facility. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxdx2_poid;
	by YEAR WEEK;
	run;
	data buckets_pxdx3_poid;
	merge buckets_pxdx2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxdx4_poid as
	select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxdx3_poid;
	quit;

	proc sql ;
		create table buckets_pxpx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxpx2_poid;
	by YEAR WEEK;
	run;
	data buckets_pxpx3_poid;
	merge buckets_pxpx2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxpx4_poid as
	select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx3_poid;
	quit;

	proc sql ;
		create table buckets_dxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_dxdx2_poid;
	by YEAR WEEK;
	run;
	data buckets_dxdx3_poid;
	merge buckets_dxdx2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_dxdx4_poid as
	select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dxdx3_poid;
	quit;

	proc sql ;
		create table buckets_pxpx_proc2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxpx_proc2_poid;
	by YEAR WEEK;
	run;
	data buckets_pxpx_proc3_poid;
	merge buckets_pxpx_proc2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxpx_proc4_poid as
	select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx_proc3_poid;
	quit;

	data buckets_all_co_poid;
	set buckets_pxdx4_poid buckets_pxpx4_poid buckets_dxdx4_poid buckets_pxpx_proc4_poid;
	run;

	proc sort data=buckets_all_co_poid;
	by COUNTING BUCKET1 BUCKET2 HMS_POID YEAR MONTH DAY;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxdx2_piid;
	by YEAR WEEK;
	run;
	data buckets_pxdx3_piid;
	merge buckets_pxdx2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxdx4_piid as
	select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxdx3_piid;
	quit;

	proc sql ;
		create table buckets_pxpx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxpx2_piid;
	by YEAR WEEK;
	run;
	data buckets_pxpx3_piid;
	merge buckets_pxpx2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxpx4_piid as
	select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx3_piid;
	quit;

	proc sql ;
		create table buckets_dxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_dxdx2_piid;
	by YEAR WEEK;
	run;
	data buckets_dxdx3_piid;
	merge buckets_dxdx2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_dxdx4_piid as
	select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dxdx3_piid;
	quit;

	proc sql ;
		create table buckets_pxpx_proc2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, WEEK;
	quit ;

	proc sort data=buckets_pxpx_proc2_piid;
	by YEAR WEEK;
	run;
	data buckets_pxpx_proc3_piid;
	merge buckets_pxpx_proc2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_pxpx_proc4_piid as
	select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_pxpx_proc3_piid;
	quit;

	data buckets_all_co_piid;
	set buckets_pxdx4_piid buckets_pxpx4_piid buckets_dxdx4_piid buckets_pxpx_proc4_piid;
	run;

	proc sort data=buckets_all_co_piid;
	by COUNTING BUCKET1 BUCKET2 HMS_POID YEAR MONTH DAY;
	run;

	%end;

%end;

%else %if &week_flag = 2 %then %do;

data buckets_pxdx1;
set buckets_pxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_pxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_pxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH
	order by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH;
quit ;

data buckets_pxpx1;
set buckets_pxpx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_pxpx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH
	order by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH;
quit ;

data buckets_dxdx1;
set buckets_dxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_dxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_dxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH
	order by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH;
quit ;

data buckets_pxpx_proc1;
set buckets_pxpx_proc;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_pxpx_proc2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx_proc1
	group by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH
	order by BUCKET1, BUCKET2, COUNTING, YEAR, MONTH;
quit ;

data buckets_all_co;
set buckets_pxdx2 buckets_pxpx2 buckets_dxdx2 buckets_pxpx_proc2;
run;

proc sort data=buckets_all_co;
by COUNTING BUCKET1 BUCKET2 YEAR MONTH;
run;

	%if &facility. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_pxpx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_dxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_pxpx_proc2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	data buckets_all_co_poid;
	set buckets_pxdx2_poid buckets_pxpx2_poid buckets_dxdx2_poid buckets_pxpx_proc2_poid;
	run;

	proc sort data=buckets_all_co_poid;
	by COUNTING BUCKET1 BUCKET2 HMS_POID YEAR MONTH;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_pxpx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_dxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_pxpx_proc2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	data buckets_all_co_piid;
	set buckets_pxdx2_piid buckets_pxpx2_piid buckets_dxdx2_piid buckets_pxpx_proc2_piid;
	run;

	proc sort data=buckets_all_co_piid;
	by COUNTING BUCKET1 BUCKET2 HMS_PIID YEAR MONTH;
	run;

	%end;

%end;

%else %if &week_flag = 3 %then %do;

data buckets_pxdx1;
set buckets_pxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_pxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_pxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR
	order by BUCKET1, BUCKET2, COUNTING, YEAR;
quit ;

data buckets_pxpx1;
set buckets_pxpx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_pxpx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR
	order by BUCKET1, BUCKET2, COUNTING, YEAR;
quit ;

data buckets_dxdx1;
set buckets_dxdx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_dxdx2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_dxdx1
	group by BUCKET1, BUCKET2, COUNTING, YEAR
	order by BUCKET1, BUCKET2, COUNTING, YEAR;
quit ;

data buckets_pxpx_proc1;
set buckets_pxpx_proc;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_pxpx_proc2 as 
	select BUCKET1, BUCKET2, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_pxpx_proc1
	group by BUCKET1, BUCKET2, COUNTING, YEAR
	order by BUCKET1, BUCKET2, COUNTING, YEAR;
quit ;

data buckets_all_co;
set buckets_pxdx2 buckets_pxpx2 buckets_dxdx2 buckets_pxpx_proc2;
run;

proc sort data=buckets_all_co;
by COUNTING BUCKET1 BUCKET2 YEAR;
run;

	%if &facility. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_pxpx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_dxdx2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_pxpx_proc2_poid as 
		select BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_POID, COUNTING, YEAR;
	quit ;

	data buckets_all_co_poid;
	set buckets_pxdx2_poid buckets_pxpx2_poid buckets_dxdx2_poid buckets_pxpx_proc2_poid;
	run;

	proc sort data=buckets_all_co_poid;
	by COUNTING BUCKET1 BUCKET2 HMS_POID YEAR;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	proc sql ;
		create table buckets_pxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_pxpx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_dxdx2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_dxdx1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_pxpx_proc2_piid as 
		select BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_pxpx_proc1
		group by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR
		order by BUCKET1, BUCKET2, HMS_PIID, COUNTING, YEAR;
	quit ;

	data buckets_all_co_piid;
	set buckets_pxdx2_piid buckets_pxpx2_piid buckets_dxdx2_piid buckets_pxpx_proc2_piid;
	run;

	proc sort data=buckets_all_co_piid;
	by COUNTING BUCKET1 BUCKET2 HMS_PIID YEAR;
	run;

	%end;

%end;

%mend;

%trend_count;

%macro export_files;

proc export data=buckets_all_co outfile='trend_buckets_co.txt' replace;
run;

%if &facility. = 1 %then %do;
proc export data=buckets_all_co_poid outfile='trend_buckets_co_poid.txt' replace;
run;
%end;

%if &practitioner. = 1 %then %do;
proc export data=buckets_all_co_piid outfile='trend_buckets_co_piid.txt' replace;
run;
%end;

%mend;

%export_files;

proc delete data=PE.trend_buckets_&rand_digit.;
run;
proc delete data=PE.trend_job_pxdx_&rand_digit.;
run;
proc delete data=PE.trend_job_pxpx_&rand_digit.;
run;
proc delete data=PE.trend_job_dxdx_&rand_digit.;
run;
proc delete data=PE.trend_job_px1_&rand_digit.;
run;
proc delete data=PE.trend_job_px2_&rand_digit.;
run;
proc delete data=PE.trend_bill_&rand_digit.;
run;
proc delete data=PE.trend_pos_&rand_digit.;
run;
proc delete data=PE.trend_bucket1_&rand_digit.;
run;
proc delete data=PE.trend_bucket2_&rand_digit.;
run;
proc delete data=PE.trend_vendors_exempt_&rand_digit.;
run;
proc delete data=PE.trend_vendors_masked_&rand_digit.;
run;
proc delete data=PE.trend_roles_&rand_digit.;
run;

/* Establish today's date */
data _null_;
tday = left(put(YEAR(TODAY()),Z4.))||left(put(MONTH(TODAY()),Z2.))||left(put(DAY(TODAY()),Z2.));
call symput('today',tday);
run;
%put 'today :' &today;

/* Add in QA graphs */
%macro QA_plots;

data _null_;
set inputs;

if PARAMETER = 'COMPARE_FILE' then do;
	if VALUE = '' then do;
		call symput('compare_file','none');
		call symput('file_exist',0);
	end;
	else do;
		call symput('compare_file',trim(left(compress(value))));
		call symput('file_exist',1);
	end;
end;
else do;
	call symput('compare_file','none');
	call symput('file_exist',0);
end;

if PARAMETER = 'PERIOD' then do;
	if VALUE = 'WEEK' then call symput('week_flag',1);
	if VALUE = 'MONTH' then call symput('week_flag',2);
	if VALUE = 'YEAR' then call symput('week_flag',3);
end;

run;

%put &compare_file;
%put &file_exist;

%if &file_exist = 1 %then %do;

symbol1 interpol=join
        value=dot
        color=_style_;
symbol2 interpol=join
        value=dot
		font=marker
        color=_style_ ;
axis1 
      label=none
      major=(height=2)
     minor=(height=1)
      ;

axis2 
      label=none
      major=(height=2)
     minor=(height=1)
      ;
legend1 label=none
        position=(top center inside)
        mode=share;

%if &week_flag. = 1 %then %do;

data new;
infile "trend_buckets_co.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	format BUCKET1	$100. ;
	format BUCKET2	$100. ;
	format COUNTING 	$100. ;
	format YEAR 	best32. ;
	format MON 	best32. ;
	format DAY 	best32. ;
	format WEEK1 	$50. ;
	format COUNT_new 	best32. ;
	informat BUCKET1	$100. ;
	informat BUCKET2	$100. ;
	informat COUNTING 	$100. ;
	informat YEAR 	best12. ;
	informat MON 	best12. ;
	informat DAY 	best12. ;
	informat WEEK1 	$50. ;
	informat COUNT_new 	best12. ;
	input BUCKET1 $ BUCKET2 $ COUNTING $ YEAR MON DAY WEEK1 $ COUNT_new;
run;

data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	format BUCKET1	$100. ;
	format BUCKET2	$100. ;
	format COUNTING 	$100. ;
	format YEAR 	best32. ;
	format MON 	best32. ;
	format DAY 	best32. ;
	format WEEK1 	$50. ;
	format COUNT_old 	best32. ;
	informat BUCKET1	$100. ;
	informat BUCKET2	$100. ;
	informat COUNTING 	$100. ;
	informat YEAR 	best12. ;
	informat MON 	best12. ;
	informat DAY 	best12. ;
	informat WEEK1 	$50. ;
	informat COUNT_old 	best12. ;
	input BUCKET1 $ BUCKET2 $ COUNTING $ YEAR MON DAY WEEK1 $ COUNT_old;
run;

proc sort data=old;
by BUCKET1 BUCKET2 COUNTING YEAR MON DAY WEEK1;
run;
proc sort data=new;
by BUCKET1 BUCKET2 COUNTING YEAR MON DAY WEEK1;
run;
data compare;
merge old new;
by BUCKET1 BUCKET2 COUNTING YEAR MON DAY WEEK1;
WEEK = mdy(MON,DAY,YEAR);
format WEEK MMDDYY10.;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_co_&today..pdf";
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot COUNT_new*WEEK COUNT_old*WEEK / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot Pct_Change*WEEK / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%else %if &week_flag. = 2 %then %do;

data new;
infile "trend_buckets_co.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET1 $100. ;
informat BUCKET2 $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat MON best32. ;
informat COUNT_new best32. ;
format BUCKET1 $100. ;
format BUCKET2 $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format MON best12. ;
format COUNT_new best12. ;
input
BUCKET1 $
BUCKET2 $
COUNTING $
YEAR
MON
COUNT_new
;
run;
data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET1 $100. ;
informat BUCKET2 $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat MON best32. ;
informat COUNT_old best32. ;
format BUCKET1 $100. ;
format BUCKET2 $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format MON best12. ;
format COUNT_old best12. ;
input
BUCKET1 $
BUCKET2 $
COUNTING $
YEAR
MON
COUNT_old
;
run;

proc sort data=old;
by BUCKET1 BUCKET2 COUNTING YEAR MON;
run;
proc sort data=new;
by BUCKET1 BUCKET2 COUNTING YEAR MON;
run;
data compare;
merge old new;
by BUCKET1 BUCKET2 COUNTING YEAR MON;
MONTH = mdy(MON,1,YEAR);
format MONTH MONYY.;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_co_&today..pdf";
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot COUNT_new*MONTH COUNT_old*MONTH / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot Pct_Change*MONTH / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%else %if &week_flag. = 3 %then %do;

data new;
infile "trend_buckets_co.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET1 $100. ;
informat BUCKET2 $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat COUNT_new best32. ;
format BUCKET1 $100. ;
format BUCKET2 $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format COUNT_new best12. ;
input
BUCKET1 $
BUCKET2 $
COUNTING $
YEAR
COUNT_new
;
run;
data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET1 $100. ;
informat BUCKET2 $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat COUNT_old best32. ;
format BUCKET1 $100. ;
format BUCKET2 $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format COUNT_old best12. ;
input
BUCKET1 $
BUCKET2 $
COUNTING $
YEAR
COUNT_old
;
run;

proc sort data=old;
by BUCKET1 BUCKET2 COUNTING YEAR;
run;
proc sort data=new;
by BUCKET1 BUCKET2 COUNTING YEAR;
run;
data compare;
merge old new;
by BUCKET1 BUCKET2 COUNTING YEAR;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_co_&today..pdf";
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot COUNT_new*YEAR COUNT_old*YEAR / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET1 BUCKET2 COUNTING;
plot Pct_Change*YEAR / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%end;

%mend;

%QA_plots;

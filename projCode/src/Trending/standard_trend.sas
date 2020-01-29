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

data _null_;
set inputs;

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
1INST
2INST
3INST
5PROF
6PROF
;
run; 

%macro role_count;
%if &ROLES. = 0 %then %do;
data role_list;
set role_list_default;
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

%put _USER_;

/* Read in inputs file */
data buckets(compress=yes);
infile '../buckets.txt'
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
	informat CODE $15. ;
	informat SCHEME $10. ;
	informat TYPE $2. ;
	informat BUCKET $100. ;
	informat COUNTING $10. ;
	format CODE $15. ;
	format SCHEME $10. ;
	format TYPE $2. ;
	format BUCKET $100. ;
	format COUNTING $10. ;
input CODE $ SCHEME $ TYPE $ BUCKET $ COUNTING $;
run;

data buckets;
set buckets;
CODE = compress(CODE,'.');
run;

proc sort data=buckets;
by TYPE BUCKET COUNTING;
run;
proc sort data=buckets nodupkey out=just_buckets;
by TYPE BUCKET COUNTING;
run;
data just_buckets;
set just_buckets;
num=_n_;
call symput('bucket_'||left(_N_),BUCKET);
call symput('type_'||left(_N_),TYPE);
call symput('counting_'||left(_N_),COUNTING);
run;
data buckets;
merge buckets just_buckets;
by TYPE BUCKET COUNTING;
run;

/* Generate 4-digit random table suffix to avoid overwrite existing table in Oracle */
data _null_;
call symput ("rand_digit", put(ranuni(0)*10000,Z4.));
run;

libname pe oracle user=claims_usr password=claims_usr123 path=PLDWH2DBR;
proc delete data=PE.trend_buckets_&rand_digit.;
run;
/* Import codes to Oracle */
data pe.trend_buckets_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.buckets;
run ;

proc delete data=PE.trend_vendors_&rand_digit.;
run;
/* Import vendor list to Oracle */
data pe.trend_vendors_&rand_digit.
(BULKLOAD=YES BL_DIRECT_PATH=NO BL_OPTIONS='ERRORS=899')
	;
	set WORK.vendor_list;
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
quit;

%macro pull;

/* Pull the data */
proc delete data=PE.trend_job_px_&rand_digit.;
run;
proc sql ;
	connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

	create table pe.trend_job_px_&rand_digit. as 
	select *
	from connection to oracle
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.PROF_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.prof_claim_procs a,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.LINE_POS_ID=s.POS_CODE
		and a.LINE_PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.CLAIM_PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		);

		execute(insert /*+ append */ into trend_job_px_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members g,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PATIENT' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.PROCEDURE_GROUP_ID=g.PROCEDURE_GROUP_ID
		and g.PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.procedure_group_members g,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'CLAIM' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.PROCEDURE_GROUP_ID=g.PROCEDURE_GROUP_ID
		and g.PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.INST_PROCEDURE_ID) as COUNT_ID
		from
		claimswh.inst_claim_procs a,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PROCEDURE' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.LINE_PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members g,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PATIENT' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.PROCEDURE_GROUP_ID=g.PROCEDURE_GROUP_ID
		and g.PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_px_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.procedure_group_members g,
		claimswh.procedures d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'CLAIM' and TYPE = 'px') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.PROCEDURE_GROUP_ID=g.PROCEDURE_GROUP_ID
		and g.PROCEDURE_ID=d.PROCEDURE_ID
		and d.ADDNL_PROCEDURE_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

proc delete data=PE.trend_job_dx_&rand_digit.;
run;
proc sql ;
	connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

	create table pe.trend_job_dx_&rand_digit. as 
	select *
	from connection to oracle
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PATIENT' and TYPE = 'dx') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		);

		execute(insert /*+ append */ into trend_job_dx_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.prof_claims a,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_pos_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'CLAIM' and TYPE = 'dx') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.CLAIM_POS_ID=s.POS_CODE
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_dx_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		a.PATIENT_ID as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'PATIENT' and TYPE = 'dx') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

		execute(insert /*+ append */ into trend_job_dx_&rand_digit.(BUCKET,COUNTING,CLAIM_ID,CLAIM_DATE,HMS_POID,HMS_PIID,COUNT_ID)   
		select BUCKET, COUNTING, CLAIM_ID, CLAIM_DATE, HMS_POID, HMS_PIID, COUNT_ID
		from  
		(select x.BUCKET, x.COUNTING, a.CLAIM_ID,
		a.CLAIM_THROUGH_DATE as CLAIM_DATE,
		f.ID_VALUE as HMS_POID,
		pid.ID_VALUE as HMS_PIID,
		to_char(a.CLAIM_ID) as COUNT_ID
		from
		claimswh.inst_claims a,
		claimswh.diagnosis_group_members dg,
		claimswh.diagnosis d,
		claimswh.facility_id_crosswalk f,
		claimswh.practitioner_group_members pgm,
		claimswh.practitioner_id_crosswalk pid,
		claimswh.vendors v,
		trend_bill_&rand_digit. s,
		trend_vendors_&rand_digit. ven,
		trend_roles_&rand_digit. r,
		(select * from trend_buckets_&rand_digit. where COUNTING = 'CLAIM' and TYPE = 'dx') x
		where a.VENDOR_ID=v.VENDOR_ID
		and v.VENDOR_CODE=ven.VENDOR
		and a.CLAIM_THROUGH_DATE between &start_date. and &max_date.
		and a.BILL_CLASSIFICATION_ID=s.BILL_CODE
		and a.DIAGNOSIS_GROUP_ID=dg.DIAGNOSIS_GROUP_ID
		and dg.DIAGNOSIS_ID=d.DIAGNOSIS_ID
		and d.ADDNL_DIAGNOSIS_CODE=x.CODE and d.CODE_SCHEME=x.SCHEME
		and a.FACILITY_ID=f.FACILITY_ID and f.ID_TYPE = 'POID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between f.START_DATE and f.END_DATE)
		and a.PRACTITIONER_GROUP_ID=pgm.PRACTITIONER_GROUP_ID and pgm.PRACTITIONER_ROLE_ID=r.ROLE_ID
		and pgm.PRACTITIONER_ID=pid.PRACTITIONER_ID and pid.ID_TYPE = 'PIID'
		and (to_date(%unquote(%str(%'&vintage%')),'YYYYMMDD') between pid.START_DATE and pid.END_DATE)
		)
		) by oracle;

quit;

%mend;

%pull;

%put &facility.;
%put &practitioner.;
%macro trend_count;  

%if &facility. = 0 & &practitioner. = 0 %then %do;

	proc sql ;
		connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

		create table buckets_px as 
		select *
		from connection to oracle
			(select a.BUCKET, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_px_&rand_digit. a);

		create table buckets_dx as 
		select *
		from connection to oracle
			(select a.BUCKET, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_dx_&rand_digit. a);

	disconnect from oracle ;
	quit ;

%end;

%else %if &facility. = 1 & &practitioner. = 0 %then %do;

	proc sql ;
		connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

		create table buckets_px as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_px_&rand_digit. a);

		create table buckets_dx as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_POID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_dx_&rand_digit. a);

	disconnect from oracle ;
	quit ;

%end;

%else %if &facility. = 0 & &practitioner. = 1 %then %do;

	proc sql ;
		connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

		create table buckets_px as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_px_&rand_digit. a);

		create table buckets_dx as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_dx_&rand_digit. a);

	disconnect from oracle ;
	quit ;

%end;

%else %if &facility. = 1 & &practitioner. = 1 %then %do;

	proc sql ;
		connect to oracle(user=claims_usr password=claims_usr123 path=PLDWH2DBR PRESERVE_COMMENTS) ;

		create table buckets_px as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_px_&rand_digit. a);

		create table buckets_dx as 
		select *
		from connection to oracle
			(select a.BUCKET, a.HMS_POID, a.HMS_PIID, a.COUNTING, a.CLAIM_DATE, a.COUNT_ID
			from trend_job_dx_&rand_digit. a);

	disconnect from oracle ;
	quit ;


%end;

%if &week_flag = 1 %then %do;

data buckets_px1;
set buckets_px;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_px2 as 
	select BUCKET, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_px1
	group by BUCKET, COUNTING, YEAR, WEEK
	order by BUCKET, COUNTING, YEAR, WEEK;
quit ;

data buckets_dx1;
set buckets_dx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
DAY = mod(CLAIM_DATE,100);
WEEK = week(mdy(MONTH,DAY,YEAR),'u');
run;
proc sql ;
	create table buckets_dx2 as 
	select BUCKET, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_dx1
	group by BUCKET, COUNTING, YEAR, WEEK
	order by BUCKET, COUNTING, YEAR, WEEK;
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

proc sort data=buckets_px2;
by YEAR WEEK;
run;
data buckets_px3;
merge buckets_px2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_px4 as
select BUCKET, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_px3;
quit;

proc sort data=buckets_dx2;
by YEAR WEEK;
run;
data buckets_dx3;
merge buckets_dx2(in=a) weekdays1;
by YEAR WEEK;
if a;
run;
proc sql;
create table buckets_dx4 as
select BUCKET, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dx3;
quit;

data buckets_all;
set buckets_dx4 buckets_px4;
run;

proc sort data=buckets_all;
by COUNTING BUCKET YEAR MONTH DAY;
run;

	%if &facility. = 1 %then %do;

	create table buckets_px2_poid as 
	select BUCKET, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_px1
	group by BUCKET, HMS_POID, COUNTING, YEAR, WEEK
	order by BUCKET, HMS_POID, COUNTING, YEAR, WEEK;

	proc sort data=buckets_px2_poid;
	by YEAR WEEK;
	run;
	data buckets_px3_poid;
	merge buckets_px2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_px4_poid as
	select BUCKET, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_px3_poid;
	quit;

	create table buckets_dx2_poid as 
	select BUCKET, HMS_POID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_dx1
	group by BUCKET, HMS_POID, COUNTING, YEAR, WEEK
	order by BUCKET, HMS_POID, COUNTING, YEAR, WEEK;

	proc sort data=buckets_dx2_poid;
	by YEAR WEEK;
	run;
	data buckets_dx3_poid;
	merge buckets_dx2_poid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_dx4_poid as
	select BUCKET, HMS_POID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dx3_poid;
	quit;

	data buckets_all_poid;
	set buckets_dx4_poid buckets_px4_poid;
	run;

	proc sort data=buckets_all_poid;
	by COUNTING HMS_POID BUCKET YEAR MONTH DAY;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	create table buckets_px2_piid as 
	select BUCKET, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_px1
	group by BUCKET, HMS_PIID, COUNTING, YEAR, WEEK
	order by BUCKET, HMS_PIID, COUNTING, YEAR, WEEK;

	proc sort data=buckets_px2_piid;
	by YEAR WEEK;
	run;
	data buckets_px3_piid;
	merge buckets_px2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_px4_piid as
	select BUCKET, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_px3_poid;
	quit;

	create table buckets_dx2_piid as 
	select BUCKET, HMS_PIID, COUNTING, YEAR, WEEK, count(distinct COUNT_ID) as COUNT
	from buckets_dx1
	group by BUCKET, HMS_PIID, COUNTING, YEAR, WEEK
	order by BUCKET, HMS_PIID, COUNTING, YEAR, WEEK;

	proc sort data=buckets_dx2_piid;
	by YEAR WEEK;
	run;
	data buckets_dx3_piid;
	merge buckets_dx2_piid(in=a) weekdays1;
	by YEAR WEEK;
	if a;
	run;
	proc sql;
	create table buckets_dx4_piid as
	select BUCKET, HMS_PIID, COUNTING, YEAR, MONTH, DAY, WEEK_OF as WEEK, COUNT from buckets_dx3_poid;
	quit;

	data buckets_all_piid;
	set buckets_dx4_piid buckets_px4_piid;
	run;

	proc sort data=buckets_all_piid;
	by COUNTING HMS_PIID BUCKET YEAR MONTH DAY;
	run;

	%end;

%end;

%else %if &week_flag = 2 %then %do;

data buckets_px1;
set buckets_px;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_px2 as 
	select BUCKET, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_px1
	group by BUCKET, COUNTING, YEAR, MONTH
	order by BUCKET, COUNTING, YEAR, MONTH;
quit ;

data buckets_dx1;
set buckets_dx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
MONTH = (mod(CLAIM_DATE,10000) - mod(CLAIM_DATE,100))/100;
run;
proc sql ;
	create table buckets_dx2 as 
	select BUCKET, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
	from buckets_dx1
	group by BUCKET, COUNTING, YEAR, MONTH
	order by BUCKET, COUNTING, YEAR, MONTH;
quit ;

data buckets_all;
set buckets_dx2 buckets_px2;
run;

proc sort data=buckets_all;
by COUNTING BUCKET YEAR MONTH;
run;

	%if &facility. = 1 %then %do;

	proc sql ;
		create table buckets_px2_poid as 
		select BUCKET, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_px1
		group by BUCKET, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_dx2_poid as 
		select BUCKET, HMS_POID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_dx1
		group by BUCKET, HMS_POID, COUNTING, YEAR, MONTH
		order by BUCKET, HMS_POID, COUNTING, YEAR, MONTH;
	quit ;

	data buckets_all_poid;
	set buckets_dx2_poid buckets_px2_poid;
	run;

	proc sort data=buckets_all_poid;
	by COUNTING HMS_POID BUCKET YEAR MONTH;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	proc sql ;
		create table buckets_px2_piid as 
		select BUCKET, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_px1
		group by BUCKET, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	proc sql ;
		create table buckets_dx2_piid as 
		select BUCKET, HMS_PIID, COUNTING, YEAR, MONTH, count(distinct COUNT_ID) as COUNT
		from buckets_dx1
		group by BUCKET, HMS_PIID, COUNTING, YEAR, MONTH
		order by BUCKET, HMS_PIID, COUNTING, YEAR, MONTH;
	quit ;

	data buckets_all_piid;
	set buckets_dx2_piid buckets_px2_piid;
	run;

	proc sort data=buckets_all_piid;
	by COUNTING HMS_PIID BUCKET YEAR MONTH;
	run;

	%end;

%end;

%else %if &week_flag = 3 %then %do;

data buckets_px1;
set buckets_px;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_px2 as 
	select BUCKET, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_px1
	group by BUCKET, COUNTING, YEAR
	order by BUCKET, COUNTING, YEAR;
quit ;

data buckets_dx1;
set buckets_dx;
YEAR = (CLAIM_DATE - mod(CLAIM_DATE,10000))/10000;
run;
proc sql ;
	create table buckets_dx2 as 
	select BUCKET, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
	from buckets_dx1
	group by BUCKET, COUNTING, YEAR
	order by BUCKET, COUNTING, YEAR;
quit ;

data buckets_all;
set buckets_dx2 buckets_px2;
run;

proc sort data=buckets_all;
by COUNTING BUCKET YEAR;
run;

	%if &facility. = 1 %then %do;

	proc sql ;
		create table buckets_px2_poid as 
		select BUCKET, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_px1
		group by BUCKET, HMS_POID, COUNTING, YEAR
		order by BUCKET, HMS_POID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_dx2_poid as 
		select BUCKET, HMS_POID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_dx1
		group by BUCKET, HMS_POID, COUNTING, YEAR
		order by BUCKET, HMS_POID, COUNTING, YEAR;
	quit ;

	data buckets_all_poid;
	set buckets_dx2_poid buckets_px2_poid;
	run;

	proc sort data=buckets_all_poid;
	by COUNTING HMS_POID BUCKET YEAR;
	run;

	%end;

	%if &practitioner. = 1 %then %do;

	proc sql ;
		create table buckets_px2_piid as 
		select BUCKET, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_px1
		group by BUCKET, HMS_PIID, COUNTING, YEAR
		order by BUCKET, HMS_PIID, COUNTING, YEAR;
	quit ;

	proc sql ;
		create table buckets_dx2_piid as 
		select BUCKET, HMS_PIID, COUNTING, YEAR, count(distinct COUNT_ID) as COUNT
		from buckets_dx1
		group by BUCKET, HMS_PIID, COUNTING, YEAR
		order by BUCKET, HMS_PIID, COUNTING, YEAR;
	quit ;

	data buckets_all_piid;
	set buckets_dx2_piid buckets_px2_piid;
	run;

	proc sort data=buckets_all_piid;
	by COUNTING HMS_PIID BUCKET YEAR;
	run;

	%end;

%end;

%mend trend_count;

%trend_count;

%macro export_files;

proc export data=buckets_all outfile='trend_buckets.txt' replace;
run;

%if &facility. = 1 %then %do;
proc export data=buckets_all_poid outfile='trend_buckets_poid.txt' replace;
run;
%end;

%if &practitioner. = 1 %then %do;
proc export data=buckets_all_piid outfile='trend_buckets_piid.txt' replace;
run;
%end;

%mend;
%export_files;

proc delete data=PE.trend_buckets_&rand_digit.;
run;
proc delete data=PE.trend_job_px_&rand_digit.;
run;
proc delete data=PE.trend_job_dx_&rand_digit.;
run;
proc delete data=PE.trend_bill_&rand_digit.;
run;
proc delete data=PE.trend_pos_&rand_digit.;
run;
proc delete data=PE.trend_vendors_&rand_digit.;
run;
proc delete data=PE.trend_roles_&rand_digit.;
run;



/* Add in QA graphs */
%macro QA_plots;

data _null_;
set inputs;

if PARAMETER = 'COMPARE_FILE' then do;
	if VALUE = '' then call symput('compare_file','none');
	else call symput('compare_file',trim(left(compress(value))));
end;
else call symput('compare_file','none');

if PARAMETER = 'PERIOD' then do;
	if VALUE = 'WEEK' then call symput('week_flag',1);
	else if VALUE = 'MONTH' then call symput('week_flag',2);
	else if VALUE = 'YEAR' then call symput('week_flag',3);
end;

run;

%put &compare_file;

%if &compare_file ~= none %then %do;

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
infile "trend_buckets.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	format BUCKET	$100. ;
	format COUNTING 	$100. ;
	format YEAR 	best32. ;
	format MON 	best32. ;
	format DAY 	best32. ;
	format WEEK1 	$50. ;
	format COUNT_new 	best32. ;
	informat BUCKET	$100. ;
	informat COUNTING 	$100. ;
	informat YEAR 	best12. ;
	informat MON 	best12. ;
	informat DAY 	best12. ;
	informat WEEK1 	$50. ;
	informat COUNT_new 	best12. ;
	input BUCKET $ COUNTING $ YEAR MON DAY WEEK1 $ COUNT_new;
run;

data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	format BUCKET	$100. ;
	format COUNTING 	$100. ;
	format YEAR 	best32. ;
	format MON 	best32. ;
	format DAY 	best32. ;
	format WEEK1 	$50. ;
	format COUNT_old 	best32. ;
	informat BUCKET	$50. ;
	informat COUNTING 	$100. ;
	informat YEAR 	best12. ;
	informat MON 	best12. ;
	informat DAY 	best12. ;
	informat WEEK1 	$50. ;
	informat COUNT_old 	best12. ;
	input BUCKET $ COUNTING $ YEAR MON DAY WEEK1 $ COUNT_old;
run;

proc sort data=old;
by BUCKET COUNTING YEAR MON DAY WEEK1;
run;
proc sort data=new;
by BUCKET COUNTING YEAR MON DAY WEEK1;
run;
data compare;
merge old new;
by BUCKET COUNTING YEAR MON DAY WEEK1;
WEEK = mdy(MON,DAY,YEAR);
format WEEK MMDDYY10.;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_&today..pdf";
proc gplot data=compare;
by BUCKET COUNTING;
plot COUNT_new*WEEK COUNT_old*WEEK / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET COUNTING;
plot Pct_Change*WEEK / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%else %if &week_flag. = 2 %then %do;

data new;
infile "trend_buckets.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat MON best32. ;
informat COUNT_new best32. ;
format BUCKET $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format MON best12. ;
format COUNT_new best12. ;
input
BUCKET $
COUNTING $
YEAR
MON
COUNT_new
;
run;
data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat MON best32. ;
informat COUNT_old best32. ;
format BUCKET $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format MON best12. ;
format COUNT_old best12. ;
input
BUCKET $
COUNTING $
YEAR
MON
COUNT_old
;
run;

proc sort data=old;
by BUCKET COUNTING YEAR MON;
run;
proc sort data=new;
by BUCKET COUNTING YEAR MON;
run;
data compare;
merge old new;
by BUCKET COUNTING YEAR MON;
MONTH = mdy(MON,1,YEAR);
format MONTH MONYY.;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_&today..pdf";
proc gplot data=compare;
by BUCKET COUNTING;
plot COUNT_new*MONTH COUNT_old*MONTH / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET COUNTING;
plot Pct_Change*MONTH / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%else %if &week_flag. = 3 %then %do;

data new;
infile "trend_buckets.txt"
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat COUNT_new best32. ;
format BUCKET $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format COUNT_new best12. ;
input
BUCKET $
COUNTING $
YEAR
COUNT_new
;
run;
data old;
infile "&compare_file."
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
informat BUCKET $100. ;
informat COUNTING $100. ;
informat YEAR best32. ;
informat COUNT_old best32. ;
format BUCKET $100. ;
format COUNTING $100. ;
format YEAR best12. ;
format COUNT_old best12. ;
input
BUCKET $
COUNTING $
YEAR
COUNT_old
;
run;

proc sort data=old;
by BUCKET COUNTING YEAR;
run;
proc sort data=new;
by BUCKET COUNTING YEAR;
run;
data compare;
merge old new;
by BUCKET COUNTING YEAR;
Pct_Change = 100*(COUNT_new/COUNT_old-1);
run;

goptions device=pdf;
options orientation=landscape;
ods pdf file="../QA/Comparison_&today..pdf";
proc gplot data=compare;
by BUCKET COUNTING;
plot COUNT_new*YEAR COUNT_old*YEAR / overlay legend=legend1;
run;
quit;
proc gplot data=compare;
by BUCKET COUNTING;
plot Pct_Change*YEAR / overlay legend=legend1;
run;
quit;
ods pdf close;

%end;

%end;

%mend;

%QA_plots;

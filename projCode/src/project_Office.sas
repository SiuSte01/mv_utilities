/* **************************************************************************************************************************
PROGRAM NAME:				project_Office.sas (Formerly: Office_Counts_HG.sas)
PURPOSE:					Pull WK office counts with Medicare subsets (by PIID)
							Pull CMS Part B counts (by PIID)
							Pull WK office counts (by PIID/POID)
							Compile office predictions (by PIID/POID)
PROGRAMMER:					Mark Piatek
CREATION DATE:				06/30/2013
UPDATED:                                      11/16/2015
NOTES:						Updated to run on old DB or new DB
                                                      Updated to account for new AGGR_NAME structure
                                                      Updated to fix rare cases where duplicate PIID-POID records exist due to migration

INPUT FILES:				input.txt

OUTPUT FILES:				Office.ALL_&Counting._wcov
							Office.WK_&Counting._POID
							Office.All_&Counting._PRED
MACROS USED:				[none]
RUN BEFORE THIS PROGRAM:	Aggregations Projections Code
RUN AFTER THIS PROGRAM:		
************************************************************************************************************************** */

options mprint;
libname Office '.';

/* ******************************** MACRO - CREATE PROJECTIONS ******************************** */


%macro Projections_yes();  

/* Use Reg procedure to get full model estimates */
proc reg data=ALL_&Counting._wcov;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT / vif;
run;
quit;

%if &replacement_factor = 0 %then %do;

/* Get selected model */
proc glmselect data=ALL_&Counting._wcov;
model y = PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT
/ selection=stepwise(select=SL) stats=all slentry= .15 slstay= .15; /* default start/stop values */
score data=Office.ALL_&Counting._wcov
out=ALL_&Counting._new predicted=yhat;
run;

/* Score records where CMS Count is greater than the WK count */
data ALL_&Counting._new;
set ALL_&Counting._new;
model_factor = 10**(yhat) + 1;
run;

%end;

%else %if &replacement_factor = 1 %then %do;
data ALL_&Counting._new;
set Office.ALL_&Counting._wcov;
model_factor = 1;
run;
%end;

%let Median = 1;
/* Find the median model factor for imputation */
proc means data=ALL_&Counting._new n median noprint;
where WK_&Counting. < CMS_&Counting.;
var model_factor;
output out=median median=;
run;
data _null_;
set median;
call symput('Median',model_factor);
run;
%put Median = &Median;

/* Impute median for null model factors */
data ALL_&Counting._new;
set ALL_&Counting._new;

if CMS_&Counting. <= 5 then count_factor = 10;
else count_factor = 15;

/* Records above the cap must get a uniformly-distributed
   random factor no less than 80% of the cap */
if model_factor = . then model_factor = &Median.;
final_proj = CMS_&Counting. * count_factor * model_factor;
if final_proj > &Cap. then final_cms_proj = floor(&Cap.*(0.2*ranuni(0) + 0.8));
else final_cms_proj = floor(final_proj);

if final_proj > &Cap. then final_cms_cap = 1;
else final_cms_cap = 0;

/* Blending Factor macro variable removed */
if 10 > 1 then do;
if CMS_&Counting. ~= 0 then r = WK_&Counting./CMS_&Counting.;
if 0 <= r < 1 then f = 0;
else if 1 <= r <= 10 then f = (r-1)/(10 - 1);
else if r > 10 then f = 1;
end;

else do;
if 0 <= r < 1 then f = 0;
else f = 1;
end;

if f = . then EST_TOTAL_&Counting. = WK_&Counting.;
else EST_TOTAL_&Counting. = floor(f*WK_&Counting. + (1-f)*final_cms_proj);

if WK_&Counting. > 0 and CMS_&Counting = 0 then group = 'WK only ';
else if WK_&Counting. = 0 and CMS_&Counting > 0 then group = 'CMS only';
else if WK_&Counting. > 0 and CMS_&Counting > 0 then group = 'Both';

run;

data Office.ALL_&Counting._new;
set ALL_&Counting._new;
run;

/* Merge in any migrated POIDs to PIID/POID file */
proc sort data=WK_&Counting._POID;
by HMS_POID;
run;
proc sort data=Inputs.poidmigration_lookup_&Vintage.;
by HMS_POID;
run;
data WK_&Counting._POID;
merge WK_&Counting._POID(in=a)
Inputs.poidmigration_lookup_&Vintage.(rename=(hms_poid=HMS_POID));
by HMS_POID;
if a;
if POID_MIGRATION_STATUS = 'MOVED' then HMS_POID = new_poid;
drop POID_MIGRATION_STATUS new_poid;
run;

/* Sort and merge HMS_PIIDs from Vintage from WK */
proc sort data=WK_&Counting._POID(rename=(INDIV_ID=HMS_PIID));
by HMS_PIID;
run;
proc sort data=IndivID2PIID_&Vintage.;
by HMS_PIID;
run;

data WK_&Counting._POID;
merge IndivID2PIID_&Vintage.(in=a) WK_&Counting._POID(in=b);
by HMS_PIID;
if b;
label HMS_PIID =;
label WK_&Counting. =;
*drop INDIV_ID;
run;

/* This step removes rare cases of duplicate PIID-POID records due to migration */
proc means data=WK_&Counting._POID nway sum noprint;
where HMS_PIID ~= 'MISSING';
class HMS_PIID HMS_POID / missing;
var WK_&Counting.;
output out=temp_step(drop=_FREQ_ _TYPE_) sum=;
run;
data WK_&Counting._POID;
set temp_step;
run;

/* PIID counts must distribute among respective POIDS */
proc means data=WK_&Counting._POID sum noprint;
class HMS_PIID;
var WK_&Counting.;
output out=temp sum=PIID_total;
run;
proc sort data=WK_&Counting._POID;
by HMS_PIID;
run;
proc sort data=temp;
where _TYPE_ = 1;
by HMS_PIID;
run;
proc sort data=ALL_&Counting._new;
by HMS_PIID;
run;
data Office.WK_&Counting._POID(compress=yes);
merge WK_&Counting._POID(in=a) temp(keep=HMS_PIID PIID_total) ALL_&Counting._new(drop=WK_&Counting. ZIP);
by HMS_PIID;
if a;
FINAL_EST_TOTAL = max(round((WK_&Counting./PIID_total)*EST_TOTAL_&Counting.,1),1);
drop count_factor model_factor final_proj r f;
run;

/* Get CMS PIIDs only */
data CMS_&Counting._new;
set ALL_&Counting._new;
where WK_&Counting. = 0;
run;

/* Get estimates for CMS only records */
proc sort data=CMS_&Counting._new;
by HMS_PIID;
run;
proc sort data=inputs.estpoid_&Vintage.;
by HMS_PIID HMS_POID;
run;
data CMS_&Counting._POID;
merge CMS_&Counting._new(in=a) inputs.estpoid_&Vintage.;
by HMS_PIID;
if a;
FINAL_EST_TOTAL = EST_TOTAL_&Counting.;
run;

data Office.All_&Counting._PRED(compress=yes);
set Office.WK_&Counting._POID(keep=HMS_PIID HMS_POID FINAL_EST_TOTAL)
CMS_&Counting._POID(keep=HMS_PIID HMS_POID FINAL_EST_TOTAL);
if HMS_POID = 'MISSING' then HMS_POID = '';
run;

%mend Projections_yes;

/* MACRO - DO NOT CREATE PROJECTIONS */

%macro Projections_no();

data Office.All_&Counting._noPRED(compress=yes);
set WK1_&Counting._PIID;
keep HMS_PIID WK_&Counting.;
rename WK_&Counting. = EST_TOTAL_&Counting.;
run;

/* Merge in any migrated POIDs to PIID/POID file */
proc sort data=WK_&Counting._POID;
by HMS_POID;
run;
proc sort data=Inputs.poidmigration_lookup_&Vintage.;
by HMS_POID;
run;
data WK_&Counting._POID;
merge WK_&Counting._POID(in=a)
Inputs.poidmigration_lookup_&Vintage.(rename=(hms_poid=HMS_POID));
by HMS_POID;
if a;
if POID_MIGRATION_STATUS = 'MOVED' then HMS_POID = new_poid;
drop POID_MIGRATION_STATUS new_poid;
run;

/* Sort and merge HMS_PIIDs from Vintage fror WK */
proc sort data=WK_&Counting._POID(rename=(INDIV_ID=HMS_PIID));
by HMS_PIID;
run;
proc sort data=IndivID2PIID_&Vintage.;
by HMS_PIID;
run;

data WK_&Counting._POID;
merge IndivID2PIID_&Vintage.(in=a) WK_&Counting._POID(in=b);
by HMS_PIID;
if b;
if HMS_PIID = 'MISSING' then delete;
label HMS_PIID =;
label WK_&Counting. =;
*drop INDIV_ID;
run;

/* PIID counts must distribute among respective POIDS */
proc means data=WK_&Counting._POID sum noprint;
class HMS_PIID;
var WK_&Counting.;
output out=temp sum=PIID_total;
run;
proc sort data=WK_&Counting._POID;
by HMS_PIID;
run;
proc sort data=temp;
where _TYPE_ = 1;
by HMS_PIID;
run;
proc sort data=Office.All_&Counting._noPRED;
by HMS_PIID;
run;
data WK_&Counting._POID(compress=yes);
merge WK_&Counting._POID(in=a) temp(keep=HMS_PIID PIID_total) Office.All_&Counting._noPRED;
by HMS_PIID;
if a;
FINAL_EST_TOTAL = max(round((WK_&Counting./PIID_total)*EST_TOTAL_&Counting.,1),1);
keep HMS_PIID HMS_POID FINAL_EST_TOTAL;
run;

data Office.All_&Counting._PRED(compress=yes);
set WK_&Counting._POID;
if HMS_POID = 'MISSING' then HMS_POID = '';
run;

%mend Projections_no;

/* MACRO - Referal Docs */

%macro Referal_Y();

/* Pull WK office data - referal PIID level if needed */

proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table WK_&Counting._PIID_ref(compress=yes) as 
	select *
	from connection to oracle
		(select DOC_ID as INDIV_ID, &TOTAL_COUNT as WK_&Counting._ref
		from &AGGREGATION_TABLE. where JOB_ID = &job_id. and AGGR_LEVEL = 'DOCLEVEL'
		and AGGR_NAME = 'WKMX_OFF_REFDOC'
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		)
		;

disconnect from oracle ;
quit ;

/* Sort and merge HMS_PIIDs from Vintage to WK */
proc sort data=WK_&Counting._PIID_ref(rename=(INDIV_ID=HMS_PIID));
by HMS_PIID;
run;
proc sort data=IndivID2PIID_&Vintage. nodupkey;
by HMS_PIID;
run;

data WK1_&Counting._PIID_ref;
merge IndivID2PIID_&Vintage.(in=a) WK_&Counting._PIID_ref(in=b);
by HMS_PIID;
if b;
label HMS_PIID =;
label WK_&Counting._ref =;
rename WK_&Counting._ref = FINAL_EST_TOTAL;
group = 'WK refer';
run;

/* MODIFICATION: remove ref docs that are also in Office.ALL_&Counting._wcov */
proc sort data=Office.ALL_&Counting._wcov out=wcov(keep=HMS_PIID) nodupkey;
by HMS_PIID;
run;
data WK1_&Counting._PIID_ref;
merge WK1_&Counting._PIID_ref(in=a) wcov(in=b);
by HMS_PIID;
if a and not b;
run;
/* */

data All_&Counting._PRED(compress=yes);
set Office.All_&Counting._PRED
WK1_&Counting._PIID_ref(keep=HMS_PIID FINAL_EST_TOTAL);
run;

/* Sum at PIID/POID level to avoid duplicates */
proc means data=All_&Counting._PRED noprint sum;
class HMS_PIID HMS_POID / missing;
var FINAL_EST_TOTAL;
output out=ref_dups sum=;
run;

data Office.All_&Counting._PRED;
set ref_dups;
where _TYPE_ = 3;
if HMS_PIID = 'MISSING' then delete;
keep HMS_PIID HMS_POID FINAL_EST_TOTAL;
run;

/* Modification 3/21/2017: No longer deleting records with a POID that has no name/address */
/* Final Step - null out POIDs that have no name or no address */
/* Must keep PIIDs that don't have POIDs */
data piids_w_poids;
set Office.All_&Counting._PRED;
where HMS_POID ~= '';
run;
data piids_wo_poids;
set Office.All_&Counting._PRED;
where HMS_POID = '';
run;

/*proc sort data=inputs.orginfo_&vintage. out=good_orgs(keep=HMS_POID);
by HMS_POID;
run;*/
proc sort data=piids_w_poids;
by HMS_POID;
run;
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
proc means data=allpreds noprint nway sum;
class HMS_PIID HMS_POID / missing;
var FINAL_EST_TOTAL;
output out=Office.All_&Counting._PRED(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=Office.All_&Counting._PRED;
by HMS_POID HMS_PIID;
run;

%mend Referal_Y();

/* MACRO - No Referal Docs */

%macro Referal_N();

data Office.All_&Counting._PRED(compress=yes);
set Office.All_&Counting._PRED;
run;

/* Modification 3/21/2017: No longer deleting records with a POID that has no name/address */
/* Final Step - null out POIDs that have no name or no address */
/* Must keep PIIDs that don't have POIDs */
data piids_w_poids;
set Office.All_&Counting._PRED;
where HMS_POID ~= '';
run;
data piids_wo_poids;
set Office.All_&Counting._PRED;
where HMS_POID = '';
run;

/*proc sort data=inputs.orginfo_&vintage. out=good_orgs(keep=HMS_POID);
by HMS_POID;
run;*/
proc sort data=piids_w_poids;
by HMS_POID;
run;
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
proc means data=allpreds noprint nway sum;
class HMS_PIID HMS_POID / missing;
var FINAL_EST_TOTAL;
output out=Office.All_&Counting._PRED(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=Office.All_&Counting._PRED;
by HMS_POID HMS_PIID;
run;

%mend Referal_N();

/* MACRO - Print Datasets */

%macro Print_yes();

proc export data=Office.ALL_&Counting._wcov
outfile='claimsdatawcov.txt' replace;
run;
proc export data=WK_&Counting._POID
outfile='claimsdata_WK.txt' replace;
run;
proc export data=Office.All_&Counting._PRED
outfile='office_projections.txt' replace;
run;

%mend Print_yes();

%macro Print_no();

proc export data=Office.All_&Counting._PRED
outfile='office_projections.txt' replace;
run;

%mend Print_no();


/* ***************************************** RUN CODE ***************************************** */

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

/* If old DB instance, refer to old Aggr count names */
if Parameter = 'INSTANCE' and Value = 'pldwhdbr' then do;
	call symput('TOTAL_COUNT','TOTAL_COUNT');
	call symput('MDCR_COUNT','MDCR_COUNT');
end;
/* New DB names to come in subsequent step */

run;

data _null_;
set inputs;

/* This only works when new DB instance is set */
if %unquote(%str(%'&INSTANCE%')) = 'pldwh2dbr' then do;
	if Parameter = 'COUNTTYPE' and VALUE = 'CLAIM' then do;
		call symput('TOTAL_COUNT','CLAIM_CNT');
		call symput('MDCR_COUNT','MDCR_CLAIM_CNT');
	end;
	else if Parameter = 'COUNTTYPE' and VALUE = 'PROC' then do;
		call symput('TOTAL_COUNT','PROC_CNT');
		call symput('MDCR_COUNT','MDCR_PROC_CNT');
	end;
	else if Parameter = 'COUNTTYPE' and VALUE = 'PATIENT' then do;
		call symput('TOTAL_COUNT','PTNT_CNT');
		call symput('MDCR_COUNT','MDCR_PTNT_CNT');
	end;
end;

run;


%put Counting = &Counting;
%put Vintage = &Vintage;
%put Codetype = &Codetype;
%put Bucket = &Bucket;
%put NameType = &NameType;
%put AddRefDoc = &AddRefDoc;
%put job_id = &job_id;
%put USERNAME = &USERNAME;
%put PASSWORD = &PASSWORD;
%put INSTANCE = &INSTANCE;
%put AGGREGATION_TABLE = &AGGREGATION_TABLE;
%put CLAIM_PATIENT_TABLE = &CLAIM_PATIENT_TABLE;
%put FXFILES = &FXFILES;

%put TOTAL_COUNT = &TOTAL_COUNT;
%put MDCR_COUNT = &MDCR_COUNT;

libname Inputs %unquote(%str(%'&FXFILES%'));

/* First pull WK office data - PIID level */
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table WK_&Counting._PIID(compress=yes) as 
	select *
	from connection to oracle
		(select DOC_ID as INDIV_ID, &TOTAL_COUNT. as WK_&Counting., &MDCR_COUNT. as MEDI_&Counting.
		from &AGGREGATION_TABLE. where JOB_ID = &job_id. and AGGR_LEVEL = 'DOCLEVEL'
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		and AGGR_NAME = 'WKMX_OFF'
		)
		;

disconnect from oracle ;
quit ;

/* First check - make sure there are WK Medicare counts */
/* If not, final model factors will all be 1 */
%let replacement_factor = 0;
%put replacement_factor = &replacement_factor;
proc sql;
create table check1 as select sum(MEDI_&Counting.) as wk_medicare_sum from WK_&Counting._PIID;
quit;
data _null_;
set check1;
if wk_medicare_sum = 0 then call symput('replacement_factor',1);
run;
%put replacement_factor = &replacement_factor;

/* Next pull WK office data - PIID/POID level */
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table WK_&Counting._POID(compress=yes) as 
	select *
	from connection to oracle
		(select DOC_ID as INDIV_ID, ORG_ID as HMS_POID, &TOTAL_COUNT. as WK_&Counting.
		from &AGGREGATION_TABLE. where JOB_ID = &job_id. and AGGR_LEVEL = 'DOCORGLEVEL'
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		and AGGR_NAME = 'WKMX_OFF'
		)
		;

disconnect from oracle ;
quit ;

data WK_&Counting._POID;
set WK_&Counting._POID;
if HMS_POID = 'MISSING' then HMS_POID = '';
run;

/* Finally pull CMS office data - PIID level */
proc sql ;
	connect to oracle(user=&USERNAME. password=&PASSWORD. path=&INSTANCE.) ;

	create table CMS_&Counting._PIID(compress=yes) as 
	select *
	from connection to oracle
		(select DOC_ID as INDIV_ID, &TOTAL_COUNT. as CMS_&Counting.
		from &AGGREGATION_TABLE. where JOB_ID = &job_id. and AGGR_LEVEL = 'DOCLEVEL'
		and BUCKET_NAME = %unquote(%str(%'&Bucket%'))
		and AGGR_NAME = 'PTB_OFF'
		)
		;

disconnect from oracle ;
quit ;

/* MODIFICATION 9.24.2018: Adding PROJECTOFF variable and initialize do_ptb_projection variable here */
%let do_ptb_projection = yes;
data _null_;
set inputs;
if Parameter = 'PROJECTOFF' then do;
	call symput('projectoff', trim(left(compress(value))));
	if VALUE = 'N' then call symput('do_ptb_projection','no');
	else if VALUE = 'Y' then call symput('do_ptb_projection','yes');
end;
run;
%put 'PROJECTOFF :' &projectoff;

/* Second check - make sure there are Part B counts */
%put do_ptb_projection = &do_ptb_projection;
proc sql;
create table check2 as select count(*) as PtB_count from CMS_&Counting._PIID;
quit;
data _null_;
set check2;
if PtB_count = 0 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;

/* Sort and merge HMS_PIIDs from Vintage to WK */

/* NOTE: NO LONGER DOING THIS - WE HAVE PIIDS */
/*
proc sort data=WK_&Counting._PIID;
by INDIV_ID;
run;
proc sort data=Inputs.IndivID2PIID_&Vintage.;
by INDIV_ID;
run;

data IndivID2PIID_&Vintage.;
length INDIV_ID $ 50.;
set Inputs.IndivID2PIID_&Vintage.;
run;

data WK1_&Counting._PIID;
merge IndivID2PIID_&Vintage.(in=a) WK_&Counting._PIID(in=b);
by INDIV_ID;
if a and b;
label WK_&Counting. =;
label MEDI_&Counting. =;
run;
*/

proc sort data=Inputs.IndivID2PIID_&Vintage. nodupkey out=IndivID2PIID_&Vintage.(drop=INDIV_ID);
by HMS_PIID;
run;
proc sort data=WK_&Counting._PIID(rename=(INDIV_ID=HMS_PIID));
by HMS_PIID;
run;

data WK1_&Counting._PIID;
merge IndivID2PIID_&Vintage.(in=a) WK_&Counting._PIID(in=b);
by HMS_PIID;
if b;
label HMS_PIID =;
label WK_&Counting. =;
label MEDI_&Counting. =;
run;

/* NOTE: NO LONGER DOING THIS - WE HAVE PIIDS */
/*
proc sort data=CMS_&Counting._PIID;
by INDIV_ID;
run;

data CMS1_&Counting._PIID(compress=yes);
merge IndivID2PIID_&Vintage.(in=a) CMS_&Counting._PIID(in=b);
by INDIV_ID;
if a and b;
label CMS_&Counting. =;
run;
*/

proc sort data=CMS_&Counting._PIID(rename=(INDIV_ID=HMS_PIID));
by HMS_PIID;
run;

data CMS1_&Counting._PIID(compress=yes);
merge IndivID2PIID_&Vintage.(in=a) CMS_&Counting._PIID(in=b);
by HMS_PIID;
if b;
label HMS_PIID =;
label CMS_&Counting. =;
run;

/* Sort and merge WK and CMS data together in one table */
proc sort data=WK1_&Counting._PIID;
by HMS_PIID;
run;
proc sort data=CMS1_&Counting._PIID;
by HMS_PIID;
run;

data Office.ALL_&Counting._PIID(compress=yes);
merge WK1_&Counting._PIID CMS1_&Counting._PIID;
by HMS_PIID;
*drop INDIV_ID;
if WK_&Counting. = . then WK_&Counting. = 0;
if MEDI_&Counting. = . then MEDI_&Counting. = 0;
if CMS_&Counting. = . then CMS_&Counting. = 0;
if HMS_PIID = 'MISSING' then delete;
rename RANK1ZIP = ZIP;
run;

/* Merge in covariates */
proc sort data=Inputs.xwalk_zip nodupkey out=zips(keep=ZIP FIPS);
by ZIP;
run;
proc sort data=Office.ALL_&Counting._PIID out=temp;
by ZIP;
run;
proc sort data=Inputs.covar_under65;
by ZIP;
run;

data ALL_&Counting._FIPS(compress=yes);
merge temp(in=a) zips Inputs.covar_under65;
by ZIP;
if a;
run;

proc sort data=ALL_&Counting._FIPS;
by FIPS;
run;
proc sort data=Inputs.covar_County_Unemp;
by FIPS;
run;
proc sort data=Inputs.covar_MA_penetration;
by FIPS;
run;
proc sort data=Inputs.covar_HI_expend;
by FIPS;
run;

data Office.ALL_&Counting._wcov(compress=yes);
merge ALL_&Counting._FIPS(in=a)
Inputs.covar_County_Unemp(keep=FIPS Rate)
Inputs.covar_MA_penetration(keep=FIPS Penetration)
Inputs.covar_HI_expend(keep=FIPS IHXCYHC1)
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

/* Modification 1/24/2017: Special non-projection case for CPM jobs only
   if total WK sum is less that total CMS sum, then do not project */
%macro CPM_project;
%if &Codetype. = CPM %then %do;

proc means data=Office.ALL_&Counting._wcov nway sum noprint;
var WK_&counting. CMS_&counting.;
output out=CPM_check sum=WK_sum CMS_sum;
run;

data _null_;
set CPM_check;
if WK_sum < CMS_sum then call symput('do_ptb_projection','no');
run;

%end;
%mend;

%CPM_project;
%put do_ptb_projection = &do_ptb_projection;

/* Make the tenth-largest WK Count value the cap */
proc sort data=Office.ALL_&Counting._wcov out=first10;
by descending WK_&Counting.;
run;
data first10;
set first10(obs=10);
temp_value=WK_&Counting. + (ranuni(0)); /* needed in case 9th and 10th are the same */
keep WK_&Counting. temp_value;
run;
proc rank data=first10 descending out=first10;
var temp_value;
ranks rank;
run;
data first10;
set first10;
if rank = 10 then call symput('Cap',WK_&Counting.);
run;
%put Cap = &Cap;

/* Set up training subset */
data ALL_&Counting._wcov(compress=yes);
set Office.ALL_&Counting._wcov;
where MEDI_&Counting. >= 5;
WK_ratio = WK_&Counting./MEDI_&Counting.;
if WK_ratio = 1 then delete;
box = 1;
run;

/* Boxplot to identify outliers */
goptions  reset=all border device=PDF;
options orientation=landscape;
ods pdf file='Boxplot.pdf';
proc boxplot data=ALL_&Counting._wcov;
plot WK_ratio*box / boxstyle = schematic outbox = boxout;
run;
quit;
ods pdf close;

proc means data=ALL_&Counting._wcov noprint q1 q3;
var WK_ratio;
output out=iqr_out q1=q1 q3=q3;
run;

data _null_;
set iqr_out;
if _TYPE_ = 0 then call symput('Outlier',(q3 + 1.5*(q3-q1)));
run;
%put Outlier = &Outlier;

/* In case the dataset is empty */
proc sql;
create table empty_set as select count(*) as empty from iqr_out;
quit;
data _null_;
set empty_set;
if empty = 0 then call symput('Outlier',1);
run;
%put Outlier = &Outlier;

/* Create dependent variable for model */
data ALL_&Counting._wcov;
set ALL_&Counting._wcov;
where WK_ratio < &Outlier.;
y = log10(WK_ratio - 1);
run;

/* Third check - must be more than 10 observations in training set */
/* If not, projections macro will run, but produce model factors of 1 */
proc sql;
create table check3 as select count(*) as Training_Count from ALL_&Counting._wcov;
quit;
/* Modification 11/10/2016: for AB jobs, do not project if count is < 100 */
/* Modification 1/31/2017: also do this for CPM jobs */
%macro AB;
%if &Codetype. = AB %then %do;
data _null_;
set check3;
if Training_Count < 100 then call symput('do_ptb_projection','no');
run;
%end;
%else %if &Codetype. = CPM %then %do;
data _null_;
set check3;
if Training_Count < 100 then call symput('do_ptb_projection','no');
run;
%end;
%else %do;
data _null_;
set check3;
if Training_Count < 10 then call symput('replacement_factor',1);
run;
%end;
%mend;

%AB;
%put do_ptb_projection = &do_ptb_projection;
%put replacement_factor = &replacement_factor;

/* Fourth check - median WK allpayer/medicare ratio must be greater than 10 */
proc means data=ALL_&Counting._wcov median noprint;
var WK_ratio;
output out=check4 median=median_ratio;
run;
data _null_;
set check4;
if median_ratio > 10 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;

/* Fifth check - do not attempt to project if training set is empty */
proc sql;
create table check5 as select count(*) as training_count from check4;
quit;
data _null_;
set check5;
if training_count = 0 then call symput('do_ptb_projection','no');
run;
%put do_ptb_projection = &do_ptb_projection;

/* Once all checks are complete, choose a macro */
%Projections_&do_ptb_projection.();

/* Choose a Referal Macro */
%Referal_&AddRefDoc.();

/* Choose a Print Macro */
%Print_&do_ptb_projection.();


/* MODIFICATION 3.18.2018: New file formats */

data temp;
set Office.All_&Counting._PRED;
if HMS_POID = '' then HMS_POID = 'MISSING';
if HMS_PIID = '' then HMS_PIID = 'MISSING';
run;

proc means data=temp nway sum noprint;
class HMS_PIID / missing;
var FINAL_EST_TOTAL;
output out=prac_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc means data=temp nway sum noprint;
class HMS_POID / missing;
var FINAL_EST_TOTAL;
output out=org_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc means data=temp nway sum noprint;
class HMS_PIID HMS_POID / missing;
var FINAL_EST_TOTAL;
output out=prac_org_proj(drop=_TYPE_ _FREQ_) sum=COUNT;
run;

proc export data=prac_proj outfile='prac_proj.txt' replace;
run;
proc export data=org_proj outfile='org_proj.txt' replace;
run;
proc export data=prac_org_proj outfile='prac_org_proj.txt' replace;
run;

/* **************************************** END OF LINE *************************************** */

/* *****************************************************************************
PROGRAM NAME:				IP_Facility_Proj.sas
PURPOSE:					Facility Projections for IP
PROGRAMMER:					Mark Piatek
CREATION DATE:				05/1/2017
UPDATED:					
NOTES:						Facility Projections for IP
INPUT FILES:				
OUTPUT FILES:				Facility_counts_output.sas
MACROS USED:				
RUN BEFORE THIS PROGRAM:	createpoidlists.sas, ipmatrix.sas, Poid_Prep.sas
RUN AFTER THIS PROGRAM:		
******************************************************************************** */

options mprint;
libname mylib '.';

data mylib.input;
infile "input.txt" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	format Parameter	$50. ;
	format Value 	$200. ;
	informat Parameter	$50. ;
	informat Value 	$200. ;
	input Parameter $ Value $ ;
run;

/* MODIFICATION 6/22/2016: Add in PROJECTIP parameter */
/* set project ip decision to empty */
%let projectip = ;

/* set macro variables for facility count estimation parameters */
data _null_;
set mylib.input;
*if Parameter = 'PROJECTIP' then call symput('projectip', cat("'",trim(left(compress(value))),"'")); /* END MODIFICATION */
if Parameter = 'PROJECTIP'  then call symput('projectip', trim(left(compress(value))));
if upcase(Parameter) = 'VINTAGE' then call symput('used_vintage', put(value,8.));
if Parameter = 'BUCKET'  then call symput('bucket',cat("'",trim(value),"'"));
if Parameter = 'FXFILES'  then call symput('fxfiles', trim(left(compress(value))));
if Parameter = 'INSTANCE'  then call symput('instance', trim(left(compress(value))));
if Parameter = 'USERNAME'  then call symput('username', trim(left(compress(value))));
if Parameter = 'PASSWORD'  then call symput('password', trim(left(compress(value))));
if Parameter = 'AGGREGATION_ID'  then call symput('aggregation_id', trim(left(compress(value))));
if Parameter = 'AGGREGATION_TABLE'  then call symput('aggregation_table', trim(left(compress(value))));
if Parameter = 'CODETYPE' then call symput('codetype', trim(left(compress(value))));
if Parameter = 'COUNTTYPE' and VALUE = 'PATIENT' then call symput('counttype','CLAIM');
else if Parameter = 'COUNTTYPE' and VALUE ~= 'PATIENT' then call symput('counttype',trim(left(compress(value))));

/* If old DB instance, refer to old Aggr count names */
if Parameter = 'INSTANCE' and Value = 'pldwhdbr' then do;
	call symput('TOTAL_COUNT','TOTAL_COUNT');
	call symput('MDCR_COUNT','MDCR_COUNT');
end;
/* New DB names to come in subsequent step */
run;

data _null_;
 set mylib.input;

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
                call symput('TOTAL_COUNT','CLAIM_CNT');
                call symput('MDCR_COUNT','MDCR_CLAIM_CNT');
        end;
end;

run;

%put 'Vintage :' &used_vintage;
%put 'Bucket :' &bucket;
%put 'FXFILES :' &fxfiles;
%put 'INSTANCE :' &instance;
%put 'USERNAME :' &username;
%put 'PASSWORD :' &password;
%put 'CODETYPE :' &codetype;
%put 'COUNTTYPE :' &counttype;
%put 'AGGREGATION_ID :' &aggregation_id;
%put 'AGGREGATION_TABLE :' &aggregation_table;
%put 'TOTAL_COUNT :' &TOTAL_COUNT;
%put 'MDCR_COUNT :' &MDCR_COUNT;
%put 'PROJECTIP :' &projectip;

/* set libraries for local folders */  
libname O_WK Oracle user=&username. password=&password. path=&instance.;
libname fxfiles %unquote(%str(%'&FXFILES%'));

/* set global macro variables */
%let rnd_sfx = 1000;

/* set references with vintage */
%let POID_address_table = DDB_&used_vintage..M_ORGANIZATION_ADDRESS;  
%let address_zip_table = DDB_&used_vintage..M_ADDRESS_ORG;

/* set GLMSELECT variables to choose from */
/* MODIFICATION 6/22/2016: remove some variables related to medicare */
/* MODIFICATION 3/23/2016: further remove some medicaid variables for All-codes jobs */
/* MODIFICATION 5/25/2017: remove variables based on VARCLUS analysis */
/* MODIFICATION 1/28/2020: Remove MType and MAPP6 since no longer available in AHA file */
data _NULL_;
   call symput ("catvars_GLMSel", cat("RESP CHC COMMTY LOS ",
									  "MAPP1 MAPP2 MAPP3 MAPP5 MAPP7 MAPP8 ",
									  "MAPP11 MAPP12 MAPP13 MAPP16 MAPP18 MAPP19 MAPP20 ")); 
if "&Codetype." = "ALL" then do;
/*   call symput ("numvars_Partial", cat("TactInsField Unemp ",
									  "log_Adj_Beds  log_Adj_SurOpIP log_Adj_SurOpOP log_Adj_AdmTot ",
									  "log_IPDTOT log_Adj_VEM log_VOTH log_FTMDTF log_FTRES log_FTRNTF ",
									  "log_Adj_ADC log_ADJADM log_ADJPD ")); */
   call symput ("numvars_Partial", cat("TactInsField Unemp ",
									  "log_MCDDC ",
									  "log_Adj_Beds log_Adj_SurOpIP log_FTMDTF ")); 
end;
else do;
/*call symput ("numvars_Partial", cat("TactInsField Unemp ",
									  "log_Adj_Beds  log_Adj_SurOpIP log_Adj_SurOpOP log_Adj_AdmTot ",
									  "log_IPDTOT log_MCDDC log_MCDIPD ",
									  "log_Adj_VEM log_VOTH log_FTMDTF log_FTRES log_FTRNTF ",
									  "log_Adj_ADC log_ADJADM log_ADJPD ")); */
   call symput ("numvars_Partial", cat("TactInsField Unemp ",
									  "log_MCDDC ",
									  "log_Adj_Beds log_Adj_SurOpIP log_FTMDTF ")); 
end;
run;
/* END MODIFICATIONS */

/* initialize global macro variables */
%let numvars_GLMSel  = ;
%let catvars_GLMSel  = ;
%let NObsUsed_GLMSel = ; 
%let AdjRSq_GLMSel   = ;
%let med_train1      = ; 
%let med_test1       = ;
%let catvars_GLM     = ;
%let numvars_GLM     = ;
%let NObsUsed_GLM    = ; 
%let RSq_GLM         = ;
%let med_all         = ; 

proc sql;
connect to oracle(user=&username. password=&password. path=&instance.); 
	create table mylib.WK_POIDCounts as
	select *
	from connection to oracle
	(select org_id as hms_poid, 
	&TOTAL_COUNT. as claim4d_total, 
	&MDCR_COUNT. as claim4d_mcare
	from &aggregation_table. 
	where aggr_name='WKUB_IP' and aggr_level = 'ORGLEVEL' and
	job_id=&aggregation_id. and bucket_name=&bucket.
	);	
disconnect from oracle ; 
quit ;

data mylib.WK_POIDCounts(drop=oldpoid);
set mylib.WK_POIDCounts(rename=(HMS_POID=OLDPOID));
HMS_POID=put(OLDPOID,$10.);
run;  

/* remove blank POIDs and calculate POID counts */
data mylib.Temp;
set mylib.WK_POIDCounts;
if hms_poid ~= '';
run;
proc sql;
	create table mylib.WK_POIDCounts as
	select hms_poid, 
	sum(claim4d_total) as claim4d_total,
	sum(claim4d_mcare) as claim4d_mcare
	from mylib.Temp
	group by hms_poid;
quit;

/* Get latest claim counts from aggr tables for bucket */
%macro Get_State_Counts_HG(aggr_name=,xstate=,ytable=);

proc sql;
connect to oracle(user=&username. password=&password. path=&instance.);
create table mylib.&ytable
(label="&xstate IPclaims in latest 12 mo, &sysdate.")
as 
select * from connection to oracle
	(select hdr.org_id as hms_poid, 
	hdr.&TOTAL_COUNT. as claim4d_total, 
	hdr.&MDCR_COUNT. as claim4d_mcare
	from &aggregation_table. hdr
	where hdr.bucket_name = &bucket. and
	aggr_name=&aggr_name. and aggr_level = 'ORGLEVEL' and
	job_id=&aggregation_id.
	);	
disconnect from oracle ;
quit ;

/* Reformat the POID List */
data mylib.&ytable(drop=oldpoid);
set mylib.&ytable(rename=(hms_poid=oldpoid));
HMS_POID=put(oldpoid,$10.);
run;
 
%mend Get_State_Counts_HG;

%Get_State_Counts_HG(aggr_name='AZ_IP',xstate=AZ,ytable=AZ_IP_Raw);
%Get_State_Counts_HG(aggr_name='FL_IP',xstate=FL,ytable=FL_IP_Raw);
%Get_State_Counts_HG(aggr_name='NV_IP',xstate=NV,ytable=NV_IP_Raw);
%Get_State_Counts_HG(aggr_name='NY_IP',xstate=NY,ytable=NY_IP_Raw);
%Get_State_Counts_HG(aggr_name='WA_IP',xstate=WA,ytable=WA_IP_Raw);
%Get_State_Counts_HG(aggr_name='CA_IP',xstate=CA,ytable=CA_IP_Raw);
%Get_State_Counts_HG(aggr_name='TX_IP',xstate=TX,ytable=TX_IP_Raw);
%Get_State_Counts_HG(aggr_name='NJ_IP',xstate=NJ,ytable=NJ_IP_Raw);

/* combine counts from different states */
data mylib.State_POIDCounts;
set
mylib.AZ_IP_Raw(IN=InAZ)
mylib.FL_IP_Raw(IN=InFL)
mylib.NV_IP_Raw(IN=InNV)
mylib.NY_IP_Raw(IN=InNY)
mylib.WA_IP_Raw(IN=InWA)
mylib.CA_IP_Raw(IN=InCA)
mylib.NJ_IP_Raw(IN=InNJ)
mylib.TX_IP_Raw(IN=InTX);
if      InAZ then source='AZ';
else if InFL then source='FL';
else if InNV then source='NV';
else if InNY then source='NY';
else if InWA then source='WA';
else if InCA then source='CA';
else if InNJ then source='NJ';
else if InTX then source='TX';
run;

/* remove blank POIDs and calculate POID counts */
data mylib.temp;
set mylib.State_POIDCounts;
if HMS_POID ~= '';
if substr(HMS_POID,1,3) ~= 'Not';
run;
proc sql;
create table mylib.State_POIDCounts as
	select HMS_POID, source,
	sum(claim4d_total) as claim4d_total,
	sum(claim4d_mcare) as claim4d_mcare
	from mylib.Temp
	group by HMS_POID, source;
quit;

proc sql;
connect to oracle(user=&username. password=&password. path=&instance.); 
	create table mylib.CMS_POIDCounts as
	select * from connection to oracle
		(select org_id as HMS_POID, &TOTAL_COUNT. as claim4d_total
		from &aggregation_table.
		where aggr_name='CMS_IP'
		and aggr_level = 'ORGLEVEL'
		and job_id=&aggregation_id.
		and bucket_name=&bucket.
		);	
	disconnect from oracle ; 
quit ;

data mylib.CMS_POIDCounts(drop=oldpoid);
set mylib.CMS_POIDCounts(rename=(HMS_POID=oldpoid));
HMS_POID = put(oldpoid,$10.);
run;  

/* Remove blank POIDs and calculate POID counts */
data mylib.Temp;
set mylib.CMS_POIDCounts;
if HMS_POID ~= '';
run;
proc sql;
create table mylib.CMS_POIDCounts as
select HMS_POID, sum(claim4d_total) as claim4d_total
from mylib.Temp
group by HMS_POID;
quit;

/* All attribute-related code have been removed,
   now run at the project level (not bucket-level) in the POID prep process */

/* Insert WK/State/CMS claim volume */
proc sql;
create table mylib.Temp as
select a.*, b.claim4d_total as WK_total_4d, b.claim4d_mcare as WK_mcare_4d 
from mylib.POID_Attributes_IP a
left join mylib.WK_POIDCounts b
on a.HMS_POID=b.HMS_POID;
quit;

/* MODIFICATION 6/22/2016: add in WK Poid Count step */
/****WK poid counts***/
data WK_POIDCounts;
set mylib.Temp(where=(HMS_POID~='MISSING'));
if  poid_class ~= 1 and WK_total_4d ~= .;
keep HMS_POID wk_total_4d wk_mcare_4d;
run;
/* END MODIFICATION */

proc sql;
create table mylib.Temp1 as
select a.*, b.source as State_source, b.claim4d_total as State_total_4d, b.claim4d_mcare as State_mcare_4d
from mylib.Temp a
left join mylib.State_POIDCounts b
on a.HMS_POID=b.HMS_POID;
quit;

/* MODIFICATION 6/22/2016: add in State Poid Count step, extra steps */
data State_POIDCounts;
set mylib.Temp1(where=(HMS_POID~='MISSING'));
if State_total_4d~=.;
keep HMS_POID State_total_4d State_mcare_4d;
run;

/* figure out medicare fraction in state and WK ub data
   output total, medicare, and fraction for both to a file
   use fraction based on wk to make projections decision */

data wkstate_POIDCounts;
merge WK_POIDCounts State_POIDCounts;
by HMS_POID;
run;

proc means data=wkstate_POIDCounts noprint nway sum;
output out=allpayer_counts(drop=_type_ _freq_) sum=;
run;

data mylib.IP_Med_Fraction;
set allpayer_counts;
wk_med_fraction=wk_mcare_4d/wk_total_4d;
State_Med_Fraction=State_mcare_4d/State_total_4d;
run;

proc export data=mylib.IP_Med_Fraction outfile='IP_Med_Fraction.txt' dbms=tab replace;
run;

%put ****Original PROJECTIP=&projectip****;

/* if input file specifies whether or not to project, use that information
   otherwise, decide to project only if wk medicare capture is >= 0.05 */

%macro projectip;
%if %upcase(&projectip) NE N and %upcase(&projectip) NE Y %then %do;

/* MODIFICATION 11/28/2017: initialize projectip in case no data present */
%let projectip=N;

data _null_;
set mylib.IP_Med_Fraction;
if wk_med_fraction < .05 then 
call symput('projectip','N');
else call symput('projectip','Y');
if wk_med_fraction < .05 then PROJECTIP = 'N';
else PROJECTIP = 'Y';
run;

%end;

data projectip_out;
set mylib.IP_Med_Fraction;
PROJECTIP = "&PROJECTIP.";
keep PROJECTIP;
run;

proc sql;
create table check_count as select count(*) as countIP from projectip_out;
quit;

data check_count;
set check_count;
if countIP = 0 then call symput('zerocount','N');
else call symput('zerocount','Y');
if countIP = 0 then PROJECTIP = 'N';
drop countIP;
run;

%put zerocount= &zerocount.;

/* MODIFICATION 2/9/2018: output PROJECTIP value for use in practitioner step */
%if %upcase(&zerocount) = N %then %do;
proc export data=check_count outfile='projectip.txt' replace;
run;
%end;
%else %if %upcase(&zerocount) NE N %then %do;
proc export data=projectip_out outfile='projectip.txt' replace;
run;
%end;

%put ****PROJECTIP= &projectip****;

%mend;

%projectip;
/* END MODIFICATION */

proc sql;
create table mylib.POID_Counts as
select a.*, b.claim4d_total as CMS_total_4d
from mylib.Temp1 a
left join mylib.CMS_POIDCounts b
on a.HMS_POID=b.HMS_POID;
quit;

/* Set missing code claim volume to zero if POID total claim volume > 0 */ 
data mylib.POID_Counts;
set mylib.POID_Counts;
if WK_Listed = 1 then do;
	if WK_total_4d = . then WK_total_4d = 0;
	if WK_mcare_4d = . then WK_mcare_4d = 0;
end;
if State_Listed = 1 then do;
	if State_total_4d = . then State_total_4d = 0;
	if State_mcare_4d = . then State_mcare_4d = 0;
end;
if CMS_Listed = 1 then do;
	if CMS_total_4d = . then CMS_total_4d = 0;
end;
run;

/* MODIFICATION 6/22/2016: See Jin's comment below */
/* if we have PROJECTIP = 'N', then make CMS 4d = missing,
   because we don't want to use it in validity assessments */

%macro setcmszero;
%if %upcase(&projectip) = N  %then %do;

data mylib.POID_Counts;
set mylib.POID_Counts;
CMS_total_4d = .;
run;

%end;

%put ****PROJECTIP= &projectip****;

%mend;

%setcmszero;
/* END MODIFICATION */


/*
Dilip moved the validity flag calculation here from the end
so that we can use it in selecting co-variates for the model

for POIDs in all 3 sources, keep Ozgur's logic
for POIDs with 2 sources add check that all p medicare needs to be
 ge 50% of cms

also, if poid_class=1, then automatically set wk_valid to 0
*/

/* Validate claim sources based on comparison with each other */  
/* Invalidate source that deviates the most if it is more than 25% deviation from average of the three */
/* If one source is missing do the 2-source check on the other two */
data mylib.POID_Counts;
set mylib.POID_Counts;
if wk_mcare_4d = . or poid_class = 1 then WK_valid = 0;
else WK_valid = 1;
if state_mcare_4d = . then State_valid = 0;
else State_valid = 1;
if cms_total_4d = . then CMS_valid = 0;
else CMS_valid = 1;

if wk_mcare_4d ~= . and state_mcare_4d ~= . and cms_total_4d ~= .
and (poid_class eq . or poid_class > 1) then do;
	avg_mcare = (wk_mcare_4d + state_mcare_4d + cms_total_4d) / 3;
	wk_dist = round(abs(wk_mcare_4d - avg_mcare),0.01);
	st_dist = round(abs(state_mcare_4d - avg_mcare),0.01);
	cms_dist = round(abs(cms_total_4d - avg_mcare),0.01);
	if wk_dist > st_dist and wk_dist > cms_dist then do;
		if wk_dist > 0.25 * avg_mcare then WK_valid = 0;       
	end;
	else if st_dist > wk_dist and st_dist > cms_dist then do;
		if st_dist > 0.25 * avg_mcare then State_valid = 0;       
	end;
	else if cms_dist > wk_dist and cms_dist > st_dist then do;
		if cms_dist > 0.25 * avg_mcare then CMS_valid = 0;       
	end;
end;

/* 2 source checks added below */
else if wk_mcare_4d ~= . and cms_total_4d ~= .
and (poid_class eq . or poid_class > 1) then do;
	/* tweaked the clause and the state one too
	if wk_mcare_4d > 0 and wk_mcare_4d < 0.5*cms_total_4d then WK_valid=0; */
	if wk_mcare_4d = 0 and cms_total_4d = 0 then WK_valid=1;
	else if wk_mcare_4d = 0 and wk_total_4d = 0 and 
	cms_total_4d > 0 then wk_valid=0;
	else if wk_mcare_4d = 0 and wk_total_4d > 0 then do;
		if wk_total_4d > cms_total_4d then wk_valid=1;
		else wk_valid=0;
	end;
	else if wk_mcare_4d < 0.5*cms_total_4d then WK_valid=0;
end;

else if state_mcare_4d ~= . and cms_total_4d ~= . then do;
	if state_mcare_4d = 0 and cms_total_4d = 0 then state_valid=1;
	else if state_mcare_4d = 0 and state_total_4d = 0 and
	cms_total_4d > 0 then state_valid = 0;
	else if state_mcare_4d = 0 and state_total_4d > 0 then do;
		if state_total_4d > cms_total_4d then state_valid=1;
		else state_valid = 0;
	end;
	else if state_mcare_4d < 0.5*cms_total_4d then State_valid=0;
end;

myratio = wk_mcare_4d/cms_total_4d; /* Mark Note: ltos of division by zero here */
drop avg_mcare wk_dist st_dist cms_dist;
run;

/* Select all-payer claim volume: State if exists, WK otherwise */
/* Modification by Dilip - can use source only if valid_flag=1 */
data mylib.POID_Counts;
set mylib.POID_Counts;
if State_Listed = 1 and state_valid = 1 then do;
	AllP_total_4d = State_total_4d;
	AllP_mcare_4d = State_mcare_4d;
	allp_claim_source = state;
end;
/* Dilip change to treat POID_class missing as better than 1 */
else if WK_Listed = 1 and ( POID_class eq . or POID_class > 1) and WK_valid = 1 then do;
/* use WK claim only if POID is reliable i.e. POID_class > 1 */
	AllP_total_4d = WK_total_4d;
	AllP_mcare_4d = WK_mcare_4d;
	allp_claim_source = 'WK';
end;
run;

/* DEBUG save the poid counts dataset for inspection */
data mylib.POID_Counts_Saved;
set mylib.POID_Counts;
run;

/*
Dilip modifications here
calculate POID-level projection factor and save it for use in phys step
calculate allowable range of capture rate and adjust POID_counts
to use all payer data only if capture rate within allowable range
calculate max allowed pf 
*/

data mylib.poidpf;
set mylib.POID_Counts;
keep HMS_POID pf medcaptrans;
if AllP_total_4d > 0 and AllP_mcare_4d > 0 then pf = AllP_total_4d/AllP_mcare_4d;
else pf = .;
medcapt=1/pf;
medcaptrans=log(medcapt/(1-medcapt));
run;

proc means data=mylib.poidpf nway q1 q3 noprint;
var medcaptrans;
output out=iqrvalues q1=q1 q3=q3;
run;

data _null_;
set iqrvalues;
call symput ('q1', q1);
call symput ('q3', q3);
call symput ('freq', _freq_);
run;

data _null_ ;
length buffer1 $ 10;
length buffer2 $ 10;
buffer1=&q1-1.5*(&q3-&q1);
call symput('lowcaptrans',buffer1);
buffer2=&q3+1.5*(&q3-&q1);
call symput('highcaptrans',buffer2);
run;

data _null_;
length buffer1 $ 10;
length buffer2 $ 10;
buffer1=1/(1+exp(-&lowcaptrans));
call symput('lowcap',buffer1);
buffer2=1/(1+exp(-&highcaptrans));
call symput('highcap',buffer2);
run;

data _null_;
length buffer1 $ 10;
length buffer2 $ 10;
buffer1=1/&highcap;
call symput('lowpf',buffer1);
buffer2=1/&lowcap;
call symput('highpf',buffer2);
run;

%put 'q1:' &q1;
%put 'q3:' &q3;
%put 'lowpf:' &lowpf;
%put 'highpf:' &highpf;
%put 'freq:' &freq;

/* Output a dataset with pfmax */
data mylib.pfmax;
pfmax=&highpf.;
run;

/* Now ensure that poidpf dataset has values in allowed range */

/* MODIFICATION 6/22/2016: This step becomes needed only if projecting */
%macro skipprojection;
%if %upcase(&projectip) = Y %then %do;

/* Merge with POID_Counts dataset and adjust allp data */
/* If pf is outside range, then allp data set to missing */
proc sort data = mylib.poidpf;
by HMS_POID;
run;
proc sort data = mylib.POID_Counts;
by HMS_POID;
run;
data mylib.POID_Counts;
merge mylib.POID_Counts mylib.poidpf;
by HMS_POID;
run;

/* Keep poids with either all payer total = 0, or
pf within the range */
data mylib.POID_Counts;
set mylib.POID_Counts;
if AllP_total_4d ~= 0  and (pf < &lowpf. or pf > &highpf.) then do;
	AllP_total_4d = .;
	AllP_mcare_4d = .;
end;
run;

%end;

%put ****PROJECTIP= &projectip****;

%mend;

%skipprojection;
/*END MODIFICATION */
 
/* Log claim volumes */
data mylib.POID_Counts;
set mylib.POID_Counts;
log_allp_total_4d = log10(allp_total_4d+1); 
log_allp_mcare_4d = log10(allp_mcare_4d+1); 
log_cms_total_4d = log10(cms_total_4d+1); 
run;

/* Identify rows with no categorical/numerical AHA/MDSI/bed data */
data mylib.POID_Counts;
set mylib.POID_Counts;
if RESP='' and CHC='' and COMMTY='' and LOS='' and MAPP1=''
and MAPP2='' and MAPP3='' and MAPP5='' and MAPP7='' and
MAPP8='' and MAPP11='' and MAPP12='' and MAPP13='' and MAPP16='' and
MAPP18='' and MAPP19='' and MAPP20='' then AHA_Cat_Empty = 1;
else AHA_Cat_Empty = 0;
if Adj_Beds=. and Adj_Births=. and Adj_SurOpIP=. and Adj_SurOpOP=. and
Adj_AdmTot=. and IPDTOT=. and MCRDC=. and MCRIPD=. and MCDDC=. and
MCDIPD=. and Adj_VEM=. and VOTH=. and FTMDTF=. and FTRES=. and FTRNTF=.
and Adj_ADC=. and ADJADM=. and ADJPD=. then AHA_Num_Empty = 1;
else AHA_Num_Empty = 0;
run;

/* Set claim actual and relevant metrics */
data mylib.POID_Counts;
set mylib.POID_Counts;
claim_actual = allp_total_4d;
log_claim_actual = log_allp_total_4d;
claim_exists = claim_actual ~= .;
run; 

/* Identify POIDs for GLMSelect procedure - from State or from WK with POID_class > 1, non-empty AHA fields */
data mylib.POID_Counts;
set mylib.POID_Counts;
length GLMSel_Role $ 10;
/* Dilip change to treat POID_class missing as better than 1 */
if (State_Listed = 1 or (WK_Listed = 1 and ( POID_class eq . or POID_class > 1)) ) and
(AHA_Cat_Empty = 0 and AHA_Num_Empty = 0 ) and allp_total_4d ~= .
then GLMSel_Role = 'Eligible';
else GLMSel_Role = 'None';
run;

/* Split POID into two groups:: Estimation with nonzero claim count and Prediction with zero claim count */
data mylib.Temp1;
set mylib.POID_Counts;
if GLMSel_Role = 'Eligible' and claim_actual > 0;
run;
data mylib.Temp2;
set mylib.POID_Counts;
if GLMSel_Role = 'Eligible' and NOT(claim_actual > 0); 
run;
	
/* Count number of zero- and nonzero-claim POIDs;
   Set ratio of zero- to nonzero claim POIDs */
%macro zero_counts;
proc sql;
create table nonzerocount as select count(*) as nonzerocount from mylib.Temp1;
quit;
data _null_;
set nonzerocount;
call symput('nonzerocount',left(trim(nonzerocount)));
run;
proc sql;
create table zerocount as select count(*) as zerocount from mylib.Temp2;
quit;
data _null_;
set zerocount;
call symput('zerocount',left(trim(zerocount)));
/* set pickratio to 1 because no poids exist with zero claims */
call symput('pickratio',left(trim('1')));
run;
%put Zero-Claim POIDs = &zerocount
NonZero-Claim POIDs = &nonzerocount
Frac. Zero-Claim POIDs Picked = &pickratio;
%mend zero_counts;
%zero_counts;

/* Select POIDs to use for estimation (test and training) by GLMSELECT */ 
proc sort data=mylib.Temp2;
by Adj_Beds;
run;
data mylib.Temp2; 
set mylib.Temp2;
if ranuni(2) <= &pickratio. then GLMSel_Role = 'Eligible';
else GLMSel_Role = 'None';
run;
data mylib.Temp; 
set mylib.Temp2;
if GLMSel_Role = 'Eligible';
run;
data mylib.Temp1;
set mylib.Temp1 mylib.Temp;
run;
/* Sort to select more uniformly across claim sources */
proc sort data=mylib.Temp1; 
by allp_claim_source;
run;
/* Set test and training sets */
data mylib.Temp1; 
set mylib.Temp1;
if ranuni(1) > 0.333 then GLMSel_Role = 'Train';
else GLMSel_Role = 'Test';
run;

/* Select POIDs to use for score by GLM */
data mylib.Temp; 
set mylib.POID_Counts;
if GLMSel_Role = 'None';
run;
data mylib.Temp2; 
set mylib.Temp2;
if GLMSel_Role = 'None';
run;
data mylib.Temp2;
set mylib.Temp2 mylib.Temp;
run;

/* Combine all POIDs in one table */
data mylib.POID_Counts;
set mylib.Temp1 mylib.Temp2;
run;
proc sort data=mylib.POID_Counts;
by HMS_POID;
run;

/* Set GLMSelect input table */
data mylib.POID_Counts_GLMSel;
set mylib.POID_Counts;
if GLMSel_Role in ('Train','Test');
run;

/* run GLMSELECT at 4 different levels */
/* Mark Note: only run at level 4, I guess */
/*%Run_GLMSelect(xlib=&xlib,xlevel=4);*/

/* MODIFICATION 6/22/2016: Add in medicare variables if needed */
/* MODIFICATION 3/23/2017: Do not add medicare/medicaid vars for all-codes */
/*
data _NULL_;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," log_allp_mcare_4d"));
run;
*/
/* if we want to project using medicare, we have to add in the medicare related variables */
/* MODIFICATION 5/25/2017: Remove variables based on VARCLUS analysis */
%macro addmedivars;
%if %upcase(&projectip) = Y  %then %do;
data _NULL_;
if "&Codetype." = "ALL" then do;
call symput("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_allp_mcare_4d"));
end;
else do;
/*call symput("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_MCRDC log_MCRIPD log_allp_mcare_4d"));*/
call symput("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_allp_mcare_4d"));
end;
run;
%end;
%else %do;
data _NULL_;
/*call symput ("numvars_GLMSel", cat("TactInsField Unemp ",
									"log_Adj_Beds log_Adj_Births log_Adj_SurOpIP ",
									"log_MCDIPD ",
									"log_FTMDTF log_FTRES ")); */
call symput ("numvars_GLMSel", cat("TactInsField Unemp ",
									"log_Adj_Beds log_Adj_Births log_Adj_SurOpIP ",
									"log_MCDDC ",
									"log_FTMDTF ")); 
run;

%end;

%put numvars_GLMSel: &numvars_GLMSel;

%mend;

%addmedivars;
/*END MODIFICATIONS */

/* Macros depending on PROJECTIP variable */

%macro GLM_Robust_N;

ods graphics on;
ods output NObs               = mylib.NObs_4;
*ods output FitStatistics      = mylib.FitStatistics_4;
ods output ParameterEstimates = mylib.ParameterEstimates_4;

proc robustreg data=mylib.POID_Counts_GLMSel method=mm outest=robust;
class &catvars_GLMSel.;
model log_claim_actual = &catvars_GLMSel. &numvars_GLMSel. / leverage;
output out=POID_Prediction_4 p=log_claim_pred_GLMSel;
run;
quit;

ods output close;
ods graphics off;

data good_robust;
set mylib.ParameterEstimates_4;
where ProbChiSq < 0.05 and Parameter not in ('Intercept','Scale');
keep parameter;
run;

data Temp1;
set good_robust;
length x1 $256;
length y1 $256;
retain x1 '';
retain y1 '';
if      count("&numvars_GLMSel",parameter,'it') then x1 = catx(' ',x1,parameter);
else if count("&catvars_GLMSel",parameter,'it') then y1 = catx(' ',y1,parameter);
else if count("&catvars_GLMSel",substr(parameter,1,find(parameter,'_','i')-1),'it')
then y1 = catx(' ',y1,substr(parameter,1,find(parameter,'_','i')-1));
call symput("catvars_robust", compbl(y1));
call symput("numvars_robust", TRANWRD(compbl(x1),'allp','adj'));
run;
%put &catvars_robust;
%put &numvars_robust;

data mylib.Temp;
set mylib.Temp;
if _N_ = 1 then call symput ("BestLevel", put(4,1.));
run;

/* Pick tables for selected model */
data mylib.POID_Prediction_GLMSel;
set POID_Prediction_&BestLevel.;
run;
data mylib.NObs_GLMSel;
set mylib.NObs_&BestLevel.;
run;
*data mylib.FitStatistics_GLMSel;
*set mylib.FitStatistics_&BestLevel.;
*run;
data mylib.ParameterEstimates_GLMSel;
set mylib.ParameterEstimates_&BestLevel.;
run;

/* MODIFICATION 6/22/2016: Different variables depending on projecting or not */

/*
data _NULL_;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," log_allp_mcare_&BestLevel.d"));
run;
*/

%if %unquote(%str(%'&projectip%')) = 'Y' or %upcase(&projectip) = 'Y' %then %do;
data _NULL_;
if "&Codetype." = "ALL" then do;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_allp_mcare_&BestLevel.d"));
run;
end;
else do;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_MCRDC log_MCRIPD log_allp_mcare_&BestLevel.d"));
end;
run;
%end;
%else %let numvars_GLMSel=&numvars_Partial;
%put numvars_GLMSel: &numvars_GLMSel;

/* END MODIFICATION */

data mylib.POID_Prediction_GLMSel;
set mylib.POID_Prediction_GLMSel;
claim_pred_GLMSel = int(10 ** log_claim_pred_GLMSel - 1);
pred_dif_GLMSel = claim_pred_GLMSel - claim_actual;
if claim_actual ~= 0 then pct_err_GLMSel = pred_dif_GLMSel/claim_actual;
else pct_err_GLMSel = .;
if claim_actual = 0 and claim_pred_GLMSel ~= . and claim_pred_GLMSel <= 25
then pred_good_GLMSel = 1; 
else if claim_actual = 0 and claim_pred_GLMSel ~= . and claim_pred_GLMSel > 25
then pred_good_GLMSel = -1; 
else if claim_pred_GLMSel = . or pct_err_GLMSel = .
then pred_good_GLMSel = 0;
else if abs(pct_err_GLMSel <= 0.25) or abs(pred_dif_GLMSel) <= 25
then pred_good_GLMSel = 1; 
else pred_good_GLMSel = -1;   
run;


/* Set GLM input table */
data mylib.Temp;
set mylib.POID_Counts;
if GLMSel_Role = 'None';
run;
data mylib.POID_Counts_GLM;
set mylib.POID_Prediction_GLMSel mylib.Temp;
run;
proc sort data=mylib.POID_Counts_GLM;
by HMS_POID;
run;
data mylib.POID_Counts_GLM;
set mylib.POID_Counts_GLM;
if GLMSel_Role in ('Train','Test') then do;
	log_adj_mcare_4d = log_allp_mcare_4d;      
	log_claim_adj    = log_claim_actual;
end;
if GLMSel_Role = 'None' then do;
	log_adj_mcare_4d = log_cms_total_4d;
	log_claim_adj    = .;
end;
run;

/* GLM procedure uses the same Effects found by GLMSELECT but trains with all POIDs used */
ods graphics on;
ods output NObs               = mylib.NObs_GLM;
*ods output FitStatistics      = mylib.FitStatistics_GLM;
ods output ParameterEstimates = mylib.ParameterEstimates_GLM;

proc robustreg data=mylib.POID_Counts_GLM method=mm outest=robust;
class &catvars_robust.;
model log_claim_adj = &catvars_robust. &numvars_robust. / leverage;
output out=mylib.POID_Prediction_GLM p=log_claim_pred_GLM;
run;
quit;

ods output close;
ods graphics off;

%mend;

%macro GLM_Robust_Y;

ods graphics on;
ods output NObs               = mylib.NObs_4;
ods output FitStatistics      = mylib.FitStatistics_4;
ods output ParameterEstimates = mylib.ParameterEstimates_4;

proc glmselect data=mylib.POID_Counts_GLMSel; 
*partition roleVar=GLMSel_Role(test='Test' train='Train');
class &catvars_GLMSel.;
model log_claim_actual = &catvars_GLMSel. &numvars_GLMSel.
/ selection=stepwise(select=SL) stats=all slentry= .05 slstay= .1;
output out=mylib.POID_Prediction_4 p=log_claim_pred_GLMSel; 
run;

ods output close;
ods graphics off;

data mylib.Temp;
set mylib.Temp;
if _N_ = 1 then call symput ("BestLevel", put(4,1.));
run;

/* Pick tables for selected model */
data mylib.POID_Prediction_GLMSel;
set mylib.POID_Prediction_&BestLevel.;
run;
data mylib.NObs_GLMSel;
set mylib.NObs_&BestLevel.;
run;
data mylib.FitStatistics_GLMSel;
set mylib.FitStatistics_&BestLevel.;
run;
data mylib.ParameterEstimates_GLMSel;
set mylib.ParameterEstimates_&BestLevel.;
run;

/* MODIFICATION 6/22/2016: Different variables depending on projecting or not */
/* MODIFICATION 3/23/2017: All-codes variables removed */
/*
data _NULL_;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," log_allp_mcare_&BestLevel.d"));
run;
*/

%if %unquote(%str(%'&projectip%')) = 'Y' or %upcase(&projectip) = 'Y' %then %do;
data _NULL_;
if "&Codetype." = "ALL" then do;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_allp_mcare_&BestLevel.d"));
end;
else do;
call symput ("numvars_GLMSel",cat("&numvars_Partial"," U65pct MaPenet log_MCRDC log_MCRIPD log_allp_mcare_&BestLevel.d"));
end;
run;
%end;
%else %let numvars_GLMSel=&numvars_Partial;
%put numvars_GLMSel: &numvars_GLMSel;

/* END MODIFICATION */

data mylib.POID_Prediction_GLMSel;
set mylib.POID_Prediction_GLMSel;
claim_pred_GLMSel = int(10 ** log_claim_pred_GLMSel - 1);
pred_dif_GLMSel = claim_pred_GLMSel - claim_actual;
if claim_actual ~= 0 then pct_err_GLMSel = pred_dif_GLMSel/claim_actual;
else pct_err_GLMSel = .;
if claim_actual = 0 and claim_pred_GLMSel ~= . and claim_pred_GLMSel <= 25
then pred_good_GLMSel = 1; 
else if claim_actual = 0 and claim_pred_GLMSel ~= . and claim_pred_GLMSel > 25
then pred_good_GLMSel = -1; 
else if claim_pred_GLMSel = . or pct_err_GLMSel = .
then pred_good_GLMSel = 0;
else if abs(pct_err_GLMSel <= 0.25) or abs(pred_dif_GLMSel) <= 25
then pred_good_GLMSel = 1; 
else pred_good_GLMSel = -1;   
run;

/* Set macro variables for performance parameters */
data _NULL_;
set mylib.NObs_GLMSel;
if Label="Number of Observations Used" then call symput("NObsUsed_GLMSel", put(N,best5.));
run;
data _NULL_;
set mylib.FitStatistics_GLMSel;
if Label1="Adj R-Sq" then call symput("AdjRSq_GLMSel", put(round(cValue1,0.0001),best6.));
run;

/* Calculate median absolute percentage error */
/*
data mylib.Temp;
set mylib.POID_Prediction_GLMSel;
pct_err_GLMSel = abs(pct_err_GLMSel);
keep pct_err_GLMSel _ROLE_;
run;
proc sort data=mylib.Temp;
by _ROLE_;
run;
proc univariate data=mylib.Temp noprint;
var pct_err_GLMSel;
by _ROLE_;
output out=mylib.Temp1 median=median;
run;

data mylib.Temp1;
set mylib.Temp1;
if _ROLE_='TRAIN' then call symput("med_train1", put(round(median,0.0001),best5.));
if _ROLE_='TEST'  then call symput("med_test1",  put(round(median,0.0001),best5.));
run;
*/

/* Write GLMSelect fit metrics and model specification into table */
/*
data mylib.Temp;
set mylib.ParameterEstimates_GLMSel(keep=Effect Estimate Probt);
if Probt ~= .;
run;
proc transpose data=mylib.Temp out=mylib.Temp1 prefix=Param_;
var Estimate;
id Effect;
run;
proc transpose data=mylib.Temp out=mylib.Temp2 prefix=PVal_;
var Probt;
id Effect;
run;
data mylib.Temp;
GLMSel_NOObsUsed = &NObsUsed_GLMSel.;
GLMSel_Adj_RSq   = &AdjRSq_GLMSel.;
GLMSel_Med_Train = &med_train1.;
GLMSel_Med_Test  = &med_test1.;
set mylib.Temp1(drop = _NAME_);
set mylib.Temp2(drop = _NAME_ _LABEL_);
run; 
*/
/* Identify predictor variables for GLM */
%put &numvars_GLMSel;
proc sort data=mylib.ParameterEstimates_GLMSel out=mylib.Temp nodupkey;
by Effect;
run;
data mylib.Temp;
set mylib.Temp;
keep Effect;
if Effect ~= 'Intercept';
run; 
data mylib.Temp1;
set mylib.Temp;
length x1 $256;
length y1 $256;
retain x1 '';
retain y1 '';
if      count("&numvars_GLMSel",Effect,'it') then x1 = catx(' ',x1,Effect);
else if count("&catvars_GLMSel",Effect,'it') then y1 = catx(' ',y1,Effect);
else if count("&catvars_GLMSel",substr(Effect,1,find(Effect,'_','i')-1),'it')
then y1 = catx(' ',y1,substr(Effect,1,find(Effect,'_','i')-1));
call symput("catvars_GLM", compbl(y1));
call symput("numvars_GLM", TRANWRD(compbl(x1),'allp','adj'));
run;
%put &catvars_GLM;
%put &numvars_GLM;

/* Set GLM input table */
data mylib.Temp;
set mylib.POID_Counts;
if GLMSel_Role = 'None';
run;
data mylib.POID_Counts_GLM;
set mylib.POID_Prediction_GLMSel mylib.Temp;
run;
proc sort data=mylib.POID_Counts_GLM;
by HMS_POID;
run;
data mylib.POID_Counts_GLM;
set mylib.POID_Counts_GLM;
if GLMSel_Role in ('Train','Test') then do;
	log_adj_mcare_4d = log_allp_mcare_4d;      
	log_claim_adj    = log_claim_actual;
end;
if GLMSel_Role = 'None' then do;
	log_adj_mcare_4d = log_cms_total_4d;
	log_claim_adj    = .;
end;
run;

/* GLM procedure uses the same Effects found by GLMSELECT but trains with all POIDs used */
ods graphics on;
ods output NObs               = mylib.NObs_GLM;
ods output FitStatistics      = mylib.FitStatistics_GLM;
ods output ParameterEstimates = mylib.ParameterEstimates_GLM;

proc glm data=mylib.POID_Counts_GLM;
class &catvars_GLM.;
model log_claim_adj = &catvars_GLM. &numvars_GLM. / solution;
output out=mylib.POID_Prediction_GLM p=log_claim_pred_GLM;
run;
quit;

ods output close;
ods graphics off;

%mend;

/* Run appropriate macro */
%GLM_Robust_&projectip.;

/* Calculate Model Fit */
data mylib.POID_Prediction_GLM;
set mylib.POID_Prediction_GLM;
if log_claim_pred_GLM ~= . then claim_pred_raw = 10 ** log_claim_pred_GLM - 1;
*if claim_pred_raw < 1 then claim_pred_GLM = round(claim_pred_raw,1); /* Use round instead of floor */
*if claim_pred_raw < 1 then claim_pred_GLM = int(claim_pred_raw,1); /* Use floor instead of round */
if 0.9 <= claim_pred_raw < 1 then claim_pred_GLM = round(claim_pred_raw,1); /* Use round only where > 0.9 */
else claim_pred_GLM = int(claim_pred_raw);
pred_dif_GLM = claim_pred_GLM - claim_actual;
if claim_actual NE 0 then pct_err_GLM = pred_dif_GLM/claim_actual;
else pct_err_GLM = .;
if claim_actual = 0 and claim_pred_GLM ~= . and claim_pred_GLM <= 25 then pred_good_GLM = 1; 
else if claim_actual = 0 and claim_pred_GLM ~= . and claim_pred_GLM > 25 then pred_good_GLM = -1; 
else if claim_pred_GLM = . or pct_err_GLM = . then pred_good_GLM = 0;
else if abs(pct_err_GLM <= 0.25) or abs(pred_dif_GLM) <= 25 then pred_good_GLM = 1; 
else pred_good_GLM = -1;
drop claim_pred_raw;
run;

data mylib.NObs_GLM;
set mylib.NObs_GLM;
if Label="Number of Observations Used" then call symput ("NObsUsed_GLM", put(N,best5.));
run;
*data mylib.FitStatistics_GLM;
*set mylib.FitStatistics_GLM;
*call symput ("RSq_GLM", put(round(RSquare,0.0001),best6.));
*run;


/* Choose between actual and predicted claim volume to deliver */
data mylib.POID_Prediction_GLM;
set mylib.POID_Prediction_GLM;

/* Nevada and TX state claims data does not allow us to vend their data to our customers */
/* Also NJ after switching to HCUP purchase for 2012 data onwards - removing NJ 9/25/2019 based on Advisory Board acquisition of data */
/* Set delivery to allpayer or CMS total count if no prediction can be made due to missing predictor variables */
if claim_pred_GLM = . then do;
	if State_valid = 1 and NOT(State_source in ('NV','TX')) then claim_dlvry = State_total_4d;
	else if WK_valid = 1 then claim_dlvry = WK_total_4d;
	else if CMS_valid = 1 then claim_dlvry = CMS_total_4d;
	else claim_dlvry = 0;
end;
else do;
	if State_valid = 1 and NOT(State_source in ('NV','TX')) then  claim_dlvry = State_total_4d;
	else if WK_valid = 1 then claim_dlvry = WK_total_4d;
	/* constrain delivery to be at least equal to allpayer or CMS total count */
	else if CMS_valid = 1 then claim_dlvry = max(CMS_total_4d,claim_pred_GLM);
	else claim_dlvry = claim_pred_GLM;
end;

run;
	
/* Output results in one table */
data mylib.Facility_Counts_Output;
set mylib.POID_Prediction_GLM (rename=(claim_pred_GLMSel=claim_GLMSel claim_pred_GLM=claim_GLM));
keep hms_poid claim_actual claim_dlvry wk_mcare_4d state_mcare_4d cms_total_4d WK_valid State_valid CMS_valid POID_Class;
run;

/* ****************** SAVE PLOTS IN PDF *********************** */

/* get max value for GLMSELECT axis ranges */
proc means data=mylib.POID_Prediction_GLMSel max;
var log_claim_pred_GLMSel log_claim_actual;
output out=mylib.Temp; 
run;

data _NULL_;
set mylib.Temp;
if _STAT_='MAX' then call symput ("max_glmsel", put(ceil(max(log_claim_pred_GLMSel,log_claim_actual)),best3.));
run;

/* get max value for GLM axis ranges */
proc means data=mylib.POID_Prediction_GLM max;
var log_claim_pred_GLM log_claim_adj;
output out=mylib.Temp;
run;

data _NULL_;
set mylib.Temp;
if _STAT_='MAX' then call symput ("max_glm", put(ceil(max(log_claim_pred_GLM,log_claim_adj)),best3.));
run;

/* prepare data for y=x reference line */
data annodata;
   function='move';
   xsys="1"; ysys="1";
   x=0;      y=0;
   output;
   function='draw';
   xsys="1"; ysys="1";
   color='gray';
   x=100;    y=100;
   output;
run;

goptions reset=all border device=PDF;
options orientation=Landscape;
ods pdf file="Model_Fit.pdf"; 
ods pdf style=normal;

/* plot GLMSELECT fit */
symbol1 i=none v=dot c=blue    h=0.2;
symbol2 i=none v=dot c=red     h=0.2;
symbol3 i=none v=dot c=green   h=0.2;
axis1 label=(a=90 'GLMSELECT Log Predicted Claims - log_claim_pred_GLMSel') order=(-1 to &max_glmsel by 1);
axis2 label=(a=0  'Log Actual Claims - log_claim_actual')             order=(-1 to &max_glmsel by 1); 
title1 "Predicted vs. Actual: &Setting &source Facility Claim Counts" font='Helvetica' height=12pt;
title2 "Obs Used=&NObsUsed_GLMSel - Adj R-Sq=&AdjRSq_GLMSel - Median % Error(TRAIN)=&med_train1.% - Median % Error(TEST)=&med_test1.%" font='Helvetica' height=10pt;
title3 "Categorical: &catvars_GLM" font='Helvetica' height=10pt;
title4 "Numerical: &numvars_GLM" font='Helvetica' height=10pt;
proc gplot data=mylib.POID_Prediction_GLMSel;
plot log_claim_pred_GLMSel * log_claim_actual  / vaxis=axis1 haxis=axis2 anno=annodata; 
run;
quit;

/* plot GLM fit */
symbol1  i=none v=dot c=blue    h=0.2;
symbol2  i=none v=dot c=red     h=0.2;
symbol3  i=none v=dot c=green   h=0.2;
symbol4  i=none v=dot c=yellow  h=0.2;
symbol5  i=none v=dot c=cyan    h=0.2;
symbol6  i=none v=dot c=orange  h=0.2;
symbol7  i=none v=dot c=violet  h=0.2;
symbol8  i=none v=dot c=magenta h=0.2;
symbol9  i=none v=dot c=brown   h=0.2;
symbol10 i=none v=dot c=black   h=0.2;
symbol11 i=none v=dot c=gray    h=0.2;
axis1 label=(a=90 'GLM Log Predicted Claims - log_claim_pred_GLM') order=(-1 to &max_glm by 1);
axis2 label=(a=0  'Log Actual Claims - log_claim_actual')      order=(-1 to &max_glm by 1);
title1 "Predicted vs. Actual: &Setting &source Facility Claim Counts" font='Helvetica' height=12pt;
title2 "Obs Used=&NObsUsed_GLM - R-Square=&RSq_GLM - Median % Error=&med_all.%" font='Helvetica' height=10pt;
title3 "Categorical: &catvars_GLM" font='Helvetica' height=10pt;
title4 "Numerical: &numvars_GLM" font='Helvetica' height=10pt;
proc gplot data=mylib.POID_Prediction_GLM;
plot log_claim_pred_GLM * log_claim_adj = state_source / vaxis=axis1 haxis=axis2 anno=annodata; 
run;
quit;

ods pdf close;
goptions reset=all border  device=PDF;


/* Create dup-check file for checking POIDs in same zip */
data mylib.POID_Dup_Check;
retain HMS_POID zip state Adj_Beds POID_Class Matrix_Listed AHA_Listed WK_Listed State_Listed CMS_Listed 
claim_actual claim_pred_GLM claim_dlvry;
set mylib.POID_Prediction_GLM;
keep hms_poid zip state Adj_Beds POID_Class Matrix_Listed AHA_Listed WK_Listed State_Listed CMS_Listed 
claim_actual claim_pred_GLM claim_dlvry;
run;
proc sql;
create table mylib.Temp as
select zip, count(HMS_POID) as zip_POIDs from mylib.POID_Dup_Check group by zip;
quit;   
proc sort data=mylib.POID_Dup_Check out=mylib.Temp1;
by zip;
run;	   
data mylib.POID_Dup_Check;
merge mylib.Temp1 mylib.Temp;
by zip;
run;
proc sort data=mylib.POID_Dup_Check;
by descending zip_POIDs;
run;
proc export data=mylib.POID_Dup_Check
outfile="POID_Dup_Check.txt" dbms=TAB replace;
run;


/* ****************************** CLEAN UP TABLES **************************** */

/* remove output tables from GLMSelect procedure */
proc datasets library=mylib nolist;
delete NObs_4 FitStatistics_4 ParameterEstimates_4 POID_Prediction_4
NObs_GLMSel FitStatistics_GLMSel ParameterEstimates_GLMSel
NObs_GLM FitStatistics_GLM ParameterEstimates_GLM
Temp Temp1 Temp2;
run;

/* Delete the old GRSEGs */
proc greplay igout=work.gseg nofs;
delete _all_;
run;
quit;

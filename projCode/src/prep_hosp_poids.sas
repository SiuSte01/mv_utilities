/* *****************************************************************************
PROGRAM NAME:				Poid_Prep.sas
PURPOSE:					Prepare poid attributes for IP & OP Facility Projections
PROGRAMMER:					Mark Piatek
CREATION DATE:				05/01/2017
UPDATED:					10/21/2016: Removed WebSearch Beds 
                            01/28/2020 - Removed references to MAPP6 and MType in AHA File since no longer available
											also removed use of other bed sources since out of date
NOTES:						
INPUT FILES:				
OUTPUT FILES:				POID_attributes.sas
MACROS USED:				
RUN BEFORE THIS PROGRAM:	createpoidlists.sas, ipmatrix.sas
RUN AFTER THIS PROGRAM:		
******************************************************************************** */

option orientation=landscape;
libname matrloc '.';

data input;
   infile "input.txt" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
   format Parameter	$50. ;
   format Value 	$200. ;
   informat Parameter	$50. ;
   informat Value 	$200. ;
   input Parameter $ Value $ ;
run;

/* set macro variables for facility count estimation parameters */
data _null_;
set input;
if Parameter = 'VINTAGE' then call symput('used_vintage', put(value,8.));
if Parameter = 'FXFILES'  then call symput('fxfiles', trim(left(compress(value))));
if Parameter = 'PROJDIR'  then call symput('projdir', trim(left(compress(value))));
if Parameter = 'INSTANCE'  then call symput('instance', trim(left(compress(value))));
if Parameter = 'USERNAME'  then call symput('username', trim(left(compress(value))));
if Parameter = 'PASSWORD'  then call symput('password', trim(left(compress(value))));
if Parameter = 'BUCKET'  then call symput('bucket',cat("'",trim(value),"'"));
if Parameter = 'AGGREGATION_ID' then call symput('aggregation_id', trim(left(compress(value))));
if Parameter = 'AGGREGATION_TABLE'  then call symput('aggregation_table', trim(left(compress(value))));

if Parameter = 'INSTANCE' and value='pldwhdbr' then do;
	call symput('POID_class_table', 'wk_ub.poid_capture');
end;
if Parameter = 'INSTANCE' and value='pldwh2dbr' then do;
	call symput('POID_class_table', 'claims_aggr.poid_capture');
end;

/* If old DB instance, refer to old Aggr count names */
if Parameter = 'INSTANCE' and Value = 'pldwhdbr' then do;
	call symput('TOTAL_COUNT','TOTAL_COUNT');
	call symput('MDCR_COUNT','MDCR_COUNT');
end;
/* New DB names to come in subsequent step */
run;

data _null_;
 set input;

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

%put 'Vintage: ' &used_vintage;
%put 'FXFILES:' &fxfiles;
%put 'PROJDIR:' &projdir;
%put 'INSTANCE:' &instance;
%put 'PASSWORD:' &password;
%put 'BUCKET :' &bucket;
%put 'AGGREGATION_ID:' &aggregation_id;
%put 'AGGREGATION_TABLE :',&aggregation_table;
%put 'USERNAME:' &username;
%put 'POID_class_table:' &POID_class_table;
%put 'TOTAL_COUNT :',&TOTAL_COUNT;
%put 'MDCR_COUNT :',&MDCR_COUNT;

libname fxfiles %unquote(%str(%'&FXFILES%'));
libname projdir %unquote(%str(%'&PROJDIR%'));

proc sort data=matrloc.ip_Datamatrix out=matrloc.AHA_Data_v3_Mig;
by HMS_POID;
run;

data matrloc.POID_Beds;
set matrloc.AHA_Data_v3_Mig;

Matrix_Listed=1;
MDSI_Listed = 0; /* Always zero since removing use of this as of 1/28/2020 */
AHD_Beds = .; /* No longer using AHD data as of 1/28/2020 */

/* set AHA_Listed to 1 if any AHA data exists */
if SERV ~= '' or RESP ~= '' or CHC ~= '' or COMMTY ~= ''
or LOS ~= '' or MAPP1 ~= '' or MAPP2 ~= '' or MAPP3 ~= '' or MAPP5 ~= ''
or MAPP7 ~= '' or MAPP8 ~= '' or MAPP11 ~= '' or MAPP12 ~= ''
or MAPP13 ~= '' or MAPP16 ~= '' or MAPP18 ~= '' or MAPP19 ~= '' or MAPP20 ~= ''
or HOSPBD ~= . or BDTOT ~= . or BIRTHS ~= . or SUROPIP ~= . or SUROPOP ~= .
or SUROPTOT ~= . or ADMTOT ~= . or IPDTOT NE . or MCRDC ~= . or MCRIPD ~= .
or MCDDC ~= . or MCDIPD ~= . or VEM ~= . or VOTH ~= . or VTOT ~= . or
FTMDTF ~= . or FTRES ~= . or FTRNTF ~= . or ADC ~= . or ADJADM ~= . or ADJPD ~= .
then AHA_Listed = 1;
else AHA_Listed = 0;

run;

/* Should now be always zero for MDSI Listed */
proc freq data=matrloc.POID_Beds;
tables AHA_Listed*MDSI_Listed / list missing;
run;

/* read POID class table from Oracle */
proc sql;
   connect to oracle(user=&username password=&password path=&instance);
   create table matrloc.Temp as
   select *
   from connection to oracle
   (select hms_poid, poidclass as POID_Class
   from &POID_class_table.);	
   disconnect from oracle ; 
quit ;

/* migrate POID characterization table */
proc sort data=matrloc.Temp;
by HMS_POID;
run;
data matrloc.POID_Characterization_Mig;
merge matrloc.Temp (In=Main) fxfiles.poidmigration_lookup_&used_vintage.(In=Mig); 
by HMS_POID;
if Main=1;
if Mig=1 then migrated=1; 
else migrated=0;
run;

/* remove deactivated and invalid POIDs with blank new_poid field */
data matrloc.POID_Characterization_Mig; 
set matrloc.POID_Characterization_Mig;
if migrated=0 or (migrated=1 and new_poid~='');
run;

/* update hms_poid with new_poid */
data matrloc.POID_Characterization_Mig; 
set matrloc.POID_Characterization_Mig;
if migrated=1 then do;
	OLD_POID = HMS_POID;
	HMS_POID = NEW_POID;
end;
drop NEW_POID;
run;   

/* remove duplicates by deleting the row for migrated POID in AHA */
proc sql;
create table matrloc.Temp as
select HMS_POID, count(HMS_POID) as count
from matrloc.POID_Characterization_Mig
group by HMS_POID;
quit;
proc sort data=matrloc.Temp;
by HMS_POID;
run;
proc sort data=matrloc.POID_Characterization_Mig out=matrloc.Temp2;
by HMS_POID;
run;
data matrloc.POID_Characterization_Mig;
merge matrloc.Temp2 matrloc.Temp;
by HMS_POID;
run;
data matrloc.POID_Characterization_Mig;
set matrloc.POID_Characterization_Mig;
if count=1 or (count=2 and migrated=0);
drop poid_migration_status migrated OLD_POID count; 
run;

/* add claim volume metrics to POID table */
/* add POID class to POID table */
proc sort data=matrloc.POID_Beds;
by HMS_POID;
run;
proc sort data=matrloc.POID_Characterization_Mig;
by HMS_POID;
run;
data matrloc.POID_Volume;
merge matrloc.POID_Beds(in=matrix) matrloc.POID_Characterization_Mig(In=Char);
by HMS_POID;
if matrix=1;
if Char=1 then Class_Listed=1;
else Class_Listed=0;
run;

/* copy POID_Volume table into local folder to be used for all buckets */
data matrloc.POID_Volume_&used_vintage.;
set matrloc.POID_Volume;
run;

/* This part pulled from Step 2b (Facility Counts) */

libname matrloc '.';

/* MODIFICATION 08.07.2018: Removed some unnecessary reformats */

/* clean up blank POIDs and duplicates in POID lists */
data projdir.WK_POIDList;
set projdir.WK_POIDList;
if hms_poid ~= '';
run;
proc sort data=projdir.WK_POIDList nodupkey; 
by hms_poid;
run;

data projdir.State_POIDList;
set projdir.State_POIDList;
if hms_poid ~= '';
run;
proc sort data=projdir.State_POIDList nodupkey;
by hms_poid;   
run;

data projdir.CMS_POIDList;
set projdir.CMS_POIDList;
if HMS_POID ~= '';
run;
proc sort data=projdir.CMS_POIDList nodupkey; 
by HMS_POID;
run;

/* Add WK totals to POID table */
data matrloc.POID_Volume;
merge matrloc.POID_Volume_&used_vintage.(in=matrix) /* MODIFICATION 6/22/2016: change to project directory */
projdir.WK_POIDList(in=WK);
by HMS_POID;
if matrix=1;
if WK=1 then WK_Listed=1;
else WK_Listed=0;
run;
/* Add State totals to POID table */
data matrloc.Temp;
merge matrloc.POID_Volume(in=matrix) 
projdir.State_POIDList(in=State);
by HMS_POID;
if matrix=1;
if State=1 then State_Listed=1;
else State_Listed=0;
run;
/* Add CMS totals to POID table */
data matrloc.POID_Volume;
merge matrloc.Temp(in=Main) projdir.CMS_POIDList(in=CMS);
by HMS_POID;
if Main=1;
if CMS=1 then CMS_Listed=1;
else CMS_Listed=0;
run;
data matrloc.POID_Volume;
set matrloc.POID_Volume;
if MDSI_Listed   =.  then MDSI_Listed   = 0;
if Matrix_Listed =.  then Matrix_Listed = 0;
if AHA_Listed    =.  then AHA_Listed    = 0;
if Class_Listed  =.  then Class_Listed  = 0;
if WK_Listed     =.  then WK_Listed     = 0;
if State_Listed  =.  then State_Listed  = 0;
if CMS_Listed    =.  then CMS_Listed    = 0;
run;   

/* Remove POIDs that are missing in WK/State/CMS */
data matrloc.POID_Limited;
set matrloc.POID_Volume;
if WK_Listed=1 or State_Listed=1 or CMS_Listed=1;   
run;

/* Use the already generated and sorted poid/zip/state dataset */
proc sort data=matrloc.POID_Limited out=matrloc.Temp;
by HMS_POID;
run;
data matrloc.POID_Limited;
merge matrloc.Temp(in=Target) fxfiles.POID_Zip_Lookup_&used_vintage.;
by HMS_POID;
if Target=1;
if source_state ~= '' then State = source_state;
else State = zip_state;
drop source_state zip_state;
run;

/* Use state of claim source if state is not found */
data matrloc.POID_Limited;
set matrloc.POID_Limited;
if state in ('AK','AL','AR','AZ','CA','CO','CT','DC',
'DE','FL','GA','HI','IA','ID','IL','IN','KS','KY','LA',
'MA','MD','ME','MI','MN','MO','MS','MT','NC','ND','NE',
'NH','NJ','NM','NV','NY','OH','OK','OR','PA','RI','SC',
'SD','TN','TX','UT','VA','VT','WA','WI','WV','WY')
then valid_state = 1;
else if state = '' then valid_state = .; 
else valid_state = 0;
run;

/* Impute Tactician variables based on zip */
data matrloc.POID_Imputed_Tact;
set matrloc.POID_Limited;
if U65Pct ~= . and MAPenet ~= . and TactInsField ~= .
and Unemp ~= . then Tact_miss = 0;
else Tact_miss = 1;
run;
data matrloc.POID_With_Tact;
set matrloc.POID_Imputed_Tact;
if Tact_miss = 0;
run;
data matrloc.POID_WOut_Tact;
set matrloc.POID_Imputed_Tact;
if Tact_miss = 1;
run;
data matrloc.Temp;
set matrloc.POID_WOut_Tact;
if zip ~= '';
keep HMS_POID ZIP;
run;
proc sort data=matrloc.Temp nodupkey;
by ZIP;
run;
proc sql;
create table matrloc.Temp2 as
select a.zip, a.U65Pct as U65Pct_zip, a.MAPenet as MAPenet_zip,
a.TactInsField as TactInsField_zip, a.Unemp as Unemp_zip
from matrloc.POID_With_Tact a, matrloc.Temp b
where a.ZIP=b.ZIP; 
quit;
proc sort data=matrloc.Temp2 nodupkey;
by ZIP;
run;
proc sort data=matrloc.POID_WOut_Tact out=matrloc.Temp;
by ZIP;
run;
data matrloc.POID_WOut_Tact;
merge matrloc.Temp matrloc.Temp2;
by ZIP;
if U65Pct       = . then U65Pct       = U65Pct_zip;
if MAPenet      = . then MAPenet      = MAPenet_zip;
if TactInsField = . then TactInsField = TactInsField_zip;
if Unemp        = . then Unemp        = Unemp_zip;
drop U65Pct_zip MAPenet_zip TactInsField_zip Unemp_zip;
run;

/* Combine nonmissing and imputed Tactician lists into one */
data matrloc.POID_Imputed_Tact;
set matrloc.POID_With_Tact matrloc.POID_WOut_Tact;
run;

/* Impute Tactician variables based on state */
data matrloc.POID_With_Tact;
set matrloc.POID_Imputed_Tact;
if U65Pct ~= . and MAPenet ~= . and TactInsField ~= . and Unemp ~= . ;
run;
data matrloc.POID_WOut_Tact;
set matrloc.POID_Imputed_Tact;
if U65Pct = . or MAPenet = . or TactInsField = . or Unemp = . ;
run;
data matrloc.Temp;
set matrloc.POID_WOut_Tact;
if STATE ~= '';
keep HMS_POID STATE;
run;
proc sql;
create table matrloc.Temp2 as
select a.state, avg(a.U65Pct) as U65Pct_state, avg(a.MAPenet) as MAPenet_state,
avg(a.TactInsField) as TactInsField_state, avg(a.Unemp) as Unemp_state
from matrloc.POID_With_Tact a,
matrloc.Temp b
where a.STATE=b.STATE
group by a.STATE; 
quit;
proc sort data=matrloc.Temp2;
by STATE;
run;
proc sort data=matrloc.POID_WOut_Tact out=matrloc.Temp;
by STATE;
run;
data matrloc.POID_WOut_Tact;
merge matrloc.Temp matrloc.Temp2;
by state;
if U65Pct       = . then U65Pct       = round(U65Pct_state,0.1);
if MAPenet      = . then MAPenet      = round(MAPenet_state,0.01);
if TactInsField = . then TactInsField = round(TactInsField_state,0.01);
if Unemp        = . then Unemp        = round(Unemp_state,0.1);
drop U65Pct_state MAPenet_state TactInsField_state Unemp_state;
run;

/* Combine nonmissing and imputed Tactician lists into one */
data matrloc.POID_Imputed_Tact;
set matrloc.POID_With_Tact matrloc.POID_WOut_Tact;
run;

/* Pick bedsize in priority order */
data matrloc.POID_Imputed;
set matrloc.POID_Imputed_Tact;
/* MODIFICATION 4.26.2017 - Because of new audit dataset, bed source already exits 
   MODIFICATION 1.28.2020 - Removal of MDSI and AHD means AHA or None are the only values */
length Bed_Source $ 4;
Bed_Source = 'None';
if HospBd ~= . and HospBd > 0 then do;
    Adj_Beds = HospBd;
    Bed_Source = 'AHA';
  end;
else if BdTot ~= . and HospBd > 0 then do;
	Adj_Beds = BdTot;
	Bed_Source = 'AHA';
  end;

if Births ~= . then Adj_Births = Births;
if SurOpIP ~= . then Adj_SurOpIP = SurOpIP;
if SurOpOP ~= . then Adj_SurOpOP = SurOpOP;
if AdmTot ~= . then Adj_AdmTot = AdmTot;
if VEM ~= . then Adj_VEM = VEM;
if ADC ~= . then Adj_ADC = ADC;
run;

/* Estimate AHA categorical attributes based on bed decile - use proc rank to compute deciles */
proc freq data = matrloc.POID_Imputed;
tables Adj_Beds;
run;

proc rank data = matrloc.POID_Imputed groups = 10 descending out = ranked;
var Adj_Beds;
ranks bed_decile;
run;

proc summary data = ranked nway nmiss;
  class bed_decile;
  var Adj_Beds;
  output out = matrloc.Bed_Decile_Report ( drop = _TYPE_ rename = ( _FREQ_ = POID_Count ) )
    min = Adj_Beds_Min
    max = Adj_Beds_Max
	sum = Adj_Beds_Total;
  run;

/* Identify POIDs with full AHA data and those with missing fields */
data matrloc.POID_Imputed;
set ranked;
bed_decile = bed_decile + 1; /* Offset so 10-1 instead of 9-0 */
if SERV='' or RESP='' or CHC='' or COMMTY='' or LOS='' or MAPP1=''
or MAPP2='' or MAPP3='' or MAPP5='' or MAPP7='' or MAPP8='' or MAPP11=''
or MAPP12='' or MAPP13='' or MAPP16='' or MAPP18='' or MAPP19='' or MAPP20=''
then AHA_cat_miss = 1;
else AHA_cat_miss = 0;
if HOSPBD=. or BDTOT=. or BIRTHS=. or SUROPIP=. or SUROPOP=. or SUROPTOT=.
or ADMTOT=. or IPDTOT=. or MCRDC=. or MCRIPD=. or MCDDC=. or MCDIPD=.
or VEM=. or VOTH=. or VTOT=. or FTMDTF=. or FTRES=. or FTRNTF=. or ADC=.
or ADJADM=. or ADJPD=. 
then AHA_num_miss = 1;
else AHA_num_miss = 0;
run;

/* Estimate AHA categorical attributes based on bed decile */
data matrloc.POID_With_AHA;
set matrloc.POID_Imputed;
if AHA_cat_miss = 0 and AHA_num_miss = 0;
run;
proc sort data=matrloc.POID_With_AHA;
by bed_decile;
run;

ods output OneWayFreqs = matrloc.OneWayFreqs;
proc freq data=matrloc.POID_With_AHA;
tables SERV RESP CHC COMMTY LOS MAPP1 MAPP2 MAPP3 
MAPP5 MAPP7 MAPP8 MAPP11 MAPP12 MAPP13 MAPP16 
MAPP18 MAPP19 MAPP20;
by bed_decile;
run;
ods output close;

data matrloc.Temp;
set matrloc.OneWayFreqs(rename=(Table=DecVar));
DecVar = substr(DecVar,7);			
DecMode = cat(SERV,RESP,CHC,COMMTY,LOS,MAPP1,MAPP2,MAPP3,MAPP5,
MAPP7,MAPP8,MAPP11,MAPP12,MAPP13,MAPP16,MAPP18,MAPP19,MAPP20);
DecMode = compress(DecMode,' ');			
DecMode = compress(DecMode,'.');	/* Added 1/11/2017 */		
keep bed_decile DecVar DecMode Percent;
run;
proc sort data=matrloc.Temp;
by DecVar bed_decile descending Percent;
run;
proc sort data=matrloc.Temp nodupkey out=matrloc.Decile_Metrics_Cat;
by DecVar bed_decile;
run;
data matrloc.Decile_Metrics_Cat;
set matrloc.Decile_Metrics_Cat;
drop Percent;
run;
proc sort data=matrloc.Decile_Metrics_Cat out=matrloc.Temp;
by bed_decile;
run;
proc transpose data=matrloc.Temp out=matrloc.Decile_Metrics_Cat suffix=_Mode;
var DecMode;
id DecVar;
by bed_decile;
run;
data matrloc.Decile_Metrics_Cat;
set matrloc.Decile_Metrics_Cat;
drop _NAME_;
run;

/* Mark Note: Need to change this step so births are not imputed based on bed decile */

/* Estimate AHA numerical attributes based on bed decile */
ods output Summary = matrloc.Means_Summary;
proc means data=matrloc.POID_With_AHA n mean;
var HOSPBD BDTOT BIRTHS SUROPIP SUROPOP SUROPTOT ADMTOT IPDTOT MCRDC MCRIPD 
MCDDC MCDIPD VEM VOTH VTOT FTMDTF FTRES FTRNTF ADC ADJADM 
ADJPD Adj_Beds /*Adj_Births*/ Adj_SurOpIP Adj_SurOpOP Adj_AdmTot Adj_VEM Adj_ADC;
by bed_decile;
run;
ods output close;

proc sql;
create table matrloc.Decile_Metrics_Num
as select bed_decile,
INT(HOSPBD_Mean)   as HOSPBD_Mean,
INT(BDTOT_Mean)    as BDTOT_Mean,
INT(BIRTHS_Mean)   as BIRTHS_Mean,
INT(SUROPIP_Mean)  as SUROPIP_Mean,
INT(SUROPOP_Mean)  as SUROPOP_Mean,
INT(SUROPTOT_Mean) as SUROPTOT_Mean,
INT(ADMTOT_Mean)   as ADMTOT_Mean,
INT(IPDTOT_Mean)   as IPDTOT_Mean,
INT(MCRDC_Mean)    as MCRDC_Mean,
INT(MCRIPD_Mean)   as MCRIPD_Mean,
INT(MCDDC_Mean)    as MCDDC_Mean,
INT(MCDIPD_Mean)   as MCDIPD_Mean,
INT(VEM_Mean)      as VEM_Mean,
INT(VOTH_Mean)     as VOTH_Mean,
INT(VTOT_Mean)     as VTOT_Mean,
INT(FTMDTF_Mean)   as FTMDTF_Mean,
INT(FTRES_Mean)    as FTRES_Mean,
INT(FTRNTF_Mean)   as FTRNTF_Mean,
INT(ADC_Mean)      as ADC_Mean,
INT(ADJADM_Mean)   as ADJADM_Mean,
INT(ADJPD_Mean)    as ADJPD_Mean,
/*INT(Adj_Births_Mean)    as Adj_Births_Mean,*/
INT(Adj_SurOpIP_Mean)   as Adj_SurOpIP_Mean,
INT(Adj_SurOpOP_Mean)   as Adj_SurOpOP_Mean,
INT(Adj_AdmTot_Mean)    as Adj_AdmTot_Mean,
INT(Adj_VEM_Mean)       as Adj_VEM_Mean,
INT(Adj_ADC_Mean)       as Adj_ADC_Mean
from matrloc.Means_Summary;
quit;   
   
/* Assign decile modes to POIDs missing categorical AHA data */
data matrloc.POID_WOut_AHA;
set matrloc.POID_Imputed;
if AHA_cat_miss = 1 or AHA_num_miss = 1;
run;   
proc sort data=matrloc.POID_WOut_AHA out=matrloc.Temp;
by bed_decile;
run;
proc sort data=matrloc.Decile_Metrics_Cat;
by bed_decile;
run;
data matrloc.POID_WOut_AHA;
merge matrloc.Temp(in=matrix) matrloc.Decile_Metrics_Cat;
by bed_decile;
if matrix = 1;
if SERV     = '' then SERV     = SERV_Mode;
if RESP     = '' then RESP     = RESP_Mode;
if CHC      = '' then CHC      = CHC_Mode;
if COMMTY   = '' then COMMTY   = COMMTY_Mode;
if LOS      = '' then LOS      = LOS_Mode;
if MAPP1    = '' then MAPP1    = MAPP1_Mode;
if MAPP2    = '' then MAPP2    = MAPP2_Mode;
if MAPP3    = '' then MAPP3    = MAPP3_Mode;
if MAPP5    = '' then MAPP5    = MAPP5_Mode;
if MAPP7    = '' then MAPP7    = MAPP7_Mode;
if MAPP8    = '' then MAPP8    = MAPP8_Mode;
if MAPP11   = '' then MAPP11   = MAPP11_Mode;
if MAPP12   = '' then MAPP12   = MAPP12_Mode;
if MAPP13   = '' then MAPP13   = MAPP13_Mode;
if MAPP16   = '' then MAPP16   = MAPP16_Mode;
if MAPP18   = '' then MAPP18   = MAPP18_Mode;
if MAPP19   = '' then MAPP19   = MAPP19_Mode;
if MAPP20   = '' then MAPP20   = MAPP20_Mode; 

drop SERV_Mode RESP_Mode CHC_Mode COMMTY_Mode LOS_Mode MAPP1_Mode MAPP2_Mode MAPP3_Mode 
MAPP5_Mode MAPP7_Mode MAPP8_Mode MAPP11_Mode MAPP12_Mode MAPP13_Mode MAPP16_Mode 
MAPP18_Mode MAPP19_Mode MAPP20_Mode;
run;

/* Assign decile means to POIDs missing numerical AHA data */
proc sort data=matrloc.POID_WOut_AHA out=matrloc.Temp;
by bed_decile;
run;
proc sort data=matrloc.Decile_Metrics_Num;
by bed_decile;
run;
data matrloc.POID_WOut_AHA;
merge matrloc.Temp(in=matrix) matrloc.Decile_Metrics_Num;
by bed_decile;
if matrix = 1;
if HOSPBD   = . then HOSPBD   = HOSPBD_Mean;
if BDTOT    = . then BDTOT    = BDTOT_Mean; 
if BIRTHS   = . then BIRTHS   = BIRTHS_Mean; 
if SUROPIP  = . then SUROPIP  = SUROPIP_Mean; 
if SUROPOP  = . then SUROPOP  = SUROPOP_Mean; 
if SUROPTOT = . then SUROPTOT = SUROPIP + SUROPOP;
if ADMTOT   = . then ADMTOT   = ADMTOT_Mean;
if IPDTOT   = . then IPDTOT   = IPDTOT_Mean; 
if MCRDC    = . then MCRDC    = MCRDC_Mean;
if MCRIPD   = . then MCRIPD   = MCRIPD_Mean;
if MCDDC    = . then MCDDC    = MCDDC_Mean;
if MCDIPD   = . then MCDIPD   = MCDIPD_Mean;
if VEM      = . then VEM      = VEM_Mean;
if VOTH     = . then VOTH     = VOTH_Mean;
if VTOT     = . then VTOT     = VEM + VOTH;
if FTMDTF   = . then FTMDTF   = FTMDTF_Mean;
if FTRES    = . then FTRES    = FTRES_Mean;
if FTRNTF   = . then FTRNTF   = FTRNTF_Mean;
if ADC      = . then ADC      = ADC_Mean;
if ADJADM   = . then ADJADM   = ADJADM_Mean;
if ADJPD    = . then ADJPD    = ADJPD_Mean;

/*if Adj_Births   = . then Adj_Births   = Adj_Births_Mean;*/
if Adj_SurOpIP  = . then Adj_SurOpIP  = Adj_SurOpIP_Mean;
if Adj_SurOpOP  = . then Adj_SurOpOP  = Adj_SurOpOP_Mean;
if Adj_AdmTot   = . then Adj_AdmTot   = Adj_AdmTot_Mean;
if Adj_VEM      = . then Adj_VEM      = Adj_VEM_Mean;
if Adj_ADC      = . then Adj_ADC      = Adj_ADC_Mean;

drop HOSPBD_Mean BDTOT_Mean BIRTHS_Mean SUROPIP_Mean SUROPOP_Mean SUROPTOT_Mean ADMTOT_Mean IPDTOT_Mean MCRDC_Mean MCRIPD_Mean 
MCDDC_Mean MCDIPD_Mean VEM_Mean VOTH_Mean VTOT_Mean FTMDTF_Mean FTRES_Mean FTRNTF_Mean ADC_Mean ADJADM_Mean 
ADJPD_Mean /*Adj_Births_Mean*/ Adj_SurOpIP_Mean Adj_SurOpOP_Mean Adj_AdmTot_Mean Adj_VEM_Mean Adj_ADC_Mean;
run;

/* Combine nonmissing and imputed POID lists into one */
data matrloc.POID_Imputed;
set matrloc.POID_With_AHA 
matrloc.POID_WOut_AHA;
run;

data matrloc.POID_Log;
set matrloc.POID_Imputed;

log_HOSPBD		= log10(HOSPBD+1);
log_BDTOT		= log10(BDTOT+1);
log_BIRTHS		= log10(BIRTHS+1);
log_SUROPIP		= log10(SUROPIP+1);
log_SUROPOP		= log10(SUROPOP+1);
log_SUROPTOT	= log10(SUROPTOT+1);
log_ADMTOT		= log10(ADMTOT+1);
log_IPDTOT		= log10(IPDTOT+1);
log_MCRDC		= log10(MCRDC+1);
log_MCRIPD		= log10(MCRIPD+1);
log_MCDDC		= log10(MCDDC+1);
log_MCDIPD		= log10(MCDIPD+1);
log_VEM			= log10(VEM+1);
log_VOTH		= log10(VOTH+1);
log_VTOT		= log10(VTOT+1);
log_FTMDTF		= log10(FTMDTF+1);
log_FTRES		= log10(FTRES+1);
log_FTRNTF		= log10(FTRNTF+1);
log_ADC			= log10(ADC+1);
log_ADJADM		= log10(ADJADM+1);
log_ADJPD		= log10(ADJPD+1);

/*log_EmpTotal	= log10(EmpTotal+1);*/
/*log_AdmOP		= log10(AdmOP+1);*/

log_Adj_Beds	= log10(Adj_Beds+1);
log_Adj_Births	= log10(Adj_Births+1);
log_Adj_SurOpIP	= log10(Adj_SurOpIP+1);
log_Adj_SurOpOP	= log10(Adj_SurOpOP+1);
log_Adj_AdmTot	= log10(Adj_AdmTot+1);
log_Adj_VEM		= log10(Adj_VEM+1);
log_Adj_ADC		= log10(Adj_ADC+1);

run;

/* Create more variables to be used in GLMSELECT statement */
data matrloc.POID_NewVars;
set matrloc.POID_Log;
if Adj_AdmTot > 0 then ALOS = IPDTOT / Adj_AdmTot;
if Adj_Beds   > 0 then AOR = IPDTOT / (365 * Adj_Beds);
if Adj_Beds   > 0 then suropperbed = (Adj_SurOpIP+Adj_SurOpOP) / Adj_Beds;
if Adj_Beds   > 0 then admperbed = Adj_AdmTot / Adj_Beds;
if Adj_Beds   > 0 then vemperbed = Adj_VEM / Adj_Beds;
if Adj_AdmTot > 0 then suropperadm = (Adj_SurOpIP+Adj_SurOpOP) / Adj_AdmTot;
if ftrntf     > 0 then suropperrn = (Adj_SurOpIP+Adj_SurOpOP) / ftrntf;
if ftrntf     > 0 then bedperrn = Adj_Beds / ftrntf;
if ftrntf     > 0 then vemperrn = Adj_VEM / ftrntf;
run;
proc sort data=matrloc.POID_NewVars;
by HMS_POID;
run;

/* remove POID if it is not found in WK/State/CMS data i.e. no prediction potential */
/* remove POID if it is found in WK tables but does not exist in AHA, State and CMS */
/* remove selected POIDs from list: army hospitals, closed facilities, Christian science nursing centers (HospitalExclusionList.tab in FXFILES)*/ 
/* MODIFICATION 4/30/2019 - Removed list of hard-coded POIDS and added reference to exclusion list in FXFILES */ 
data exclusion_list ( drop = Reason);
   infile "&FXFILES./HospitalExclusionList.tab" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
   informat HMS_POID	$10. ;
   informat Reason 	$40. ;
   format HMS_POID	$10. ;
   format Reason 	$40. ;
   input HMS_POID $ Reason $ ;
run;

proc sort data = matrloc.POID_NewVars; by HMS_POID; run;
proc sort data = exclusion_list; by HMS_POID; run;

data matrloc.POID_NewVars;
  merge matrloc.POID_NewVars ( in = a ) exclusion_list ( in = b );
  by HMS_POID;

  if a then do;
    if b or ( WK_listed = 0 and State_Listed = 0 and CMS_Listed = 0 ) or
            ( WK_listed = 1 and AHA_Listed = 0 and State_Listed = 0 and CMS_Listed = 0 ) then POID_removed = 1; else POID_removed = 0;
	output;
	end;
  run;

data matrloc.POID_Removed;
set matrloc.POID_NewVars;
if POID_removed = 1;
run;
data matrloc.POID_NewVars;
set matrloc.POID_NewVars;
if POID_removed = 0;
run;

/* organize selected rows from POID attributes table */
data matrloc.POID_Attributes_IP;
retain HMS_POID 
U65pct MaPenet TactInsField Unemp
RESP CHC COMMTY LOS 
MAPP1 MAPP2 MAPP3 MAPP5 MAPP7 MAPP8
MAPP11 MAPP12 MAPP13 MAPP16 MAPP18 MAPP19 MAPP20
Adj_Beds Adj_Births Adj_SurOpIP Adj_SurOpOP Adj_AdmTot 
IPDTOT MCRDC MCRIPD MCDDC MCDIPD 
Adj_VEM VOTH FTMDTF FTRES FTRNTF Adj_ADC ADJADM ADJPD 
Matrix_Listed AHA_Listed WK_Listed State_Listed CMS_Listed MDSI_Listed Zip State
Valid_State POID_Class AHA_cat_miss AHA_num_miss
log_Adj_Beds log_Adj_Births log_Adj_SurOpIP log_Adj_SurOpOP
log_Adj_AdmTot log_IPDTOT log_MCRDC log_MCRIPD log_MCDDC log_MCDIPD 
log_Adj_VEM log_VOTH log_FTMDTF log_FTRES log_FTRNTF log_Adj_ADC log_ADJADM log_ADJPD
;
set matrloc.POID_NewVars;
keep HMS_POID 
U65pct MaPenet TactInsField Unemp
RESP CHC COMMTY LOS MAPP1 MAPP2 MAPP3 MAPP5 
MAPP7 MAPP8 MAPP11 MAPP12 MAPP13 MAPP16 MAPP18 
MAPP19 MAPP20
Adj_Beds Adj_Births Adj_SurOpIP Adj_SurOpOP Adj_AdmTot
IPDTOT MCRDC MCRIPD MCDDC MCDIPD 
Adj_VEM VOTH FTMDTF FTRES FTRNTF Adj_ADC ADJADM ADJPD 
Matrix_Listed AHA_Listed WK_Listed State_Listed CMS_Listed MDSI_Listed Zip State
Valid_State POID_Class AHA_cat_miss AHA_num_miss 
log_Adj_Beds log_Adj_Births log_Adj_SurOpIP log_Adj_SurOpOP
log_Adj_AdmTot log_IPDTOT log_MCRDC log_MCRIPD log_MCDDC log_MCDIPD 
log_Adj_VEM log_VOTH log_FTMDTF log_FTRES log_FTRNTF log_Adj_ADC log_ADJADM log_ADJPD
; 
run; 






/* OP Matrix Steps */
proc sort data=projdir.op_Datamatrix out=matrloc.POID_Volume_OP;
by HMS_POID;
run;

/* copy POID_Volume table into local folder to be used for all buckets */
data matrloc.POID_Volume_OP_&used_vintage.;
set matrloc.POID_Volume_OP;
run;

/* Add WK totals to POID table */
data matrloc.POID_Volume_OP;
merge matrloc.POID_Volume_OP_&used_vintage.(in=matrix) /* MODIFICATION 6/22/2016: change to project directory */
projdir.WK_POIDList(in=WK);
by HMS_POID;
if matrix=1;
if WK=1 then WK_Listed=1;
else WK_Listed=0;
run;
/* Add State totals to POID table */
data matrloc.Temp;
merge matrloc.POID_Volume_OP(in=matrix) 
projdir.State_POIDList(in=Statee);
by HMS_POID;
if matrix=1;
if Statee=1 then State_Listed=1;
else State_Listed=0;
run;
/* Add CMS totals to POID table */
data matrloc.POID_Volume_OP;
merge matrloc.Temp(in=Main) projdir.CMS_POIDList(in=CMS);
by HMS_POID;
if Main=1;
if CMS=1 then CMS_Listed=1;
else CMS_Listed=0;
run;
data matrloc.POID_Volume_OP;
set matrloc.POID_Volume_OP;
if MDSI_Listed   =.  then MDSI_Listed   = 0;
if Matrix_Listed =.  then Matrix_Listed = 0;
*if AHA_Listed    =.  then AHA_Listed    = 0;
if Class_Listed  =.  then Class_Listed  = 0;
if WK_Listed     =.  then WK_Listed     = 0;
if State_Listed  =.  then State_Listed  = 0;
if CMS_Listed    =.  then CMS_Listed    = 0;
run;   

/* Remove POIDs that are missing in WK/State/CMS */
data matrloc.POID_Limited_OP;
set matrloc.POID_Volume_OP;
if WK_Listed=1 or State_Listed=1 or CMS_Listed=1;   
run;

/* Use the already generated and sorted poid/zip/state dataset */
proc sort data=matrloc.POID_Limited_OP out=matrloc.Temp;
by HMS_POID;
run;
data matrloc.POID_Limited_OP;
merge matrloc.Temp(in=Target) fxfiles.POID_Zip_Lookup_&used_vintage.;
by HMS_POID;
if Target=1;
if source_state ~= '' then State = source_state;
else State = zip_state;
drop source_state zip_state;
run;

/* Use state of claim source if state is not found */
data matrloc.POID_Limited_OP;
set matrloc.POID_Limited_OP;
if state in ('AK','AL','AR','AZ','CA','CO','CT','DC',
'DE','FL','GA','HI','IA','ID','IL','IN','KS','KY','LA',
'MA','MD','ME','MI','MN','MO','MS','MT','NC','ND','NE',
'NH','NJ','NM','NV','NY','OH','OK','OR','PA','RI','SC',
'SD','TN','TX','UT','VA','VT','WA','WI','WV','WY')
then valid_state = 1;
else if state = '' then valid_state = .; 
else valid_state = 0;
run;

/* Impute Tactician variables based on zip */
data matrloc.POID_Imputed_Tact_OP;
set matrloc.POID_Limited_OP;
if U65Pct ~= . and MAPenet ~= . and TactInsField ~= .
and Unemp ~= . then Tact_miss = 0;
else Tact_miss = 1;
run;
data matrloc.POID_With_Tact_OP;
set matrloc.POID_Imputed_Tact_OP;
if Tact_miss = 0;
run;
data matrloc.POID_WOut_Tact_OP;
set matrloc.POID_Imputed_Tact_OP;
if Tact_miss = 1;
run;
data matrloc.Temp;
set matrloc.POID_WOut_Tact_OP;
if zip ~= '';
keep HMS_POID ZIP;
run;
proc sort data=matrloc.Temp nodupkey;
by ZIP;
run;
proc sql;
create table matrloc.Temp2 as
select a.zip, a.U65Pct as U65Pct_zip, a.MAPenet as MAPenet_zip,
a.TactInsField as TactInsField_zip, a.Unemp as Unemp_zip
from matrloc.POID_With_Tact_OP a, matrloc.Temp b
where a.ZIP=b.ZIP; 
quit;
proc sort data=matrloc.Temp2 nodupkey;
by ZIP;
run;
proc sort data=matrloc.POID_WOut_Tact_OP out=matrloc.Temp;
by ZIP;
run;
data matrloc.POID_WOut_Tact_OP;
merge matrloc.Temp matrloc.Temp2;
by ZIP;
if U65Pct       = . then U65Pct       = U65Pct_zip;
if MAPenet      = . then MAPenet      = MAPenet_zip;
if TactInsField = . then TactInsField = TactInsField_zip;
if Unemp        = . then Unemp        = Unemp_zip;
drop U65Pct_zip MAPenet_zip TactInsField_zip Unemp_zip;
run;

/* Combine nonmissing and imputed Tactician lists into one */
data matrloc.POID_Imputed_Tact_OP;
set matrloc.POID_With_Tact_OP matrloc.POID_WOut_Tact_OP;
run;

/* Impute Tactician variables based on state */
data matrloc.POID_With_Tact_OP;
set matrloc.POID_Imputed_Tact_OP;
if U65Pct ~= . and MAPenet ~= . and TactInsField ~= . and Unemp ~= . ;
run;
data matrloc.POID_WOut_Tact_OP;
set matrloc.POID_Imputed_Tact_OP;
if U65Pct = . or MAPenet = . or TactInsField = . or Unemp = . ;
run;
data matrloc.Temp;
set matrloc.POID_WOut_Tact_OP;
if STATE ~= '';
keep HMS_POID STATE;
run;
proc sql;
create table matrloc.Temp2 as
select a.state, avg(a.U65Pct) as U65Pct_state, avg(a.MAPenet) as MAPenet_state,
avg(a.TactInsField) as TactInsField_state, avg(a.Unemp) as Unemp_state
from matrloc.POID_With_Tact_OP a,
matrloc.Temp b
where a.STATE=b.STATE
group by a.STATE; 
quit;
proc sort data=matrloc.Temp2;
by STATE;
run;
proc sort data=matrloc.POID_WOut_Tact_OP out=matrloc.Temp;
by STATE;
run;
data matrloc.POID_WOut_Tact_OP;
merge matrloc.Temp matrloc.Temp2;
by state;
if U65Pct       = . then U65Pct       = round(U65Pct_state,0.1);
if MAPenet      = . then MAPenet      = round(MAPenet_state,0.01);
if TactInsField = . then TactInsField = round(TactInsField_state,0.01);
if Unemp        = . then Unemp        = round(Unemp_state,0.1);
drop U65Pct_state MAPenet_state TactInsField_state Unemp_state;
run;

/* Combine nonmissing and imputed Tactician lists into one */
data matrloc.POID_Imputed_OP;
set matrloc.POID_With_Tact_OP matrloc.POID_WOut_Tact_OP;
run;

/* remove POID if it is not found in WK/State/CMS data i.e. no prediction potential */
/* remove POID if it is found in WK tables but does not exist in AHA, State and CMS */
/* remove selected POIDs from list: army hospitals, closed facilities, Christian science nursing centers (HospitalExclusionList.tab in FXFILES)*/ 
/* MODIFICATION 4/30/2019 - Removed list of hard-coded POIDS and added reference to exclusion list in FXFILES */ 
data exclusion_list ( drop = Reason);
   infile "&FXFILES./HospitalExclusionList.tab" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2;
   informat HMS_POID	$10. ;
   informat Reason 	$40. ;
   format HMS_POID	$10. ;
   format Reason 	$40. ;
   input HMS_POID $ Reason $ ;
run;

proc sort data = matrloc.POID_Imputed_OP; by HMS_POID; run;
proc sort data = exclusion_list; by HMS_POID; run;

data matrloc.POID_NewVars_OP;
  merge matrloc.POID_Imputed_OP ( in = a ) exclusion_list ( in = b );
  by HMS_POID;

  if a then do;
    if b or ( WK_listed = 0 and State_Listed = 0 and CMS_Listed = 0 ) or
            ( WK_listed = 1 and State_Listed = 0 and CMS_Listed = 0 ) then POID_removed = 1; else POID_removed = 0;
	output;
	end;
  run;
  
/* MODIFICATION 04.26.2017 - Removed more POIDs, though they will be suppressed in future aggregations */

data matrloc.POID_Removed_OP;
set matrloc.POID_NewVars_OP;
if POID_removed = 1;
run;
data matrloc.POID_NewVars_OP;
set matrloc.POID_NewVars_OP;
if POID_removed = 0;
run;

/* organize selected rows from POID attributes table */
data matrloc.POID_Attributes_OP;
retain HMS_POID U65pct MaPenet TactInsField Unemp;
set matrloc.POID_NewVars_OP;
keep HMS_POID U65pct MaPenet TactInsField Unemp; 
run; 


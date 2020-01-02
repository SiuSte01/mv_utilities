options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      ipmatrix.sas
PURPOSE:           the latest possible state data, wk, and cms IP
				   by getting the POID universe 
PROGRAMMER:		
CREATION DATE:	   
UPDATED:		   Molli Jones, 1/16/2018
NOTES:			   drop NH and TN state data
INPUT FILES:	   input.txt, aha_demo data, tactician data	   
output files:      ip_matrix
				   ip_matrix_Child and ip_matrix_nonChild if SPLITIPMATRIX = 'Y'
****************************************************************************************** */

/* Read in input file and use to set environment variables
   SPLITIPMATRIX defaults to 'N' */
   
data inputs;
  infile "input.txt" delimiter = '09'x MISSOVER DSD lrecl = 32767 firstobs = 2;
  format Parameter     $50. ;
  format Value         $200. ;
  informat Parameter   $50. ;
  informat Value       $200. ;
  input Parameter $ Value $ ;
  run;

%let SPLITIPMATRIX = N;

data _null_;
  set inputs;

  if Parameter eq 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
  if Parameter EQ 'FXFILES'  then call symput('fxfiles', trim(left(compress(value))));
  if Parameter eq 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
  if Parameter eq 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
  if Parameter eq 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
  if Parameter eq 'AGGREGATION_ID' then call symput('AGGREGATION_ID', trim(left(compress(value))));
  if Parameter eq 'SPLITIPMATRIX' then call symput('SPLITIPMATRIX', trim(left(compress(value))));
  run;

%put SPLITIPMATRIX: &SPLITIPMATRIX;

/* Set up libnames */
libname fxfiles %unquote(%str(%'&FXFILES%'));
libname claim '.';
libname profile oracle user = claims_usr password = claims_usr123 path = PLDWH2DBR SCHEMA = profileData;

/* Select POIDs with valid claims */
proc sql;
  connect to oracle( user = &USERNAME password = &PASSWORD path = &INSTANCE);
  
  create table ip_poids as select * from connection to oracle
    ( select distinct h.id_value as HMS_POID 
        from claimswh.inst_claims a
           inner join claimswh.facility_id_crosswalk h on a.facility_id=h.facility_id
           inner join claimswh.bill_classifications b on a.bill_classification_id = b.bill_classification_id
           inner join claims_aggr.job_vendors v on a.vendor_id=v.vendor_id
         where v.job_id = &AGGREGATION_ID 
		   and ( a.claim_through_date between v.first_vend_date and v.last_vend_date )
           and a.load_batch <= v.last_vend_batch   
           and h.id_type='POID'
           and ( to_date(%unquote(%str(%'&Vintage%')), 'YYYYMMDD' ) between h.start_date and h.end_date )
           and ( ( v.vendor_code in ('CMSIP','AZIP','TXIP','NVIP','NYIP','FLIP','WAIP','NJIP','CAIP') ) 
                       or ( v.vendor_code='WK' and b.classification_code='011' ) ) );
  disconnect from oracle;
  quit;
%put &sqlxmsg ;

proc sort data = ip_poids( where = ( hms_poid ^= ' ' ) ) out = ip_poids nodupkey; by hms_poid; run;

/*****incorportate insurance, state penetration, and age distribution****/
proc sql;
  create table ip_poids_zip as
    select a.hms_poid, b.state, b.zip
    from ip_poids a 
	  left join profile.Organization_Addresses_View b 
		on a.hms_poid = b.hms_poid and Vintage_Num = &vintage.;
  quit;

data ip_poids;
  set ip_poids_zip;
  zip1 = input(zip, 5.0);
  run;

proc sql;
  create table hosp_data as
    select a.hms_poid, a.state, a.zip, b.U65Pct, c.ins as insurance, c.MaPenet, c.Unemp
    from ip_poids a
      left join fxfiles.test_u65byhsa b on a.zip1 = b.zipcode
      left join fxfiles.ins_mapenet c on a.zip1 = c.zip1
    order by a.hms_poid;
  quit;

data hosp_data1;
  set hosp_data;
  TactInsField = round( insurance, 0.01 );
  drop insurance;
  run;

proc sql;
  create table hosp_info as select a.*, b.*
    from hosp_data1 a
      left join profile.Poid_Identifiers_View x 
	    on a.hms_poid = x.hms_poid and x.vintage_num = &vintage. and x.ID_TYPE = 'AHA'
      left join fxfiles.aha_demo b on x.value = b.id
    where a.state is not null;
  quit;

proc sort data = hosp_info; by hms_poid descending hospbd; run;

data hosp_info1;
  set hosp_info;
  by hms_poid;
  if first.hms_poid = 1 then output;
  run;

proc means data = hosp_info1 noprint nway median;
  var U65pct mapenet TactInsField unemp;
  output out = med median=;
  run;

data _null_;
  set med;
  call symput('mapenet', mapenet);
  call symput('U65pct', U65pct);
  call symput('TactInsField', TactInsField);
  call symput('unemp', unemp);
  run;

%put 'TactInsField:' &TactInsField;
%put 'mapenet:' &mapenet;
%put 'U65pct:' &U65pct;
%put 'unemp': &unemp;

data datamatrix; /* Impute as median value if missing */
  set hosp_info1;
  if mapenet = . then mapenet = &mapenet;
  if U65pct = . then U65pct = &U65pct;
  if TactInsField = . then TactInsField = &TactInsField;
  if unemp = . then unemp = &unemp;
  run;

/****** find additional aha_id through pos-aha_id crosswalk ***/
proc sort data = datamatrix ( where = ( id = ' ' ) ) out = poid ( drop = id ) nodupkey; by hms_poid; run;


proc sql; /**** there are additional 240 poid crosswalk to ahaid [OLD COMMENT] ***/
  create table addtn_hosp_info as
    select a.hms_poid, b.*
    from poid a, 
	     ( select * from profile.Poid_Identifiers_View 
		     where Vintage_Num = &vintage. and ID_TYPE = 'POS' ) x,
		 fxfiles.aha_demo b
    where a.hms_poid = x.hms_poid and x.value = b.mcrnum;
  quit;

proc sort data = addtn_hosp_info; by hms_poid descending hospbd; run;

data addtn_hosp_info;
  set addtn_hosp_info;
  by hms_poid;
  if first.hms_poid = 1 then output;
  run;

proc sort data = datamatrix ( where = ( id = ' ' ) keep = hms_poid state zip u65pct mapenet unemp tactinsfield id ) out = mymatrix;
  by hms_poid;
  run;

data mymatrix1;
  merge mymatrix ( in = a drop = id ) addtn_hosp_info ( in = b );
  by hms_poid;
  if a then output;
  run;
 
data ip_datamatrix;
  set datamatrix ( where = ( id ^= ' ' ) ) mymatrix1;
  drop ID state zip;
  run;

/* Get POID Profile Information and Create Final Matrix */
proc sql ;
  connect to oracle ( user = claims_usr password = claims_usr123 path = PLDWH2DBR ) ;

  create table POID_PROFILE ( compress = yes ) as select * from connection to oracle
    ( select a.HMS_POID, b.ORG_NAME, b.ADDRESS1 as ADDRESS_LINE1
       from profileData.organizations_view a 
	   left join profileData.organization_addresses_view b
	     on a.hms_poid = b.hms_poid and a.vintage = b.vintage
	   where a.VINTAGE_NUM = &Vintage. and b.org_name is not null and b.address1 is not null);

  disconnect from oracle ;
  quit ;

proc sort data = ip_datamatrix; by HMS_POID; run;
proc sort data = POID_PROFILE; by HMS_POID; run;

data claim.ip_datamatrix;
  merge ip_datamatrix ( in = a ) POID_PROFILE;
  by HMS_POID;
  if a then output; 
  run;
  
proc sort data = claim.ip_datamatrix nodupkey; by hms_poid; run;

/* Split Matrix into Child and Non-Child if Environment variable is set 
     -- Differs from old version because only uses one ORG_NAME */
%macro splitmatrix();
  %if %upcase(&SPLITIPMATRIX) = Y %then %do;
    proc sql;
      create table children_hosp as
        select distinct hms_poid
        from profile.organization_addresses_view
        where org_name like '%CHILD%' and Vintage_num = &vintage.
        order by hms_poid;
      quit;

    data claim.ip_matrix_nonChild claim.ip_matrix_child;
      merge claim.ip_datamatrix ( in = a ) children_hosp ( in = b );
      by hms_poid;
	  if a and not b then output claim.ip_matrix_nonChild;
	  if a and b then output claim.ip_matrix_Child;
      run;

    proc sort data=claim.ip_matrix_nonChild nodupkey; by hms_poid; run;
    proc sort data=claim.ip_matrix_child nodupkey; by hms_poid; run;
    %end;
%mend splitmatrix;

%splitmatrix();

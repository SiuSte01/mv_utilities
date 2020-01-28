options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      ascmatrix.sas
PURPOSE:           Creates the POID asc_datamatrix_&Vintage.sas7bdat
PROGRAMMER:		   
CREATION DATE:	   
UPDATED:		   Molli Jones - 1/2018
NOTES:			   Called by createxwalks.py
INPUT FILES:	   input.txt, poidmigration_lookup_&Vintage.sas7bdat, CMS_ASC_ProcedureData.txt,
                   zip2fips.sas7bdat, covar_under65.sas7bdat, covar_County_Unemp.sas7bdat, 
				   covar_MA_penetration.sas7bdat, covar_HI_expend.sas7bdat
OUTPUT FILES:	   asc_datamatrix_&Vintage.sas7bdat 
****************************************************************************************** */

/* Read in inputs file */
data inputs ( compress = yes );
  infile 'input.txt' delimiter = '09'x MISSOVER DSD lrecl = 32767 firstobs = 2;
	
  informat Parameter $125.;
  informat Value $200.;
  format Parameter $125.;
  format Value $200.;
  input Parameter $ Value $;
  run;

/* Create macro variables based on inputs */
data _null_;
  set inputs;
  
  if Parameter = 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
  if Parameter = 'FXFILES' then call symput('FXFILES', trim(left(compress(value))));
  if Parameter = 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
  if Parameter = 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
  if Parameter = 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
  if Parameter eq 'AGGREGATION_ID' then call symput('AGGREGATION_ID', trim(left(compress(value))));
  run;

%put 'Vintage:' &Vintage;
%put 'FXFILES:' &FXFILES;
%put 'USERNAME:' &USERNAME;
%put 'PASSWORD:' &PASSWORD;
%put 'INSTANCE:' &INSTANCE;
%put 'AGGREGATION_ID:' &AGGREGATION_ID;

/* Pull ASC Claims from Oracle */
proc sql;
  connect to oracle( user = &USERNAME. password = &PASSWORD. path = &INSTANCE. );

  create table ASC_claims ( compress = yes ) as select * from connection to oracle
    ( select distinct d.Vendor_Code, b.Facility_ID, c.ID_TYPE, c.ID_VALUE
	    from claimswh.inst_claims b, claimswh.facility_id_crosswalk c, claims_aggr.job_vendors d, claimswh.bill_classifications e
	    where b.FACILITY_ID = c.FACILITY_ID
             and d.job_id = &AGGREGATION_ID
		     and b.Bill_Classification_ID = e.Bill_Classification_ID and e.CLASSIFICATION_CODE = '083'
		     and b.vendor_id = d.vendor_id and d.vendor_code in ('EMD','FLOP','NYOP')
		     and b.LOAD_BATCH <= d.LAST_VEND_BATCH
		     and ( b.CLAIM_THROUGH_DATE between d.FIRST_VEND_DATE and d.LAST_VEND_DATE )
		     and ( to_date( %unquote( %str( %'&Vintage%' ) ), 'YYYYMMDD' ) between c.START_DATE and c.END_DATE ) );
  disconnect from oracle;
  quit;

proc sql ;
  connect to oracle( user = &USERNAME. password = &PASSWORD. path = &INSTANCE. );

  create table CA_claims ( compress = yes ) as select * from connection to oracle
   ( select distinct d.Vendor_Code, b.Facility_ID, b.Bill_Classification_ID, c.ID_TYPE, c.ID_VALUE
	   from claimswh.inst_claims b, claimswh.facility_id_crosswalk c, claims_aggr.job_vendors d
	   where b.FACILITY_ID = c.FACILITY_ID
		    and b.vendor_id = d.vendor_id and d.vendor_code in ('CAOPA','CAIPA','CAOP','CAIP')
            and d.job_id = &AGGREGATION_ID
		    and b.LOAD_BATCH <= d.LAST_VEND_BATCH
		    and ( b.CLAIM_THROUGH_DATE between d.FIRST_VEND_DATE and d.LAST_VEND_DATE )
		    and ( to_date( %unquote( %str( %'&Vintage%' ) ),'YYYYMMDD' ) between c.START_DATE and c.END_DATE ) );
  disconnect from oracle;
  quit;

/* ASC Claims from Emdeon Switch with non-null NPI */
data ASC_claims_sw;
  set ASC_claims;
  if vendor_code = 'EMD' and ID_TYPE = 'NPI' then do;
    if ID_VALUE = 'NULL' then delete;
    output;
    end;
  run;

/* NY and FL OP claims with non-null POID */
data NYFL_claims;
  set ASC_claims;
  if vendor_code in ('FLOP','NYOP') and ID_TYPE = 'POID' then do;
    if ID_VALUE = 'NULL' then delete;
	output;
	end;
  run;

/* For CA - If OP and not IP then keep */
data CAOP_claims;
  set CA_claims;
  where Vendor_Code in ( 'CAOP', 'CAOPA' );

  if ID_VALUE = 'NULL' then delete;
  else if ID_TYPE ~= 'POID' then delete;
  run;
  
data CAIP_claims;
  set CA_claims;
  where Vendor_Code in ( 'CAIPA', 'CAIP' );

  if ID_VALUE = 'NULL' then delete;
  else if ID_TYPE ~= 'POID' then delete;
  run;
  
proc sort data = CAOP_claims; by ID_VALUE; run;
proc sort data = CAIP_claims; by ID_VALUE; run;

data CA_claims;
  merge CAOP_claims ( in = a ) CAIP_claims ( in = b );
  by ID_VALUE;

  if a and not b then do;
    CA_flag = 1;
    keep ID_VALUE CA_flag;
	output;
	end;
  run;
  
/* Set together State Data (CA, NY, FL) with non-null POID */
data States;
  length HMS_POID $10.;
  set CA_claims NYFL_claims;

  HMS_POID = ID_VALUE;
  if vendor_code = 'FLOP' then FL_flag = 1;
  if vendor_code = 'NYOP' then NY_flag = 1;
  keep HMS_POID CA_flag FL_flag NY_flag;
  run;

/* Get Migration Info for State Data */
libname Inputs %unquote(%str(%'&FXFILES%'));

data migrate_poids;
  set Inputs.poidmigration_lookup_&Vintage.;
  run;

proc sort data = States; by HMS_POID; run;
proc sort data = migrate_poids; by HMS_POID; run;

data States_migr;
  merge migrate_poids States(in=a);
  by HMS_POID;
  
  if a then do;
    if poid_migration_status = 'MOVED' then HMS_POID = new_poid;
    else if poid_migration_status ~= '' then delete;
    drop poid_migration_status new_POID;
	output;
	end;
  run;

proc sort data = States_migr nodupkey; by HMS_POID; run;

/* Get ASC from CMS and merge with ASC Claims from Emdeon Switch by NPI */
data CMS_ASC;
  infile %unquote(%str(%'&FXFILES/CMS_ASC_ProcedureData.txt%')) delimiter = '09'x MISSOVER DSD lrecl = 32767 firstobs = 2;
  
  informat HCPCS $5.;
  informat MODIFIER_1 $2.;
  informat MODIFIER_2 $2.;
  informat ALLOWED_CHARGES best32.;
  informat ALLOWED_SERVICES best32.;
  informat CARRIER best32.;
  informat SUPPLIER_ID_NUMBER $10.;
  informat SUPPLIER_COUNTY best32.;
  informat SUPPLIER_STATE best32.;
  informat SUPPLIER_STATE_ABBREV $2.;
  informat CBSA best32.;
  informat WAGE_INDEX best32.;
  informat DISCOUNTED_ALLOWED_SERVICES best32.;
  
  format HCPCS $5.;
  format MODIFIER_1 $2.;
  format MODIFIER_2 $2.;
  format ALLOWED_CHARGES best12.;
  format ALLOWED_SERVICES best12.;
  format CARRIER best12.;
  format SUPPLIER_ID_NUMBER $10.;
  format SUPPLIER_COUNTY best12.;
  format SUPPLIER_STATE best12.;
  format SUPPLIER_STATE_ABBREV $2.;
  format CBSA best12.;
  format WAGE_INDEX best12.;
  format DISCOUNTED_ALLOWED_SERVICES best12.;
  
  input HCPCS $ MODIFIER_1 $ MODIFIER_2 $ ALLOWED_CHARGES ALLOWED_SERVICES CARRIER SUPPLIER_ID_NUMBER $
	    SUPPLIER_COUNTY SUPPLIER_STATE SUPPLIER_STATE_ABBREV $ CBSA WAGE_INDEX DISCOUNTED_ALLOWED_SERVICES;
		
  ORG_NPI = SUPPLIER_ID_NUMBER;
  CMS_flag = 1;
  keep ORG_NPI ALLOWED_SERVICES CMS_flag;
  run;

data EMD_ASC;
  set ASC_claims_sw;
  
  ORG_NPI = ID_VALUE;
  EMD_flag = 1;
  keep ORG_NPI EMD_flag;
  run;
  
proc sort data = CMS_ASC nodupkey; by ORG_NPI; run;
proc sort data = EMD_ASC nodupkey; by ORG_NPI; run;

data EMD_CMS_ASC;
  merge EMD_ASC CMS_ASC;
  by ORG_NPI;
  run;

/* Crosswalk NPI to POID for CMS and Emdeon Switch Data */
proc sql;
  connect to oracle ( user = claims_usr password = claims_usr123 path = PLDWH2DBR ) ;

  create table NPI_POID ( compress = yes ) as select * from connection to oracle
	( select HMS_POID, VALUE as ORG_NPI, RANK 
	      from ProfileData.Poid_Identifiers_View
	      where VINTAGE_NUM = &Vintage. and ID_TYPE = 'NPI' );

  disconnect from oracle ;
  quit;

proc sort data = EMD_CMS_ASC; by ORG_NPI; run;
proc sort data = NPI_POID; by ORG_NPI; run;

data EMD_CMS_ASC_POID;
  merge NPI_POID EMD_CMS_ASC ( in = a );
  by ORG_NPI;

  if a then do;
    if HMS_POID = '' then delete;
    *drop ORG_NPI RANK;
	output;
	end;
  run;

/* Look for duplicate POIDs after mapping from NPI */
proc sort data = States_migr; by HMS_POID; run;
proc sort data = EMD_CMS_ASC_POID; by HMS_POID; run;
proc sort data = EMD_CMS_ASC_POID nodupkey out = temp dupout = dup_poids ( keep = HMS_POID ); by HMS_POID; run;
proc sort data = dup_poids nodupkey; by HMS_POID; run;

data determine; /* Look for POIDs that are duplicated in dataset after mapping NPI */
  merge dup_poids(in=a) EMD_CMS_ASC_POID;
  by HMS_POID;
  if a then output;
  run;

data determine2; /* Source of POID */
  set determine;
  if EMD_flag = 1 and CMS_flag = 1 then Type = 'Both';
  else if EMD_flag = 1 and CMS_flag = . then Type = 'EMD';
  else if EMD_flag = . and CMS_flag = 1 then Type = 'CMS';
  drop EMD_flag CMS_flag;
  run;

proc sort data = determine2 nodupkey; by HMS_POID Type; run; /* Sort by Type & NODUPKEY for Type --- So alphabetical BOTH - CMS - EMD */

proc transpose data = determine2 out = determine3; /* Transpose file so Source of POID are column variables */
  by HMS_POID;
  var Type;
  run;

data determine4; 
  set determine3;
  
  /* COL1 = 'Both' if any entry had both */
  if COL1 = 'Both' then do; EMD_flag = 1; CMS_flag = 1; end;
  
  /* COL1 = 'CMS' if no entry had both --- if COL2 has 'EMD' then one entry from each source */
  else if COL1 = 'CMS' then do; CMS_flag = 1;
    if COL2 = 'EMD' then EMD_flag = 1;
    end;
	
  /* If COL1 = 'EMD' then this is the only source */	
  else if COL1 = 'EMD' then EMD_flag = 1;
  keep HMS_POID EMD_flag CMS_flag;
  run;

data EMD_CMS_ASC_CORRECT; /* Merge the undupped EMD_CMS dataset with EMD_Flag and CMS_Flag --- creates across all mappings to the POID */
  merge temp determine4;
  by HMS_POID;
  run;

/* Merge together Emdeon Switch, CMS, and State Data */
data ASC_POID_Matrix;
  merge EMD_CMS_ASC_CORRECT States_migr;
  by HMS_POID;
  
  if EMD_flag = . then EMD_flag = 0;
  if CMS_flag = . then CMS_flag = 0;
  if CA_flag = . then CA_flag = 0;
  if FL_flag = . then FL_flag = 0;
  if NY_flag = . then NY_flag = 0;
  run;

  
/* Get POID Profile Information and Create Matrix */
proc sql ;
  connect to oracle ( user = claims_usr password = claims_usr123 path = PLDWH2DBR ) ;

  create table POID_PROFILE ( compress = yes ) as select * from connection to oracle
    ( select a.HMS_POID, b.ORG_NAME, a.ORGTYPE_DESC as ORG_TYPE,
		     b.ADDRESS1 as ADDRESS_LINE1, b.ADDRESS2 as ADDRESS_LINE2, 
			 b.CITY, b.STATE, b.ZIP, b.ZIP4
       from profileData.organizations_view a 
	   left join profileData.organization_addresses_view b
	     on a.hms_poid = b.hms_poid and a.vintage = b.vintage
	   where a.VINTAGE_NUM = &Vintage. and a.ORGTYPE_CODE like '1%' );
	   
  create table POID_ZIP (compress=yes) as select * from connection to oracle
    ( select HMS_POID, ADDRESS1 as ADDRESS_LINE1, ADDRESS2 as ADDRESS_LINE2, 
	         CITY, STATE, ZIP, ZIP4
		from profileData.organization_addresses_view b 
		where b.VINTAGE_NUM = &Vintage. );

  disconnect from oracle ;
  quit ;

proc sort data = ASC_POID_MATRIX; by HMS_POID; run;
proc sort data = POID_PROFILE; by HMS_POID; run;
proc sort data = POID_ZIP; by HMS_POID; run;

data All_poids ( compress = yes );
  merge ASC_POID_MATRIX ( in = a ) POID_PROFILE POID_ZIP;
  by HMS_POID;
  
  if a then do;
    if EMD_flag = . then EMD_flag = 0;
    if CMS_flag = . then CMS_flag = 0;
    if CA_flag = 1 or FL_flag = 1 or NY_flag = 1 then State_flag = 1; else State_flag = 0;
    Flag_Sum = EMD_flag + CMS_flag + State_flag;
    drop ALLOWED_SERVICES;
    output; 
    end;
  run;

data All_poids_final ( compress = yes );
  set All_poids;
  where EMD_flag = 1 or CMS_flag = 1 or State_flag = 1;
  run;

data POID_matrix;
  set All_poids_final;
  rename hms_poid = HMS_POID;
  label HMS_POID = ;
  keep HMS_POID EMD_flag CMS_flag State_flag ORG_NAME ORG_TYPE ADDRESS_LINE1 ADDRESS_LINE2 CITY STATE ZIP ZIP4;
  run;

/* Merge in covariates */
proc sort data = inputs.zip2fips nodupkey out = zips ( keep = ZIP FIPS ); by ZIP; run;
proc sort data = POID_matrix out = temp; by ZIP; run;
proc sort data = inputs.covar_under65; by ZIP; run;

data POID_matrix_FIPS ( compress = yes );
  merge temp(in=a) zips inputs.covar_under65;
  by ZIP;
  if a;
  run;

proc sort data = inputs.covar_County_Unemp; by FIPS; run;
proc sort data=inputs.covar_MA_penetration; by FIPS; run;
proc sort data=inputs.covar_HI_expend; by FIPS; run;

data POID_matrix_FIPS;
  set POID_matrix_FIPS ( rename = ( FIPS = fips1 ) );
  FIPS = fips1*1;
  run;
  
proc sort data=POID_matrix_FIPS; by FIPS; run;

data POID_matrix_wcov;
  merge POID_matrix_FIPS ( in = a )
        inputs.covar_County_Unemp ( keep = FIPS Rate )
        inputs.covar_MA_penetration ( keep = FIPS Penetration )
        inputs.covar_HI_expend ( keep = FIPS IHXCYHC1 );
  by FIPS;
  if a then do;
    rename Rate = UNEMPLOYMENT;
    rename Penetration = MA_PENETRATION;
    rename IHXCYHC1 = TACTINS_EXPEND;
	
    if PERCENT_POP_UNDER_65 < .0001 then PCT_UNDER65 = .;
    else PCT_UNDER65 = round( PERCENT_POP_UNDER_65, .01 );
	
    drop POP_UNDER_65 PERCENT_POP_UNDER_65 FIPS;
    output;
	end;
  run;

/* Check values of Covariates - Get Median Values for imputation */
proc means data = POID_matrix_wcov noprint n median;
  var PCT_UNDER65 MA_PENETRATION TACTINS_EXPEND UNEMPLOYMENT;
  output out = covs n = n median = ;
  run;
  
data _null_;
  set covs;
  if _TYPE_ = 0 then do;
    call symput('M_PCT_UNDER65',PCT_UNDER65);
    call symput('M_MA_PENETRATION',MA_PENETRATION);
    call symput('M_TACTINS_EXPEND',TACTINS_EXPEND);
    call symput('M_UNEMPLOYMENT',UNEMPLOYMENT);
    end;
  run;
  
%put &M_PCT_UNDER65;
%put &M_MA_PENETRATION;
%put &M_TACTINS_EXPEND;
%put &M_UNEMPLOYMENT;

/* If missing, set to median value */
data POID_matrix_wcov1;
  set POID_matrix_wcov;
  if PCT_UNDER65 = . then PCT_UNDER65 = &M_PCT_UNDER65.;
  if MA_PENETRATION = . then MA_PENETRATION = &M_MA_PENETRATION.;
  if TACTINS_EXPEND = . then TACTINS_EXPEND = &M_TACTINS_EXPEND.;
  if UNEMPLOYMENT = . then UNEMPLOYMENT = &M_UNEMPLOYMENT.;
  run;

/* Create Permanent Dataset */
libname ASC '.';

data ASC.asc_datamatrix ( compress = yes );
  set POID_matrix_wcov1;
  run;

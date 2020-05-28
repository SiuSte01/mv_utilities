options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      prep_Matrix_OP_ASC.sas
PURPOSE:           Create OP and ASC data matrices to use in projections
PROGRAMMER:		   Jin Qian
CREATION DATE:     7/31/2012
UPDATED:		   Molli Jones, 5/14/2020
NOTES:			   Called by createxwalks.py
INPUT FILES:	   aha_demo, input.txt, poidmigration_lookup_&Vintage.sas7bdat, CMS_ASC_ProcedureData.txt,
                   zip2fips.sas7bdat, covar_under65.sas7bdat, covar_County_Unemp.sas7bdat, 
				   covar_MA_penetration.sas7bdat, covar_HI_expend.sas7bdat
OUTPUT FILES:	   op_datamatrix.sas7bdat, asc_datamatrix.sas7bdat
****************************************************************************************** */

/* Read in input file and use to set environment variables */
data inputs;
  infile "input.txt" delimiter = '09'x MISSOVER DSD lrecl = 32767 firstobs = 2;
  
  informat Parameter $125.;
  informat Value $200.;
  
  format Parameter $125.;
  format Value $200.;
  
  input Parameter $ Value $;
  run;

data _null_;
  set inputs;
  if Parameter eq 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
  if Parameter EQ 'FXFILES'  then call symput('fxfiles', trim(left(compress(value))));
  if Parameter eq 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
  if Parameter eq 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
  if Parameter eq 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
  if Parameter eq 'AGGREGATION_ID' then call symput('AGGREGATION_ID', trim(left(compress(value))));
  run;
  
%put 'Vintage:' &Vintage;
%put 'FXFILES:' &FXFILES;
%put 'USERNAME:' &USERNAME;
%put 'PASSWORD:' &PASSWORD;
%put 'INSTANCE:' &INSTANCE;
%put 'AGGREGATION_ID:' &AGGREGATION_ID;

/* Set libnames */
libname fxfiles %unquote(%str(%'&FXFILES%'));
libname claim '.';
libname profile oracle user = claims_usr password = claims_usr123 path = PLDWH2DBR SCHEMA = profileData;

/* Get POIDs with Claims in OP */
/* For CA, pick POIDs that show up in both IP and OP claims - these are hospitals */
/* Advisory Board uses CAOPA, NJOPA states - added these in */ 
proc sql;
  connect to oracle ( user = &USERNAME password = &PASSWORD path = &INSTANCE );
  
  create table claim.op_poids as select * from connection to oracle
   ( select distinct h.id_value as HMS_POID, v.vendor_code
       from claimswh.inst_claims a
          inner join claimswh.facility_id_crosswalk h on a.facility_id = h.facility_id
          inner join claimswh.bill_classifications b on a.bill_classification_id = b.bill_classification_id
          inner join claims_aggr.job_vendors v on a.vendor_id = v.vendor_id
       where v.job_id = &AGGREGATION_ID 
	     and ( a.claim_through_date between v.first_vend_date and v.last_vend_date )
         and a.load_batch <= v.last_vend_batch
         and h.id_type='POID'
         and (to_date(%unquote(%str(%'&Vintage%')),'YYYYMMDD') between h.start_date and h.end_date)
         and ( (v.vendor_code = 'CMSOP') or (v.vendor_code in ('WK','FLOP','NYOP','NJOP','NJOPA') and b.classification_code='013' ) )
                         
     union
       ( select distinct HMS_POID, 'CAOPA' as vendor_code from

	      ( select distinct h.id_value as HMS_POID
              from claimswh.inst_claims a
                inner join claimswh.facility_id_crosswalk h on a.facility_id = h.facility_id
                inner join claims_aggr.job_vendors v on a.vendor_id = v.vendor_id
              where v.job_id = &AGGREGATION_ID 
			    and ( a.claim_through_date between v.first_vend_date and v.last_vend_date )
                and a.load_batch <= v.last_vend_batch
                and h.id_type='POID'
                and ( to_date(%unquote(%str(%'&Vintage%')), 'YYYYMMDD' ) between h.start_date and h.end_date )
                and v.vendor_code in ( 'CAOP', 'CAOPA' )
                       
            intersect

            select distinct h.id_value as HMS_POID
              from claimswh.inst_claims a
                inner join claimswh.facility_id_crosswalk h on a.facility_id = h.facility_id
                inner join claims_aggr.job_vendors v on a.vendor_id = v.vendor_id
              where v.job_id = &AGGREGATION_ID 
			    and ( a.claim_through_date between v.first_vend_date and v.last_vend_date )
                and a.load_batch <= v.last_vend_batch
                and h.id_type='POID'
                and ( to_date(%unquote(%str(%'&Vintage%')),'YYYYMMDD' ) between h.start_date and h.end_date )
                and v.vendor_code in ( 'CAIP', 'CAIPA' ) ) ) );
  disconnect from oracle;
  quit;
%put &sqlxmsg;

proc sort data = claim.op_poids ( where = ( hms_poid ^= 'NULL' ) ) out = op_poids nodupkey; by hms_poid; run;

proc sql;
  create table op_poids_zip as
    select a.hms_poid, b.state, b.zip
    from op_poids a 
	     left join profile.Organization_Addresses_View b 
		   on a.hms_poid = b.hms_poid and Vintage_Num = &vintage.;
  quit;

data op_poids;
  set op_poids_zip;
  zip1 = input(zip, 5.0);
  run;

proc sql;
  create table hosp_data as
    select a.hms_poid, a.state, a.zip, b.U65Pct, c.ins as insurance, c.MaPenet, c.Unemp
    from op_poids a
      left join fxfiles.test_u65byhsa b on a.zip1 = b.zipcode
      left join fxfiles.ins_mapenet c on a.zip1 = c.zip1
    order by a.hms_poid;
  quit;
 
data hosp_data1;
  set hosp_data;
  TactInsField = round( insurance, 0.01 );
  drop insurance;
  run;

proc means data = hosp_data1 median nway noprint;
  var U65Pct MAPenet TactInsField Unemp;
  output out = med_opmatrix median =;
  run;

data _null_;
  set med_opmatrix;
  call symput('mapenet', mapenet);
  call symput('U65pct', U65pct);
  call symput('TactInsField', TactInsField);
  call symput('unemp', unemp);
  run;

%put 'TactInsField:' &TactInsField;
%put 'mapenet:' &mapenet;
%put 'U65pct:' &U65pct;
%put 'unemp': &unemp;

data op_datamatrix ( where = ( hms_poid ^= ' ' ) ); /* Impute as median value if missing */
  set hosp_data1;
  if mapenet = . then mapenet = &mapenet;
  if U65pct = . then U65pct = &U65pct;
  if TactInsField = . then TactInsField = &TactInsField;
  if unemp = . then unemp = &unemp;
  run;
   
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
data migrate_poids;
  set fxfiles.poidmigration_lookup_&Vintage.;
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

/* Sort by Type & NODUPKEY for Type --- So alphabetical BOTH - CMS - EMD */
proc sort data = determine2 nodupkey; by HMS_POID Type; run; 

/* Transpose file so Source of POID are column variables */
proc transpose data = determine2 out = determine3; 
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

/* Merge the undupped EMD_CMS dataset with EMD_Flag and CMS_Flag --- creates across all mappings to the POID */
data EMD_CMS_ASC_CORRECT; 
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
  
/* Get POID Profile Information - Will be used to create final OP and ASC Matrices */
proc sql;
  connect to oracle ( user = claims_usr password = claims_usr123 path = PLDWH2DBR );

  create table POID_PROFILE ( compress = yes ) as select * from connection to oracle
    ( select a.HMS_POID, b.ORG_NAME, a.ORGTYPE_DESC as ORG_TYPE,
		     b.ADDRESS1 as ADDRESS_LINE1, b.ADDRESS2 as ADDRESS_LINE2, 
			 b.CITY, b.STATE, b.ZIP, b.ZIP4
       from profileData.organizations_view a 
	   left join profileData.organization_addresses_view b
	     on a.hms_poid = b.hms_poid and a.vintage = b.vintage
	   where a.VINTAGE_NUM = &Vintage. and a.ORGTYPE_CODE like '1%' );
	   
  disconnect from oracle;
  quit;
  
/* Set up ASC Matrix */
proc sort data = ASC_POID_MATRIX; by HMS_POID; run;
proc sort data = POID_PROFILE; by HMS_POID; run;

data All_poids ( compress = yes );
  merge ASC_POID_MATRIX ( in = a ) POID_PROFILE;
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
proc sort data = fxfiles.zip2fips nodupkey out = zips ( keep = ZIP FIPS ); by ZIP; run;
proc sort data = POID_matrix out = temp; by ZIP; run;
proc sort data = fxfiles.covar_under65; by ZIP; run;

data POID_matrix_FIPS ( compress = yes );
  merge temp(in=a) zips fxfiles.covar_under65;
  by ZIP;
  if a;
  run;

proc sort data = fxfiles.covar_County_Unemp; by FIPS; run;
proc sort data=fxfiles.covar_MA_penetration; by FIPS; run;
proc sort data=fxfiles.covar_HI_expend; by FIPS; run;

data POID_matrix_FIPS;
  set POID_matrix_FIPS ( rename = ( FIPS = fips1 ) );
  FIPS = fips1*1;
  run;
  
proc sort data=POID_matrix_FIPS; by FIPS; run;

data POID_matrix_wcov;
  merge POID_matrix_FIPS ( in = a )
        fxfiles.covar_County_Unemp ( keep = FIPS Rate )
        fxfiles.covar_MA_penetration ( keep = FIPS Penetration )
        fxfiles.covar_HI_expend ( keep = FIPS IHXCYHC1 );
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
  
data asc_datamatrix ( compress = yes );
  set POID_matrix_wcov1;
  run;
  
/* Create Final OP Matrix */
proc sort data = op_datamatrix; by HMS_POID; run;

data op_datamatrix;
  merge op_datamatrix ( in = a ) 
        POID_PROFILE ( in = b keep = HMS_POID ORG_NAME ORG_TYPE ADDRESS_LINE1 rename = ( ADDRESS_LINE1 = ADDRESS1 ) );
  by HMS_POID;
  if a and b then do;
    if org_name ^= '' and address1 ^= '' then output;
 	end;
  run;
  
/* Final checks to eliminate overlap between OP and ASC matrices 
     - CMS ASC File is best source of truth
	 - Trust Orgtype Hospital or Ambulatory next
	 - Otherwise, if in both, choose OP */
proc sort data = op_datamatrix nodupkey; by hms_poid; run;  
proc sort data = asc_datamatrix nodupkey; by hms_poid; run;

data op_poid_list ( keep = HMS_POID ) 
     asc_poid_list ( keep = HMS_POID );
merge op_datamatrix ( in = op keep = HMS_POID ORG_TYPE ) 
      asc_datamatrix ( in = asc keep = HMS_POID ORG_TYPE CMS_FLAG );
by HMS_POID;

if op and asc then do;
  if find( ORG_TYPE, "Ambulatory" ) > 0 or CMS_FLAG = 1 then output asc_poid_list;
  else output op_poid_list;
  end;
else if op then do;
  if find( ORG_TYPE, "Ambulatory" ) = 0 and CMS_FLAG = 0 then output op_poid_list;
  end;
else if asc then do;
  if CMS_FLAG = 1 or find( ORG_TYPE, "Hospital" ) = 0 then output asc_poid_list;
  end;
run;

/* Output final datasets */
data claim.op_datamatrix ( drop = ORG_TYPE );
  merge op_datamatrix ( in = a ) op_poid_list ( in = b );
  by HMS_POID;
  if a and b then output;
  run;
  
data claim.asc_datamatrix;
  merge asc_datamatrix ( in = a ) asc_poid_list ( in = b );
  by HMS_POID;
  if a and b then output;
  run;


  


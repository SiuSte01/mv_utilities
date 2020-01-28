options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      opmatrix.sas
PURPOSE:           2012 state and wk data; to update op matrix
PROGRAMMER:		   Jin Qian
CREATION DATE:     7/31/2012
UPDATED:		   Molli Jones, 1/16/2018
NOTES:
INPUT FILES:       aha_demo
OUTPUT FILES:      op_matrix
****************************************************************************************** */

/* Read in input file and use to set environment variables */
data inputs;
  infile "input.txt" delimiter = '09'x MISSOVER DSD lrecl = 32767 firstobs = 2 ;
  format Parameter     $50. ;
  format Value         $200. ;
  informat Parameter   $50. ;
  informat Value       $200. ;
  input Parameter $ Value $ ;
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

/* Set libnames */
libname fxfiles %unquote(%str(%'&FXFILES%'));
libname claim '.';
libname profile oracle user = claims_usr password = claims_usr123 path = PLDWH2DBR SCHEMA = profileData;

/* Get POIDs with Claims */
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
  
/* Get POID Profile Information and Create Final Matrix */
proc sql;
  connect to oracle ( user = claims_usr password = claims_usr123 path = PLDWH2DBR ) ;

  create table POID_PROFILE ( compress = yes ) as select * from connection to oracle
    ( select a.HMS_POID, b.ORG_NAME, b.ADDRESS1 as ADDRESS_LINE1
       from profileData.organizations_view a 
	     left join profileData.organization_addresses_view b
	       on a.hms_poid = b.hms_poid and a.vintage = b.vintage
	   where a.VINTAGE_NUM = &Vintage. and b.org_name is not null and b.address1 is not null );

  disconnect from oracle;
  quit;

proc sort data = op_datamatrix; by HMS_POID; run;
proc sort data = POID_PROFILE; by HMS_POID; run;

data claim.op_datamatrix;
  merge op_datamatrix ( in = a ) POID_PROFILE ( in = b );
  by HMS_POID;
  if a and b then output; 
  run;
  
proc sort data = claim.op_datamatrix nodupkey; by hms_poid; run;  
  
  
  


options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      project_IP_Practitioner.sas
PURPOSE:           Creates the practitioner level projections file from the Facility Level Projections
PROGRAMMER:		   Jin Qian
CREATION DATE:	   07/01/2014
UPDATED:		   Molli Jones - 11/2017
NOTES:			   Runs after project_IP_Facility (Formerly input.sas, ipclaims.sas, excute_proj.sas)
INPUT FILES:	   Facility_Count_Output.sas7bdat
OUTPUT FILES:	   hospital_projections.txt
****************************************************************************************** */

/* Set default values for parameters that may not be contained in the input text file */
%let Filter1500Specialty = N;

/* Read in input text file */
data inputs;
  infile "input.txt" delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
  
  format Parameter	$50. ;
  format Value 		$200. ;
  
  informat Parameter	$50. ;
  informat Value 	$200. ;
  
  input Parameter $ Value $ ;
  run;

/* Use input text file to set values of macrovariables */
data _null_;
  set inputs;

  if Parameter EQ 'COUNTTYPE' and VALUE = 'PATIENT' then call symput('counttype','CLAIM');
  else if Parameter EQ 'COUNTTYPE' and VALUE ~= 'PATIENT' then call symput('counttype',trim(left(compress(value))));

  if Parameter eq 'BUCKET' then do;
    call symput('Bucket', trim("'"||trim(value)||"'"));
    call symput('Bucketn', trim(trim(value)));
	end;

  if Parameter eq 'VINTAGE' then call symput('Vintage', trim(left(compress(value))));
  if Parameter eq 'AGGREGATION_ID' then call symput('AGGRID', trim(left(compress(value))));
  if Parameter eq 'USERNAME' then call symput('USERNAME', trim(left(compress(value))));
  if Parameter eq 'PASSWORD' then call symput('PASSWORD', trim(left(compress(value))));
  if Parameter eq 'INSTANCE' then call symput('INSTANCE', trim(left(compress(value))));
  if Parameter eq 'AGGREGATION_TABLE' then call symput('AGGR', trim(left(compress(value))));
  if Parameter eq 'CLAIM_PATIENT_TABLE' then call symput('AGGRP', trim(left(compress(value))));
  if Parameter eq 'FXFILES' then call symput('FXFILES', trim("'"||left(compress(value))||"'"));
  if Parameter eq 'AddRefDoc' then call symput('AddRefDoc', trim(left(compress(value))));
  if Parameter eq 'CODETYPE' then call symput('CODETYPE', trim(trim(value)));
  if Parameter eq 'Filter1500Specialty' then call symput('Filter1500Specialty', trim(trim(value)));
  if Parameter eq 'INSTANCE' and value='pldwhdbr' then do;
	call symput('TOTAL_COUNT', 'TOTAL_COUNT');
	call symput('FRAC_COUNT', 'FRAC_COUNT');
	call symput('MDCR_COUNT', 'MDCR_COUNT');
    end;
  run;

/* If INSTANCE is pldwh2dbr then determine if PROC or CLAIM counts should be used. [This refers to the New Warehouse Schema] */
data _null_;
  if %unquote(%str(%'&INSTANCE%')) = 'pldwh2dbr' then do;
	if %unquote(%str(%'&COUNTTYPE%'))= 'CLAIM' then do;
	  call symput('TOTAL_COUNT','CLAIM_CNT');
	  call symput('FRAC_COUNT', 'CLAIM_FRAC_CNT');
	  call symput('MDCR_COUNT','MDCR_CLAIM_CNT');
	  end;
	else if %unquote(%str(%'&COUNTTYPE%'))= 'PROC' then do;
	  call symput('TOTAL_COUNT', 'PROC_CNT');
	  call symput('FRAC_COUNT', 'PROC_FRAC_CNT');
	  call symput('MDCR_COUNT', 'MDCR_PROC_CNT');
	  end;
    end;
  run;

/* Output the values of the parameters to the log for easier error checking */
%put 'CountType:' &CountType;
%put 'Vintage:' &Vintage;
%put 'Bucket:' &Bucket;
%put 'Bucketn:' &Bucketn;
%put 'AGGREGATION_ID:' &AGGRID;
%put 'USERNAME:' &USERNAME;
%put 'PASSWORD:' &PASSWORD;
%put 'INSTANCE:' &INSTANCE;
%put 'AGGREGATION_TABLE:' &AGGR;
%put 'CLAIM_PATIENT_TABLE:' &AGGRP;
%put 'FXFILES:' &FXFILES;
%put 'AddRefDoc:' &AddRefDoc;
%put 'TOTAL_COUNT:' &TOTAL_COUNT;
%put 'FRAC_COUNT:' &FRAC_COUNT;
%put 'MDCR_COUNT:' &MDCR_COUNT;
%put 'Filter1500Specialty:' &Filter1500Specialty;
%put 'CODEBASE:' &CODEBASE;
%put 'CODETYPE:' &CODETYPE;

/* Assign LIBNAMES [effective Sept 2016, matrix dataset will be in current directory not in fxfiles] */
libname fxfiles  &FXFILES;
libname claim '.'; 
libname matrloc '.';
libname Child 'Child';

/* Mark Modification: Get PROJECTIP value from facility projections */
/* Mark Modification 9.4.2018: The projectip.txt file location is based on if allcodes or not */
data _null_;
if %unquote(%str(%'&CODETYPE%')) = 'ALL' then call symput('projectiploc','NonChild/projectip.txt');
else call symput('projectiploc','projectip.txt');
run;
%put 'projectiploc:' &projectiploc;

data projectip;
  infile "&projectiploc." delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
  
  format PROJECTIP	$1. ;
  
  informat PROJECTIP	$1. ;
  
  input PROJECTIP $ ;
  run;

data _null_;
  set projectip;

  call symput('PROJECTIP', trim(left(compress(PROJECTIP))));
  run;

%put 'PROJECTIP:' &PROJECTIP;
/* End Mark Modification */

/********************************/
/* Subroutine for Oracle Pulls */
/********************************/ 

/* Get counts from individual data sources from Oracle */
%macro count( src = , aggrname = );
  proc sql;
    connect to oracle( user = &USERNAME password = &PASSWORD path = &INSTANCE );
    create table claim.&src._ip as select *
      from connection to oracle
          (select h.doc_id as hms_piid,
		          h.org_id as hms_poid,
		          &total_count as &counttype._count,
		          &frac_count as &counttype._fraction
		     from &AGGR h
			   where h.bucket_name=&Bucket
					  and h.aggr_name = &aggrname
					  and h.aggr_level = 'DOCORGLEVEL'
					  and h.job_id = &AGGRID );
    disconnect from oracle;
    quit;

  %put &sqlxmsg;
%mend count;
  
/* Rest of code is a single macro since there are several places throughout the code that %IF is needed 
   in order to run different code depending on values of variables that are set in input.txt */ 
%macro complete_ip_projection();

  /* Get raw data from wkub, wkmx, cms, and state - adding NJ here 9/25/2019 since Advisory Board can now get counts */
  %count(src=WKUB, aggrname='WKUB_IP');
  %count(src=WKMX, aggrname='WKMX_IP');
  %count(src=CMS,  aggrname='CMS_IP');
  %count(src=NY,   aggrname='NY_IP');
  %count(src=FL,   aggrname='FL_IP');
  %count(src=WA,   aggrname='WA_IP');
  %count(src=AZ,   aggrname='AZ_IP');
  %count(src=NJ,   aggrname='NJ_IP');

  
  /* Create "migs" version of dataset where if PIID is labeled as MISSING, set it to MISSINGDOC 
     Set state data together into one dataset */
  data claim.WKUB_ip_migs;
    set claim.WKUB_ip;
    if hms_piid='MISSING' then hms_piid='MISSINGDOC';
    run;

  data claim.WKMX_ip_migs;
    set claim.WKMX_ip;
    if hms_piid='MISSING' then hms_piid='MISSINGDOC';
    run;

  data claim.CMS_ip_migs;
    set claim.CMS_ip;
    if hms_piid='MISSING' then hms_piid='MISSINGDOC';
    run;

  data claim.state_ip_migs;
    set claim.az_ip claim.fl_ip claim.ny_ip claim.wa_ip claim.nj_ip; /* Adding NJ here 9/25/2019 since Advisory Board can now get counts */
    if hms_piid='MISSING' then hms_piid='MISSINGDOC';
    run;
	
  /* State Claims at PIID@POID level - remove missing Practitioners */
  proc sort data = claim.state_ip_migs ( where = ( hms_piid ^= 'MISSINGDOC' ) ) out = state_ip_migs;
    by hms_poid hms_piid ;
    run;

  /* State Claims with missing Practitioners */
  proc sort data = claim.state_ip_migs ( where = ( hms_piid = 'MISSINGDOC' ) ) 
    out = state_piid_miss ( rename = ( &counttype._count = state_count_miss ) );
    by hms_poid;
    run;

  /* WK Institutional Claims at PIID@POID level - remove missing Practitioners */
  proc sort data = claim.wkub_ip_migs ( where = ( hms_piid ^= 'MISSINGDOC' ) ) out = wkub_ip_migs;
    by hms_poid hms_piid ;
    run;

  /* WK Institutional Claims with missing Practitioners */
  proc sort data = claim.wkub_ip_migs ( where = ( hms_piid = 'MISSINGDOC' ) ) 
    out = wkub_piid_miss ( rename = ( &counttype._count = wkub_count_miss ) );
    by hms_poid;
    run;
	
  /* Get Projected Facility Level Counts from SAS Output */
  proc sort data = claim.facility_counts_output out = facility_counts_output;
    by hms_poid;          
    run;

  /* Merge together All Payer data [State, WK] with missing Practitioner with Facility Counts */	
  data allpayer_miss ( keep = hms_poid allpayer_miss );
    merge state_piid_miss 
	      wkub_piid_miss 
		  facility_counts_output ( in = a keep = hms_poid POID_Class wk_valid state_valid );
    by hms_poid;

	/* If POID is on Facility Counts and (1) both WK and State data is valid OR (2) State is valid and POID_Class is 1 [poor capture compared to AHA data]
	   then All Payer Missing number is the maximum of the State Missing and the WK Institutional Claims Missing */
    if (wk_valid=1 and state_valid =1) or (state_valid=1 and wk_valid=0 and POID_Class=1 )  then allpayer_miss=max(state_count_miss, wkub_count_miss);
	
    /* Else if POID is on Facility Counts and WK is not Valid but State is then All Payer Missing is the State Missing Value */	
    else if wk_valid in (0,.) and state_valid=1 then allpayer_miss=state_count_miss;

	/* Else if POID is on Facility Counts and (1) WK is Valid and State is not OR (2) Neither WK nor State are valid but POID_Class = 1 
	   the All Payer Missing number is the WK Institutional Claims Missing */
	else if (wk_valid=1 and state_valid in (0,.)) or (state_valid in (0,.) and wk_valid=0 and POID_Class=1 )  then allpayer_miss=wkub_count_miss;
	
	/* Else All Payer Missing Number is Missing */
    else allpayer_miss=.;
    run;

  /* Code was modified to filter physicians in certain specialties based on flag set by input.txt file */
       /***note 12/22/2016: HG aggregation use 'MISSING' instead of 'NULL'***/
  %if %upcase( &Filter1500Specialty ) = Y %then %do;

    /* Get observations from WK 1500 (professional) claims where PIID is not missing and speciality does not contain key words. 
	   Sort by POID, PIID. 4/30/2019: Removed reference to specific POID that was excluded	*/
    proc sql;
      create table wkmx_ip_migs as select a.*
        from claim.wkmx_ip_migs a, fxfiles.indivspec_&Vintage b
        where a.hms_piid = b.hms_piid
              and a.hms_piid not in ('MISSINGDOC')
              and ( coalesce(lowcase(spec1),'MISSING') not like ('%pathology%') 
                      and coalesce(lowcase(spec1),'MISSING') not like ('%radiology%')
                      and coalesce(lowcase(spec1),'MISSING') not like ('%rehabilitation%') 
                      and coalesce(lowcase(spec1),'MISSING') not like ('%emergency%')
                      and coalesce(lowcase(spec1),'MISSING') not like ('%assistive%')
                      and coalesce(lowcase(spec1),'MISSING') not like ('%anesthesiology%')
	                  and coalesce(spec1,'MISSING') not in ('Anesthesiology', 'Nurse Practitioner', 'Physician Assistant',
			                                                'Certified Registered Nurse Anesthetist', 'Nursing', 
						   								    'Certified Nurse Midwife', 'Hospitalist', 'Dentist') )
	          and ( coalesce(lowcase(spec2),'MISSING') not like ('%pathology%') 
                      and coalesce(lowcase(spec2),'MISSING') not like ('%radiology%')
                      and coalesce(lowcase(spec2),'MISSING') not like ('%rehabilitation%') 
                      and coalesce(lowcase(spec2),'MISSING') not like ('%emergency%')
                      and coalesce(lowcase(spec2),'MISSING') not like ('%assistive%')
	                  and coalesce(lowcase(spec2),'MISSING') not like ('%anesthesiology%')
	                  and coalesce(spec2,'MISSING') not in ('Anesthesiology', 'Nurse Practitioner', 'Physician Assistant',
			                                                'Certified Registered Nurse Anesthetist', 'Nursing', 
															'Certified Nurse Midwife', 'Hospitalist', 'Dentist') )											
        order by a.hms_poid, a.hms_piid;
      quit;
    %end;
  %else %do;
  
    /* Otherwise, get observations from WK 1500 (professional) claims where PIID is not missing.
	   Sort by POID, PIID.  */
    proc sort data = claim.wkmx_ip_migs ( where = ( hms_piid ^= 'MISSINGDOC' ) ) out = wkmx_ip_migs;
      by hms_poid hms_piid ;
      run; 
    %end;

  /* Create dataset with All Payer (State and WK Organizational and Professional) data at PIID, POID Level */
  data allpayer_piidatpoid;
    merge wkub_ip_migs ( where = ( hms_poid ^ = 'MISSING' ) rename = ( &counttype._count = wkub_count &counttype._fraction = wkub_fraction ) )
	      state_ip_migs( where = ( hms_poid ^= 'MISSING' ) rename = ( &counttype._count = state_count &counttype._fraction = state_fraction ) )
	      wkmx_ip_migs( where = ( hms_poid ^= 'MISSING' ) rename = ( &counttype._count = wkmx_count &counttype._fraction = wkmx_fraction ) );
    by hms_poid hms_piid ;
    run;

  /* Merge all payer data to projected facility counts.  Keep POIDs in both.  
      NOTE: Starting 10/11/2016 - use CMS piid@poid data only if the poid appears in facility counts */ 
  data allpayer_piidatpoid1;
    merge allpayer_piidatpoid ( in = a ) 
	      facility_counts_output ( in = b keep = hms_poid wk_valid state_valid cms_valid claim_dlvry POID_Class );
    by hms_poid;

	if a and b then do;		
      if claim_dlvry = . then claim_dlvry = 0;
		 
	  /* For Non-CPM runs, if WKMX (All Payer Professional Claims) are greater for this one practitioner 
	     than the projected facility counts for the entire facility then do not use WKMX */
	  /* Use CPM-specific logic for PROJECTIP = N Case --- Molli Jones 3/2018 */	  
	  %if %upcase(&CODETYPE) ^= CPM and %upcase( &PROJECTIP ) = Y %then %do;
		if wkmx_count > claim_dlvry then do; wkmx_count = .; wkmx_fraction = .; end;
		%end;
		
	  output;
	  end;
    run;

  /* CMS Claims at PIID@POID level - remove missing Practitioners */
  proc sort data = claim.cms_ip_migs ( where = ( hms_piid ^= 'MISSINGDOC' ) ) out = cms_ip_migs;
    by hms_poid hms_piid;
    run;

  /* State Claims with missing Practitioners */
  proc sort data = claim.cms_ip_migs ( where = ( hms_piid = 'MISSINGDOC' ) ) 
            out = cms_ip_miss ( drop = hms_piid rename = ( &counttype._count = cms_miss ) );
    by hms_poid ;
    run;

  /* Merge All Payer PIID@POID level data to CMS data */
  proc sort data = allpayer_piidatpoid1; by hms_poid hms_piid; run;

  data allpayer_piidatpoid1;
    merge allpayer_piidatpoid1 (in = a)
	      cms_ip_migs ( rename = ( &counttype._count = pxdx_count &counttype._fraction = pxdx_fraction ) );
    by hms_poid hms_piid;
    run;

  /* Handle ALL CODE Situation: DO NOT USE WKMX if POID-level WKMX > estimated facility counts */
  %if %upcase(&CODETYPE) EQ ALL %then %do;
  
    /* Get Facility Level Totals for WKMX Count */
	proc means data = allpayer_piidatpoid1 noprint nway sum;
      class hms_poid;
      var wkmx_count;
      output out = wkmx_count ( drop = _type_ _freq_ ) sum = ;
      run;

	/* Merge with projected counts and output POIDs where POID-level WKMX > estimated facility counts */
    data claim.wkmx_plus;
      merge wkmx_count facility_counts_output;
      by hms_poid;
	  /* MODIFICATION 11.16.2018: Too many records dropped with strict inequality; changed to 3x higher for balance when PROJECTIP = N */
	  %if &PROJECTIP. = N %then %do;
      if wkmx_count > 3*claim_dlvry then output;
	  %end;
	  %else %do;
      if wkmx_count > claim_dlvry then output;
	  %end;
      run;

	/* Merge PIID@POID level dataset to (1) POIDs where POID-level WKMX > estimated facility counts and (2) Children's POIDs 
	     In case (1) do not use WKMX data, In case (2) do not use CMS data */    
    proc sort data = Child.ip_matrix out = child_poid ( keep = hms_poid ) nodupkey; by hms_poid; run;

    data allpayer_piidatpoid1;
      merge allpayer_piidatpoid1 (in = a) 
	        claim.wkmx_plus ( in = b keep = hms_poid ) 
			child_poid (in = c);
      by hms_poid;

      if a then do;
        if b then do; wkmx_count = .; wkmx_fraction = .; end;
        if c then do; pxdx_count = .; pxdx_fraction = .; end;
        output;
	    end;
	  run;
    %end;

  /* Determine which counts to use based on what is valid and available */
  data claim.allpayer_count;
    set allpayer_piidatpoid1;

	/* If WK and State Data are valid OR State is valid and POID_Class in 1 then decide between State & WK */
    if ( wk_valid = 1 and state_valid = 1 ) or 
	   ( state_valid = 1 and wk_valid = 0 and POID_Class = 1 ) then do;

	  /* If State and both WK institutional and professional claims are missing then set All Payer Counts to 0,
         Otherwise, use the largest value as the All Payer Count for that PIID@POID combo */
	  if ( state_count = . and wkub_count = . and wkmx_count = . ) then do; allpayer_count = 0; allpayer_fraction = 0; end;
      else if max(state_count, wkub_count, wkmx_count) = state_count then do; 
		allpayer_count = state_count; allpayer_fraction = state_fraction; 
		end;
	  else if max(state_count, wkub_count, wkmx_count) = wkub_count then do;
	    allpayer_count = wkub_count; allpayer_fraction = wkub_fraction;
	 	end;
	  else if max(state_count, wkub_count, wkmx_count) = wkmx_count then do;
		allpayer_count = wkmx_count; allpayer_fraction = wkmx_fraction;
		wkmx = 1; /* SET WKMX Flag to 1 if WKMX Data was Used */
	 	end;
  	  end;

    /* If WK is Valid and State is not, or State is not Valid and POID Class = 1 then use WK */
    else if (wk_valid = 1 and state_valid = 0) or  (state_valid = 0 and wk_valid = 0 and POID_Class = 1 ) then do;
	
	  /* If both WK institutional and professional claims are missing then set All Payer Counts to 0,
         Otherwise, use the largest value as the All Payer Count for that PIID@POID combo */
      if (wkub_count = . and wkmx_count = .) then do; allpayer_count = 0; allpayer_fraction = 0; end;
      else if max(wkub_count, wkmx_count) = wkub_count then do; 
	    allpayer_count = wkub_count; allpayer_fraction = wkub_fraction;
		end;
	  else if max(wkub_count, wkmx_count) = wkmx_count then do;
		allpayer_count = wkmx_count; allpayer_fraction = wkmx_fraction;
		wkmx = 1; /* SET WKMX Flag to 1 if WKMX Data was Used */
		end;
      end;

	/* If State is Valid and WK is not then use State or WK Professional Claims */  
    else if wk_valid = 0 and state_valid = 1 then do;
	
	  /* If both State and WK professional claims are missing then set All Payer Counts to 0,
         Otherwise, use the largest value as the All Payer Count for that PIID@POID combo */
      if (state_count = . and wkmx_count = .) then do; allpayer_count = 0; allpayer_fraction = 0; end;
      else if max(state_count, wkmx_count) = state_count then do;
		allpayer_count = state_count; allpayer_fraction = state_fraction;
		end;
      else if max(state_count, wkmx_count) = wkmx_count then do;
		allpayer_count = wkmx_count; allpayer_fraction = wkmx_fraction;
		wkmx = 1; /* SET WKMX Flag to 1 if WKMX Data was Used */
		end;
	  end;

    /* If both WK and State are not valid then use WK Professional Claims if they exist */   
    else if wk_valid = 0 and state_valid = 0 then do;
	  allpayer_count = max(wkmx_count, 0); allpayer_fraction = max(wkmx_fraction,0);
	  wkmx = 1; /* SET WKMX Flag to 1 if WKMX Data was Used */
      end;

	/* If the POID was not in projected facility claims then use WK Professional Claims if they exist */   
    else if wk_valid = . and state_valid = . then do;
	  allpayer_count = max(wkmx_count, 0); allpayer_fraction = max(wkmx_fraction,0);
	  wkmx = 1; /* SET WKMX Flag to 1 if WKMX Data was Used */
      end;

	/* Rename PxDx Counts as CMS Counts (since that is what they originally were) */
	cms_count = pxdx_count;
	cms_fraction = pxdx_fraction;

    /* ONLY ONE OF ALL PAYER AND CMS WILL BE NON_ZERO:
	   If All Payer Count is less than PxDx_Count [CMS] then set All Payer to zero.
       If All Payer Count is greater than or Equal to PxDx_Count [CMS] then set CMS to zero. */
    if allpayer_count < pxdx_count then do; allpayer_count = 0; allpayer_fraction = 0; end;
    else if allpayer_count >= pxdx_count then do; cms_count = 0; cms_fraction = 0; end;

    /* If this POID had 0 claims from the projected facility count, there are All Payer Claims, AND the WKMX flag is set, 
	   then the WKMX flag will remain set.  Note: WKMX Flag being set indicates that All Payer is only from WKMX */
    if claim_dlvry = 0 and allpayer_count > 0 and wkmx = 1 then wkmx = 1; else wkmx = 0;
    drop claim_dlvry;
    run;

  /* Create a working copy of AllPayer_Count dataset that has null PIIDs removed */ 
  proc sql;
    create table allpayer_count as select a.*
      from claim.allpayer_count a
      where hms_piid is not null;
	quit;

  /* Create overall sums of claims and output to log for QA and set global variables */
  proc means data = allpayer_count noprint nway sum;
    var allpayer_count allpayer_fraction cms_count cms_fraction pxdx_count pxdx_fraction ;
    output out = total_claims ( drop = _type_ _freq_ ) sum = ;
    run;

  data _null_;
    set total_claims;
    call symput( 'allpayer', allpayer_count );
    call symput( 'cms', cms_count );
    run;

  %put **********Total number of allpayer claims**********: &allpayer;
  %put **********Total number of cms claims**********: &cms;
  
  /* Sum PIID@POID level counts to POID-level counts */
  proc means data = allpayer_count noprint nway sum;
    class hms_poid;
    var allpayer_count allpayer_fraction cms_count cms_fraction pxdx_count pxdx_fraction;
    output out = claim.poid_sum ( drop = _type_ _freq_ ) sum = ;
    run;

  /* Get POIDs where WKMX flag was set for some PIID:
       - this POID had 0 claims from the projected facility count
	   - there are All Payer Claims for some PIID at this POID
       - for this PIID, All Payer is only from WKMX 
	 Merge this to the POID level sums */
  proc sort data = allpayer_count( where = ( wkmx = 1 ) ) out = poid_wkmx ( keep = hms_poid wkmx ) nodupkey; by hms_poid; run;

  data poid_sum;
    merge claim.poid_sum ( in = b ) poid_wkmx;
    by hms_poid;
    if b then output;
    run;
	
  /* Merge together POID level sums from all payer, projected facility counts, and missing counts from All Payer and CMS
     If this is a CPM run (Molli Jones 3/2018 --- or PROJECTIP = N), 
	 then the merge will take everything in poid_sum replace claim_dlvry [which would be missing] with the allpayer_count for those obs where WKMX = 1
	 Otherwise, the merge is an inner join between poid_sum and facility_counts_output - so, only includes POIDs that have projected numbers (claim_dlvry) */
  data estimated_allpayer_count;
    merge poid_sum(in = b) 
	      facility_counts_output(in = a keep = hms_poid claim_dlvry) 
	      allpayer_miss
	      cms_ip_miss;
    by hms_poid;
    
	%if %upcase(&CODETYPE) EQ CPM or %upcase( &PROJECTIP ) = N %then %do; 
	  if b then do;
        if wkmx = 1 then claim_dlvry = allpayer_count; /* Code formerly said wk1500 - typo was corrected */
	    output;
	    end;
	  %end;
	%else %do;
	  if a and b then output;
	  %end;
    run;

  /* Calculate the 99th percentile for POIDs [exclude POIDs with zero claims] 
     Cutoff is set as 25% of the 99th percentile, rounded to the nearest unit */
  /* Initialize cutoff to some arbitrarily high number in case it's not calculated */
  %let cutoff = 10000;
  proc means data = claim.facility_counts_output ( where = ( claim_dlvry ^= 0 ) ) noprint nway p99;
    var claim_dlvry;
    output out = poid_p99 ( drop = _type_ _freq_ ) p99 = ;
    run;

  data _null_;
    set poid_p99;
    cutoff = round( 0.25*claim_dlvry, 1.0);
    call symput('cutoff', cutoff);
    run;

  %put cutoff: &cutoff;

  /* Adjust projected facility count (claim_dlvry) to allpayer_count for negative factor 
     If can not increase claim_dlvry then do not use allpayer count (set source = CMS)
	   Note: claim_dlvry1 is claim_dlvry before increment */
  data estimated_allpayer_count1;
    length source $ 3;
    set estimated_allpayer_count;

	/* Reset missings to zero */
	if claim_dlvry = . then claim_dlvry = 0;
	if allpayer_miss = . then allpayer_miss = 0;
	if cms_miss = . then cms_miss = 0;
	if allpayer_fraction = . then allpayer_fraction = 0;

	/* Save the value of claim_delvry before increment (this is the projected facility count) */
    claim_dlvry1 = claim_dlvry;

	/* If the projected facility count is less than the sum of the all payer claims (and it is reasonable to adjust the projection) 
	   then use all payer count as the projected value, otherwise set the source to CMS */
	/* Mark Modification 2/2018: in the case of low CMS (non-Advisory Board) as defined by the facility projections, use all payer claims strictly */
	%if %upcase( &PROJECTIP ) = N and %upcase(&CODETYPE) ^= AB %then %do;
	  claim_dlvry = round( allpayer_fraction + allpayer_miss, 1.0);
	  %end;

	%else %do;
      if claim_dlvry < ( allpayer_fraction + allpayer_miss ) then do;
        if ( allpayer_fraction + allpayer_miss ) <=  max( claim_dlvry + &cutoff, 1.25 * claim_dlvry ) then claim_dlvry = round( allpayer_fraction + allpayer_miss, 1.0);
	    else source = 'cms';
	    end;	
	%end;

  /* Store value of pfmax [Maximum Projection Factor] as global variable &lpfmax */
  data _null_;
    set claim.pfmax;
	call symput('lpfmax', pfmax);
    run;

  %put ************lpfmax  = &lpfmax;

  /* Adjust for factor < 1 */
  data estimated_allpayer_count2;
    set estimated_allpayer_count1 ( where = ( source ^= 'cms' ) );

	/* Reset missings to zero */
	if cms_fraction = . then cms_fraction = 0;

	/* Set difference to be the difference between the adjusted projected facility claims (claim_dlvry) and the total all payer (rounded to whole claim) 
	   Note: since excludes obs where source is CMS, we know diff must be zero or positive because of adjustment made in estimated_allpayer_count1 */
	diff = claim_dlvry - round( allpayer_fraction + allpayer_miss, 1.0 );

	/* If the difference between the projected and the all payer is less than the CMS then ...
	    In other words, if All Payer plus CMS is greater than the projected count, then ... */
    if diff >= 0 and  diff <= (cms_fraction + cms_miss) then do;
	
      /* Determine if claim_dlvry (projected claims) can be increased
         If so, increase projected to sum of All Payer and CMS
         If not, do not use All Payer and set source to CMS and reset claim_dlvry to original value */
      diff2 = diff - ( cms_fraction + cms_miss ); /* This is a negative value */
      if claim_dlvry + abs(diff2) <= max( claim_dlvry + &cutoff, 1.25 * claim_dlvry ) then claim_dlvry = round( claim_dlvry + abs(diff2), 1.0 );
      else do; source = 'cms'; claim_dlvry = claim_dlvry1; end;
	  end;
	
    /* Determine factor */
	allpayer_fraction1 = round( allpayer_fraction + allpayer_miss, 1.0 ); /* Total of All Payer for POID */
	
	/* If CMS counts exist and projected counts are greater than all payer, then factor is difference between projected and all payer divided by CMS 
	   If CMS counts exist but projected equals all payer then factor is 1
	   If CMS counts do not exist then factor is 0 */
    if ( cms_fraction + cms_miss ) ^= 0 and claim_dlvry ^= allpayer_fraction1 then 
	  factor = round( ( claim_dlvry - allpayer_fraction1 ) / ( cms_fraction + cms_miss ), 0.0001 );
    else if ( cms_fraction + cms_miss )^= 0 and claim_dlvry = allpayer_fraction1 then factor = 1;
	else if ( cms_fraction + cms_miss ) = 0 then factor = 0;
    run;

  /* For those POIDs that use All Payer data, create dataset called Factor containing POID, projected count, and factor */
  proc sort data = estimated_allpayer_count2 ( where = ( source ^= 'cms' ) ) 
            out = factor ( keep = hms_poid factor claim_dlvry );
    by hms_poid;
    run;

  /* Get actual projection factors from Raw Data */
  proc sort data = claim.poidpf out=poidpf; by hms_poid; run;

  /* Calculate and save the median actual projection factor -- &factorhat */
  proc means data = poidpf median noprint nway ;
    var pf;
    output out = med_factor median = ;
    run;

  data _null_;
    set med_factor;
    call symput('factorhat', pf);
    run;

  %put **********median projection factor***********: &factorhat;

  /* For POIDs where source is not CMS: Compare projected factor to actual factor */
  data claim.factor_merged;
    merge poidpf ( in = a keep = hms_poid pf ) factor ( in = b );
    by hms_poid;
	
	/* If projected factor is greater than the maximum factor then:
   	     Set lmaxpf to be the maximum of the actual factor and the global maximum factor 
		 If the projected factor is greater than this value, then reset it to this value */
	if factor>&lpfmax then do;
      lmaxpf = max(pf,&lpfmax);
      if factor > lmaxpf then factor = lmaxpf;
      end;
	run;

  /* Look at POIDs where source is CMS (i.e. not using All Payer data) */
  data cms_only_poid; 
    set estimated_allpayer_count1 ( where = ( source = 'cms' )  
	                                keep = source hms_poid claim_dlvry pxdx_count pxdx_fraction allpayer_count allpayer_fraction wkmx cms_miss )  
        estimated_allpayer_count2 ( where = ( source = 'cms' ) 
	                                keep = source hms_poid claim_dlvry pxdx_count pxdx_fraction allpayer_count allpayer_fraction wkmx cms_miss );
									
	/* If WKMX = 1 then set projected facility count to all payer count.
	       - this POID had 0 claims from the projected facility count
	       - there are All Payer Claims for some PIID at this POID
           - for this PIID, All Payer is only from WKMX */
    if wkmx = 1 then claim_dlvry = allpayer_count;
	
	/* Otherwise, compare projected counts to CMS Fractional Counts 
	     This was a change, as previously noted in code [change: do not compare claim_dlvry to pxdx fraction] */
		 
	/* If projected claims are less than the CMS fractional counts, reset to CMS fractional counts (rounded to nearest claim) and set factor to 1 */
    else if claim_dlvry < pxdx_fraction then do;
      claim_dlvry = round(pxdx_fraction, 1.0);
	  factor = 1;
	  end;
	  
	/* If projected claims are greater than or equal to the CMS fractional counts, 
	   then set factor to the projected count divided by the total CMS, with a cap on the factor of the global maximum factor */
	else do;
	  factor = round( claim_dlvry / ( pxdx_fraction + cms_miss ), 0.0001 );
	  if factor > &lpfmax then factor = &lpfmax;
	  end;
    run;

  /* Project CMS only facilities:
     - If wkmx = 1 then do not project on cms, use All Payer instead 
	 - Apply factor to PxDx Count and round to nearest whole claim */
  proc sort data = cms_only_poid; by hms_poid; run;
  proc sort data = allpayer_count; by hms_poid; run; /* This is PIID@POID level data */

  /* Use POID level wkmx flag to determine if wkmx data should be used as projected claims */
  data claim_delvry_cms_only;
    merge allpayer_count ( in = a drop = wkmx ) /* We were merging with wkmx in both - with correct one overwriting.  Drop just shows this is deliberate */
	      cms_only_poid ( in = b keep = hms_poid factor claim_dlvry wkmx );
    by hms_poid;

	/* Work with CMS ONLY POIDs */
    if a and b then do;
	
      if wkmx = 1 then projected_claims = allpayer_count;
      else do;
	    if pxdx_fraction = . then pxdx_fraction = 0;
	    if pxdx_count = . then pxdx_count = 0;
	    projected_claims = round( pxdx_count * factor, 1.0 );
		end;
		
	  output;
      end;
	run;
	
  /* Subset out the PIID@POID observations where the POIDs are CMS Only */
  proc sort data = cms_only_poid out = poids ( keep = hms_poid ) nodupkey; by hms_poid; run;

  data allpayer_count1;
    merge allpayer_count (in = a) poids (in = b);
    by hms_poid;
    if a and not b then output;
    run;

  /* Get projected claims from POIDs that are not CMS Only by merging on factors and claim delivery for those POIDs 
       - Only one of CMS or All Payer Claims will exist
	   - If neither exists then projected claims is zero
	   - If all payer claims exist then round them to the nearest claim
	   - If CMS claims exist then apply factor and round them to the nearest claim */
  data claim_delvry;
    merge allpayer_count1 (in = a) claim.factor_merged (in = b);
    by hms_poid;
    
	if a then do;
      if allpayer_count = 0 and cms_count = 0 then projected_claims = 0;
      else if allpayer_count ^= 0 then projected_claims = round( allpayer_count, 1.0 );
      else if cms_count ^= 0 then projected_claims = round( pxdx_count * factor, 1.0);
      output;
	  end;
    run;
	
  /* Set together the CMS Only and non-CMS Only PIID@POID projection counts - only keeping observations where projected claims exist */
  data claim_delvry1 ( where = ( projected_claims > 0 ) keep = hms_poid hms_piid projected_claims );
    set claim_delvry claim_delvry_cms_only;
    run;

  /* Sum up projected counts to PIID level */
  proc means data = claim_delvry1 noprint nway sum;
    class hms_piid;
    var projected_claims;
    output out = piid_count ( drop = _type_ _freq_ ) sum = piid_count;
    run;

  /* CREATE POID-LEVEL FINAL DATASET */

  /* Collapse the non-CMS Only & CMS Only PIID@POID level dataset to POID level
     by sorting by descending poid_count and keeping the observation with the largest poid_count 
	 Once this is complete, set the two datasets together */
  proc sort data = claim_delvry out = poid_count ( keep = hms_poid claim_dlvry rename = ( claim_dlvry = poid_count ) );
    by hms_poid descending claim_dlvry;
    run;

  data poid_count;
    set poid_count;
    by hms_poid;
    if first.hms_poid then output;
    run;

  proc sort data = claim_delvry_cms_only out = poid_count_cms ( keep = hms_poid claim_dlvry rename = ( claim_dlvry = poid_count ) );
    by hms_poid descending claim_dlvry  ;
    run;

  data poid_count_cms;
    set poid_count_cms;
    by hms_poid;
    if first.hms_poid then output;
    run;

  data poid_count;
    set poid_count poid_count_cms;	
    run;

  /* Merge Facilities - Info from IP Matrix & Original Projected Counts*/
  proc sort data = matrloc.ip_datamatrix out = poid nodupkey; by hms_poid; run;
  proc sort data = claim.facility_counts_output ( where = ( claim_dlvry > 0 ) ) 
            out = facility_counts_output nodupkey; 
	by hms_poid; 
	run;

  data facility_counts_output;
    merge facility_counts_output (in = a) poid (in = b);
    by hms_poid;
    if a and b then output;
    run;

  /* Sort datasets to prepare for final merges */
  proc sort data = claim_delvry1 nodupkey; by hms_poid hms_piid; run;
  proc sort data = poid_count nodupkey; by hms_poid; run;

  /* Merge PIID@POID with POID level and set Counts to Final Names */
  data claim.claim_delvry_nocap ( where = ( hms_piid ^= ' ' ) rename = ( projected_claims = PractFacProjCount poid_count = FacProjCount ) );
    merge claim_delvry1 (in = a) poid_count (in = b);
    by hms_poid;
    if a and b then output;
    run;

  /* Merge Non-CMS Only PIID@POID level data with IP Matrix Facilities to filter out POIDs without name or address1 */
  data claim.claim_delvry_filter;
    merge claim.claim_delvry_nocap (in = a) poid (in = b);
    by hms_poid;
    if a and b then output;
    run;

  /* Merge on Practitioner Level Counts */
  proc sort data = claim.claim_delvry_filter; by hms_piid; run;

  data claim.claim_delvry_nocap1 ( rename = ( piid_count = PractNatlProjCount ) );
    merge claim.claim_delvry_filter (in = a) piid_count (in = b);
    by hms_piid;
    if a then output;
    run;

  /* Get PIID total from all payer count dataset (before factoring applied, etc) 
     The 10th highest PIID total will be the global variable maxnum and will be used for capping */
  proc means data = allpayer_count noprint nway sum;
    class hms_piid;
    var allpayer_count;
    output out = allpayer_piid(drop = _type_ _freq_) sum = piid_total;
    run;

  proc sort data = allpayer_piid; by descending piid_total; run;

  option obs = 10;
  data claim.top10;
    set allpayer_piid end = num;
    if num then call symput('maxnum', piid_total);
    run;
  %put *********maxnum: &maxnum***********;
  option obs = max;

  /* Subset out obs where projected claims for PIID is greater than this value 
       NOTE: Based on dataset Non-CMS Only PIID@POID level data with IP Matrix filter */
  data claim_delvry_adj claim_delvry_noadj;
    set claim.claim_delvry_nocap1;
    if PractNatlProjCount > &maxnum then output claim_delvry_adj; else output claim_delvry_noadj;
    run;

  proc sort data = claim_delvry_adj out = adj_piid_count ( keep = hms_piid PractNatlProjCount ) nodupkey;
    by hms_piid;
    run;

  /* Only Cap the PIIDs that have projected counts */
  data claim_delvry_cap;
    set adj_piid_count;

	/* Want 1/11 of the observations to go to 90% of maxnum, 1/11 to go to 91%, ... , 1/11 to 100% */
    x = floor( 11 * ranuni(1) ) * 0.01;
	cap = round( ( 0.90 + x ) * &maxnum, 1.0);
    run;

  /* Apply cap to PIID@POID level for observations that need adjustment 
     Replace National Level Projection for PIID with cap */
  proc sort data = claim_delvry_adj; by hms_piid; run;
  proc sort data = claim_delvry_cap; by hms_piid; run;

  data claim_delvry_adj1 ( keep = hms_piid hms_poid cap PractFacProjCount1 FacProjCount 
	                       rename = ( PractFacProjCount1 = PractFacProjCount cap = PractNatlProjCount ) );
    merge claim_delvry_adj ( keep = hms_piid hms_poid PractFacProjCount FacProjCount PractNatlProjCount ) 
	      claim_delvry_cap ( keep = hms_piid cap );
    by hms_piid;

	PractFacProjCount1 = round( PractFacProjCount * cap / PractNatlProjCount, 1.0 );
	run;

  /* Set together adjusted with non-adjusted 
     Remove invalid observations from the dataset:
	     - Non-Missing PIID with missing/zero/invalid Practitioner AND VALID Practitioner/Facility Counts
		 - Non-Missing PIID with missing/zero/invalid Practitioner/Facility Counts
		 - Non-Missing POID with missing/zero/invalid Facility Counts */
  data claim_delvry1;
    set claim_delvry_noadj ( keep = hms_piid hms_poid PractNatlProjCount PractFacProjCount FacProjCount )  
	    claim_delvry_adj1;

    if ( hms_piid ^= '' and PractNatlProjCount in (.,0) and PractFacProjCount not in (.,0) ) or 
	   ( hms_piid ^= '' and PractFacProjCount in (.,0) ) or
	   ( hms_poid ^= '' and FacProjCount in (.,0) ) then delete;
    run;

  /* Create final dataset */
  proc sort data = claim_delvry1; by hms_poid; run;
  proc sort data = facility_counts_output; by hms_poid; run;

  data claim.claim_delvry ( drop = claim_dlvry );
    length Bucket $50.;
    merge claim_delvry1 (in = a) 
	      facility_counts_output ( in = b keep = hms_poid claim_dlvry );
    by hms_poid;

	/* If this is a POID with no POID@PIID observation, use projected count from Facility Counts code */
    if not a and b then FacProjCount =  claim_dlvry;
    Bucket = "&Bucketn";
    run;

  /* Create final dataset with counts less than 10 reset */
  data claim.claim_delvry_reset ( drop = claim_dlvry );
    length Bucket $50.;
    merge claim_delvry1 (in = a) 
	      facility_counts_output ( in = b keep = hms_poid claim_dlvry );
    by hms_poid;

 	/* If this is a POID with no POID@PIID observation, use projected count from Facility Counts code */
    if not a and b then do;
	  FacProjCount = claim_dlvry;
	  if FacProjCount <= 10 then FacProjCount = 5.5;
      end;
    else do;
      if PractFacProjCount <= 10 then PractFacProjCount = 5.5;
      if FacProjCount <= 10 then FacProjCount = 5.5;
      if PractNatlProjCount <= 10 then PractNatlProjCount = 5.5;
      end;

    Bucket = "&Bucketn";
    run;

  /* Output text files of reports */
  proc sql;
    create table output as
      select a.Bucket, a.hms_piid as HMS_PIID, a.hms_poid as HMS_POID, a.PractFacProjCount, a.PractNatlProjCount, a.FacProjCount
      from claim.claim_delvry_reset a;
    quit;

  proc export data = output outfile = 'hospital_projections.txt' dbms = tab replace; run; 

  proc sql;
    create table output2 as
      select a.Bucket, a.hms_piid as HMS_PIID, a.hms_poid as HMS_POID, a.PractFacProjCount, a.PractNatlProjCount, a.FacProjCount
      from claim.claim_delvry a;
    quit; 

  proc export data = output2 outfile = 'hospital_projections_nostar.txt' dbms = tab replace; run; 

%mend complete_ip_projection;

%complete_ip_projection();



/* MODIFICATION 3.18.2018: New file formats */

data temp;
set output2;
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

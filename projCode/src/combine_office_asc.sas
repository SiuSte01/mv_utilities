libname workdir '.';
options mprint;

data inputs(compress=yes);
infile 'input.txt'
delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
	informat Parameter $125. ;
	informat Value $200. ;
	format Parameter $125. ;
	format Value $200. ;
input Parameter $ Value $ ;
run;

data _null_;
set inputs;
if Parameter = 'COUNTTYPE' then call symput('Counting', trim(left(compress(value))));
if Parameter = 'BUCKET' then call symput('Bucket', trim(left(value)));
run;
%put _USER_;

%macro asc_exist;
	%if %sysfunc(exist(workdir.asc_projections)) %then %do;
	data _null_;
    call symput('ascexist',1);
    run;
	%put ASC Projections exist;
	%end;
	%else %do;
	data _null_;
    call symput('ascexist',0);
    run;
	%put ASC Projections do not exist;
	%end;
	%put ascexist = &ascexist.;
%mend asc_exist;
%asc_exist;

%macro office_exist;
	%if %sysfunc(exist(workdir.all_&Counting._pred)) %then %do;
	data _null_;
    call symput('officeexist',1);
    run;
	%put Office Projections exist;
	%end;
	%else %do;
	data _null_;
    call symput('officeexist',0);
    run;
	%put Office Projections do not exist;
	%end;
	%put officeexist = &officeexist.;
%mend office_exist;
%office_exist;


%macro combine;

%if &ascexist. = 1 and &officeexist. = 1 %then %do;

data asc;
set workdir.asc_projections;
run;

data office_piidpoid;
set workdir.all_&Counting._pred;
PractFacProjCount = FINAL_EST_TOTAL;
drop FINAL_EST_TOTAL;
run;

proc means data=office_piidpoid nway noprint sum;
class HMS_PIID / missing;
var PractFacProjCount;
output out=office_piid(drop=_TYPE_ _FREQ_) sum=PractNatlProjCount;
run;
proc means data=office_piidpoid nway noprint sum;
class HMS_POID / missing;
var PractFacProjCount;
output out=office_poid(drop=_TYPE_ _FREQ_) sum=FacProjCount;
run;

proc sort data=office_piid;
by HMS_PIID;
run;
proc sort data=office_poid;
by HMS_POID;
run;

proc sort data=asc nodupkey out=asc_piidpoid(keep=HMS_PIID HMS_POID PractFacProjCount);
by HMS_PIID HMS_POID;
run;
proc sort data=asc nodupkey out=asc_piid(keep=HMS_PIID PractNatlProjCount);
by HMS_PIID;
run;
proc sort data=asc nodupkey out=asc_poid(keep=HMS_POID FacProjCount);
by HMS_POID;
run;

data officeasc_piidpoid;
set office_piidpoid asc_piidpoid;
run;
proc means data=officeasc_piidpoid nway noprint sum;
class HMS_PIID HMS_POID / missing;
var PractFacProjCount;
output out=officeasc_piidpoidtot(drop=_TYPE_ _FREQ_) sum=;
run;

data officeasc_piid;
set office_piid asc_piid;
run;
proc means data=officeasc_piid nway noprint sum;
class HMS_PIID / missing;
var PractNatlProjCount;
output out=officeasc_piidtot(drop=_TYPE_ _FREQ_) sum=;
run;

data officeasc_poid;
set office_poid asc_poid;
run;
proc means data=officeasc_poid nway noprint sum;
class HMS_POID / missing;
var FacProjCount;
output out=officeasc_poidtot(drop=_TYPE_ _FREQ_) sum=;
run;

proc sort data=officeasc_piidpoidtot;
by HMS_PIID;
run;
proc sort data=officeasc_piidtot;
by HMS_PIID;
run;

data officeasc_tot1;
merge officeasc_piidpoidtot officeasc_piidtot;
by HMS_PIID;
run;

proc sort data=officeasc_tot1;
by HMS_POID;
run;
proc sort data=officeasc_poidtot;
by HMS_POID;
run;

data officeasc_tot2;
merge officeasc_tot1 officeasc_poidtot;
by HMS_POID;
run;

proc sort data=officeasc_tot2;
by HMS_PIID HMS_POID;
run;

data nostar;
length Bucket $100.;
set officeasc_tot2;
Bucket = "&Bucket.";
PractFacClaimCount = PractFacProjCount;
FacClaimCount = FacProjCount;
retain Bucket HMS_PIID HMS_POID PractFacClaimCount FacClaimCount;
drop PractFacProjCount FacProjCount PractNatlProjCount;
run;

data star;
set nostar;
if PractFacClaimCount < 11 then PractFacClaimCount = 5.5;
if FacClaimCount < 11 then FacClaimCount = 5.5;
run;

proc export data=nostar outfile='office_asc_projections_nostar.txt' replace;
run;
proc export data=star outfile='office_asc_projections.txt' replace;
run;

%end;

%else %if &ascexist. = 1 and &officeexist. = 0 %then %do;

data asc;
set workdir.asc_projections;
run;

proc sort data=asc;
by HMS_PIID HMS_POID;
run;

data nostar;
length Bucket $100.;
set asc;
Bucket = "&Bucket.";
PractFacClaimCount = PractFacProjCount;
FacClaimCount = FacProjCount;
retain Bucket HMS_PIID HMS_POID PractFacClaimCount FacClaimCount;
drop PractFacProjCount FacProjCount PractNatlProjCount;
run;

data star;
set nostar;
if PractFacClaimCount < 11 then PractFacClaimCount = 5.5;
if FacClaimCount < 11 then FacClaimCount = 5.5;
run;

proc export data=nostar outfile='office_asc_projections_nostar.txt' replace;
run;
proc export data=star outfile='office_asc_projections.txt' replace;
run;

%end;

%else %if &ascexist. = 0 and &officeexist. = 1 %then %do;

data office_piidpoid;
set workdir.all_&Counting._pred;
PractFacProjCount = FINAL_EST_TOTAL;
drop FINAL_EST_TOTAL;
run;

proc means data=office_piidpoid nway noprint sum;
class HMS_PIID / missing;
var PractFacProjCount;
output out=office_piid(drop=_TYPE_ _FREQ_) sum=PractNatlProjCount;
run;
proc means data=office_piidpoid nway noprint sum;
class HMS_POID / missing;
var PractFacProjCount;
output out=office_poid(drop=_TYPE_ _FREQ_) sum=FacProjCount;
run;

proc sort data=office_piid;
by HMS_PIID;
run;
proc sort data=office_poid;
by HMS_POID;
run;


proc sort data=office_piidpoid;
by HMS_PIID;
run;
proc sort data=office_piid;
by HMS_PIID;
run;

data office_tot1;
merge office_piidpoid office_piid;
by HMS_PIID;
run;

proc sort data=office_tot1;
by HMS_POID;
run;
proc sort data=office_poid;
by HMS_POID;
run;

data office_tot2;
merge office_tot1 office_poid;
by HMS_POID;
run;

proc sort data=office_tot2;
by HMS_PIID HMS_POID;
run;

data nostar;
length Bucket $100.;
set office_tot2;
Bucket = "&Bucket.";
PractFacClaimCount = PractFacProjCount;
FacClaimCount = FacProjCount;
retain Bucket HMS_PIID HMS_POID PractFacClaimCount FacClaimCount;
drop PractFacProjCount FacProjCount PractNatlProjCount;
run;

data star;
set nostar;
if PractFacClaimCount < 11 then PractFacClaimCount = 5.5;
if FacClaimCount < 11 then FacClaimCount = 5.5;
run;

proc export data=nostar outfile='office_asc_projections_nostar.txt' replace;
run;
proc export data=star outfile='office_asc_projections.txt' replace;
run;

%end;

%else %do;
	%put Neither office nor ASC projections exist, no file created;
%end;

%mend;

%combine;

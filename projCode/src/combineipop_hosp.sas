libname ip 'IP';
libname op 'OP';

*split out the piid total, poid total and piid/poid totals from each setting;

  data ip    ;
      %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
      infile
 'IP/hospital_projections_nostar.txt'
	delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
         informat Bucket $50. ;
         informat HMS_PIID $10. ;
         informat HMS_POID $10. ;
         informat PractFacProjCount best32. ;
         informat PractNatlProjCount best32. ;
         informat FacProjCount best32. ;
         format Bucket $50. ;
         format HMS_PIID $10. ;
         format HMS_POID $10. ;
         format PractFacProjCount best12. ;
         format PractNatlProjCount best12. ;
         format FacProjCount best12. ;
      input
                  Bucket $
                  HMS_PIID $
                  HMS_POID $
                  PractFacProjCount
                  PractNatlProjCount
                  FacProjCount
      ;
      if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
  run;


  
  data op    ;
      %let _EFIERR_ = 0; /* set the ERROR detection macro variable */
      infile
 'OP/hospital_projections_nostar.txt'
	delimiter='09'x MISSOVER DSD lrecl=32767 firstobs=2 ;
         informat Bucket $50. ;
         informat HMS_PIID $10. ;
         informat HMS_POID $10. ;
         informat PractFacProjCount best32. ;
         informat PractNatlProjCount best32. ;
         informat FacProjCount best32. ;
         format Bucket $50. ;
         format HMS_PIID $10. ;
         format HMS_POID $10. ;
         format PractFacProjCount best12. ;
         format PractNatlProjCount best12. ;
         format FacProjCount best12. ;
      input
                  Bucket $
                  HMS_PIID $
                  HMS_POID $
                  PractFacProjCount
                  PractNatlProjCount
                  FacProjCount
      ;
      if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
  run;



data ippiid;
set ip;
keep HMS_PIID PractNatlProjCount;
run;

proc sort data = ippiid nodupkey;
by hms_piid PractNatlProjCount;
run;

data oppiid;
set op;
keep HMS_PIID PractNatlProjCount;
run;

proc sort data = oppiid nodupkey;
by hms_piid PractNatlProjCount;
run;

data ippoid;
set ip;
keep HMS_POID FacProjCount;
run;

proc sort data = ippoid nodupkey;
by hms_poid FacProjCount;
run;

data oppoid;
set op;
keep HMS_POID FacProjCount;
run;

proc sort data = oppoid nodupkey;
by hms_poid FacProjCount;
run;

data ipcomb;
set ip;
keep HMS_PIID HMS_POID PractFacProjCount;
run;

data opcomb;
set op;
keep HMS_PIID HMS_POID PractFacProjCount;
run;

*now stack ip and op on top of each other;
data ipoppiid;
set ippiid oppiid;
run;

data ipoppoid;
set ippoid oppoid;
run;

data ipopcomb;
set ipcomb opcomb;
run;

*now combine ip and op counts for each count type using proc means;
proc means data = ipoppiid noprint nway;
class hms_piid;
var PractNatlProjCount;
output out=ipoppiid2 (drop = _TYPE_ _FREQ_) sum=PractNatlProjCount;
run;

proc means data = ipoppoid noprint nway;
class hms_poid;
var FacProjCount;
output out=ipoppoid2 (drop = _TYPE_ _FREQ_) sum=FacProjCount;
run;

proc means data = ipopcomb noprint nway;
class hms_poid hms_piid;
var PractFacProjCount;
output out=ipopcomb2 (drop = _TYPE_ _FREQ_) sum=PractFacProjCount; 
run;

*now merge into 1 dataset;
proc sort data = ipopcomb2;
by hms_piid;
run;

proc sort data = ipoppiid2;
by hms_piid; 
run;

data combined;
merge ipopcomb2 ipoppiid2;
by hms_piid;
run;

proc sort data = combined;
by hms_poid;
run;

proc sort data = ipoppoid2;
by hms_poid;
run;

data combined2;
merge combined ipoppoid2;
by hms_poid;
run;

*reorder colums;
data combined3;
retain HMS_PIID HMS_POID PractFacProjCount PractNatlProjCount FacProjCount;
set combined2;
run;


proc export data = combined3 file='hospital_projections.txt' replace;
run;

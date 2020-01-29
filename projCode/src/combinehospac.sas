options linesize=256 nocenter nonumber nodate mprint;
/* ***************************************************************************************
PROGRAM NAME:      combinehospac.sas
PURPOSE:           combine hospital projection and pac projection


****************************************************************************************** */

*split out the piid total, poid total and piid/poid totals from each setting;

  data PAC_PROJECTIONS    ;
     
    infile  '../PAC/pac_projections.txt' delimiter='09'x MISSOVER DSD lrecl=32767  firstobs=2 ;
         informat HMS_POID $10. ;
         informat HMS_PIID $10. ;
         informat PractFacProjCount 8. ;
         informat PractNatlProjCount 8. ;
         informat FacProjCount 8. ;
         format HMS_POID $10. ;
         format HMS_PIID $10. ;
         format PractFacProjCount 8. ;
         format PractNatlProjCount 8. ;
         format FacProjCount 8. ;
      input
                  HMS_POID $
                  HMS_PIID $
                  PractFacProjCount
                  PractNatlProjCount
                  FacProjCount
      ;
      
run;

 data WORK.HOSPITAL_PROJECTIONS    ;
      
   infile 'hospital_projections_nopac.txt' delimiter='09'x MISSOVER DSD lrecl=32767  firstobs=2 ;
         informat HMS_PIID $10. ;
         informat HMS_POID $10. ;
         informat PractFacProjCount best32. ;
         informat PractNatlProjCount best32. ;
         informat FacProjCount best32. ;
         format HMS_PIID $10. ;
         format HMS_POID $10. ;
         format PractFacProjCount best32. ;
         format PractNatlProjCount best32. ;
         format FacProjCount best32. ;
      input
                  HMS_PIID $
                  HMS_POID $
                  PractFacProjCount
                  PractNatlProjCount
                  FacProjCount
      ;
      if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
 run;

/*ip references hospital, op references PAC in remainder of code - leveraging code from combineipop with minimal changes*/
proc sort data = hospital_projections out=ippiid(keep=HMS_PIID PractNatlProjCount) nodupkey;
by hms_piid ;
run;


proc sort data = pac_projections out=oppiid(keep=HMS_PIID PractNatlProjCount) nodupkey;
by hms_piid ;
run;


proc sort data =hospital_projections out= ippoid(keep=HMS_POID FacProjCount) nodupkey;
by hms_poid ;
run;


proc sort data =pac_projections out= oppoid(keep=HMS_POID FacProjCount) nodupkey;
by hms_poid ;
run;


*now stack ip (aka hospital) and op(aka pac) on top of each other;
data ipoppiid;
set ippiid oppiid;
run;

data ipoppoid;
set ippoid oppoid;
run;

data ipopcomb;
set hospital_projections(keep=HMS_PIID HMS_POID PractFacProjCount) 
	pac_projections(keep=HMS_PIID HMS_POID PractFacProjCount);
run;


*now combine ip and op counts for each count type using proc means;
proc means data = ipoppiid noprint nway sum;
class hms_piid;
var PractNatlProjCount;
output out=ipoppiid2 (drop = _TYPE_ _FREQ_) sum=PractNatlProjCount;
run;

proc means data = ipoppoid noprint nway sum;
class hms_poid;
var FacProjCount;
output out=ipoppoid2 (drop = _TYPE_ _FREQ_) sum=FacProjCount;
run;

proc means data = ipopcomb noprint nway sum;
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

proc export data = combined3 
outfile='hospital_projections.txt' 
dbms=tab replace;
run;

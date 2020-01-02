libname ip 'IP';
libname op 'OP';

*split out the piid total, poid total and piid/poid totals from each setting;

data ippiid;
set ip.claim_delvry;
keep HMS_PIID PractNatlProjCount;
run;

proc sort data = ippiid nodupkey;
by hms_piid PractNatlProjCount;
run;

data oppiid;
set op.claim_delvry;
keep HMS_PIID PractNatlProjCount;
run;

proc sort data = oppiid nodupkey;
by hms_piid PractNatlProjCount;
run;

data ippoid;
set ip.claim_delvry;
keep HMS_POID FacProjCount;
run;

proc sort data = ippoid nodupkey;
by hms_poid FacProjCount;
run;

data oppoid;
set op.claim_delvry;
keep HMS_POID FacProjCount;
run;

proc sort data = oppoid nodupkey;
by hms_poid FacProjCount;
run;

data ipcomb;
set ip.claim_delvry;
keep HMS_PIID HMS_POID PractFacProjCount;
run;

data opcomb;
set op.claim_delvry;
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

options mprint;
*do median/mean by rank on output of deciling script;
*assume the rank output is called decileranksoutput.txt;

*read the file;
proc import file='decileranksoutput.txt' out=deciles replace;
run;

*now do the med/mean table;
proc sort data = deciles;
by DECILE;
run;

proc means data = deciles noprint nway;
by DECILE;
var RAW_SCORE;
output out=medmeantab (drop = _TYPE_ _FREQ_) n=COUNT median=MEDIAN mean=MEAN min=MIN max=MAX;
run;

data medmeantab;
set medmeantab;
mean = round(mean,0.1);
run;

proc export data = medmeantab file='medmean.txt' replace;
run;

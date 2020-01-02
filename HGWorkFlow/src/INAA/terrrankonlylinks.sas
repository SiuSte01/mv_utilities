options mprint;
*do quintiles or deciles or other ranking, depending on input;
*only do the links, not denom;

*read the terr links file;
proc import file='links2rerank.txt' out=links replace;
run;

*read the sor mapping file;
proc import file='sormap.txt' out=sormap replace;
run;

*macro to rank the links;
%macro ranklinks;
 %let sorbins=%sysget(SORBIN);
 proc rank data = links
  groups = &sorbins
  out = linksquint;
  var Count;
  ranks lq;
 run;
%mend;

%ranklinks;

*now merge the mapping value;
proc sort data = linksquint;
by lq;
run;

proc sort data = sormap;
by lq;
run;

data linksquint;
merge linksquint (in=a) sormap;
if a eq 1;
by lq;
run;

*now do the med/mean table;
proc sort data = linksquint;
by SOR;
run;

proc means data = linksquint noprint nway;
by SOR;
var Count;
output out=links1tab (drop = _TYPE_ _FREQ_) n=COUNT median=MEDIAN mean=MEAN min=MIN max=MAX;
run;

data links1tab;
set links1tab;
mean=round(mean,0.1);
run;

proc export data = links1tab file='terrlinksummarycount.txt' replace;
run;

*now drop the count column and export;
*first resort desc;
proc sort data = linksquint;
by descending Count;
run;

data linksquint;
set linksquint;
drop Count SOR;
run;

proc export data=linksquint file='terrlinksrank.txt' replace;
run;

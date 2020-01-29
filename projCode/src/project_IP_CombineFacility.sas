options linesize=256 nocenter nonumber nodate spool;
/* ***************************************************************************************
PROGRAM NAME:      project_IP_OP_combine.sas (formerly combine_facility_count.sas)
PURPOSE:           combine facility counts from children's hospital and not children's
PROGRAMMER:		   Jin Qian
CREATION DATE:	   03/21/2013
NOTES:			  
INPUT FILES:		facility_counts_output from both child and non-child
output files:       facility_counts_output combined
****************************************************************************************** */
libname child 'Child';
libname nchild 'NonChild';
libname claim '.';

/* Set together results from children's facilities (no Medicare) with results from non-children's facilities */
data claim.facility_counts_output;
  set nchild.facility_counts_output child.facility_counts_output;
  run;


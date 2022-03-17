#EH
#3/3/15
#mei datat check - verifies that the majority of MEI records are properly
#crosswalking to HMS PIID and POID records, rather than being attributed
#to null PIIDs or POIDs

# read in meidata table
meidata <-read.table("meidata.txt", header =T, sep="\t", quote="")

#get sum of total units for full result
TotalUnits <- sum(meidata$Procs)

#subset to records with null doc field only 
#and calculate sum of units with null doc
NullDoc <- subset(meidata,Doc=="")
NullDocUnits <-sum(NullDoc$Procs)

#subset to records with null org field only 
#and calculate sum of units with null org
NullOrg <- subset(meidata,Org=="")
NullOrgUnits <- sum(NullOrg$Procs)

#calculate proportion with null doc/org
NullOrgPct <- ((NullOrgUnits/TotalUnits)*100)
NullDocPct <- ((NullDocUnits/TotalUnits)*100)

#print results
####if proportions are greater than 8% for orgs and 2% for indivs
#### discuss with DR or EH
###Add all research of null POID or PIID records to document here: T:/DME_Resellers/QA.xlsx

cat("percent of total units with null doc = ",NullDocPct,"%","\n")
cat("percent of total units with null org = ",NullOrgPct,"%","\n")


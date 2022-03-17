###not quite working. for some reason, increase and decreased are throwing errors. run this from "/vol/cs/clientprojects/Grifols/2017_03_15_IVIG/Gammagard_Procs/QA"


new<-read.hms("individuals.tab",y=c("ZIP"))
old<-read.hms("olddir/individuals.tab",y=c("ZIP"))
terr<-read.hms("../../ZIP_to_Terr_Immunology_Q2_2016_Nov 28.txt",y=c("ZIP"))
#> subnewdocs<-subnew[which(! subnew$HMS_PIID %in% subold$HMS_PIID),]
#> subgonedocs<-subold[which(! subold$HMS_PIID %in% subnew$HMS_PIID),]
#subbothdocs<-subnew[which(subnew$HMS_PIID %in% subold$HMS_PIID),]
#subbothdocs$oldvol<-old$Gammagard_Procs_PRACTITIONER_TOTAL[match(subbothdocs$HMS_PIID,old$HMS_PIID)]
#subbothdocs$change<-subbothdocs$Gammagard_Procs_PRACTITIONER_TOTAL-subbothdocs$oldvol
#largestnew<-subbothdocs[which(subbothdocs$change > 44),]

terrnum<-"GIA13"

indivs.m<-merge(old,new,by="HMS_PIID",all=T)
newdocs<-indivs.m[which(is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),][order(indivs.m[which(is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),"Gammagard_Procs_PRACTITIONER_TOTAL.y"],decreasing=T),][1:10,c("HMS_PIID","FIRST.y","LAST.y","CRED.y","PRACTITIONER_TYPE.y","HMS_SPEC1.y","CITY.y","STATE.y","Gammagard_Procs_PRACTITIONER_NATL_RANK.y","Gammagard_Procs_PRACTITIONER_TOTAL.y","terr.y")]

droppeddocs<-indivs.m[which(is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & indivs.m$terr.y==terrnum),][order(indivs.m[which(is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & indivs.m$terr.y==terrnum),"Gammagard_Procs_PRACTITIONER_TOTAL.x"],decreasing=T),][1:10,c("HMS_PIID","FIRST.x","LAST.x","CRED.x","PRACTITIONER_TYPE.x","HMS_SPEC1.x","CITY.x","STATE.x","Gammagard_Procs_PRACTITIONER_NATL_RANK.x","Gammagard_Procs_PRACTITIONER_TOTAL.x","terr.x")]

increased<-indivs.m[which(! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & ! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),][order(indivs.m[which(! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & ! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),"Change"],decreasing=T),][1:10,c("HMS_PIID","FIRST.y","LAST.y","CRED.y","PRACTITIONER_TYPE.y","HMS_SPEC1.y","CITY.y","STATE.y","Gammagard_Procs_PRACTITIONER_NATL_RANK.x","Gammagard_Procs_PRACTITIONER_NATL_RANK.y","Gammagard_Procs_PRACTITIONER_TOTAL.x","Gammagard_Procs_PRACTITIONER_TOTAL.y","Change","terr.x")]

decreased<-indivs.m[which(! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & ! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),][order(indivs.m[which(! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.y) & ! is.na(indivs.m$Gammagard_Procs_PRACTITIONER_TOTAL.x) & indivs.m$terr.y==terrnum),"Change"],decreasing=F),][1:10,c("HMS_PIID","FIRST.y","LAST.y","CRED.y","PRACTITIONER_TYPE.y","HMS_SPEC1.y","CITY.y","STATE.y","Gammagard_Procs_PRACTITIONER_NATL_RANK.x","Gammagard_Procs_PRACTITIONER_NATL_RANK.y","Gammagard_Procs_PRACTITIONER_TOTAL.x","Gammagard_Procs_PRACTITIONER_TOTAL.y","Change","terr.x")]

colnames(newdocs)<-c("HMS_PIID","FIRST","LAST","CRED","PRACTITIONER_TYPE","SPECIALTY","CITY","STATE","RANK","TOTAL","TERR")
colnames(droppeddocs)<-c("HMS_PIID","FIRST","LAST","CRED","PRACTITIONER_TYPE","SPECIALTY","CITY","STATE","RANK","TOTAL","TERR")
colnames(increased)<-c("HMS_PIID","FIRST","LAST","CRED","PRACTITIONER_TYPE","SPECIALTY","CITY","STATE","OLD_RANK","NEW_RANK","OLD_TOTAL","NEW_TOTAL","CHANGE","TERR")
colnames(decreased)<-c("HMS_PIID","FIRST","LAST","CRED","PRACTITIONER_TYPE","SPECIALTY","CITY","STATE","OLD_RANK","NEW_RANK","OLD_TOTAL","NEW_TOTAL","CHANGE","TERR")

sink("change_output.txt")
print("New doctors")
print(newdocs)
print("Dropped doctors")
print(droppeddocs)
print("Greatest increases")
print(increased)
print("Greatest decreases")
print(decreased)
sink()





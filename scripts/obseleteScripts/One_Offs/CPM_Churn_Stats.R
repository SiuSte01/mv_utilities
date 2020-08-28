#This script was written in August 2016 by Katie to compare CPM June to July deliverables.
#The purpose is to show that there was churn between the months (fixing the issue where no 
#churn was seen in original files), but that the churn was small.

#It takes the piidvolcomp and poidvolcomp files, which show the delta for volumes between months
#and calculates % change. The % change is then binned into categories.

#Change directory as needed. This needs to be run separately for each setting.
setwd("T:/CPM/2016_07_15_PxDx_Enhanced/OP")

#Read in files

poidvolcomp<-read.table("poidvolcomp.txt",sep="\t",as.is=T,quote="",comment.char="",header=T)
piidvolcomp<-read.table("piidvolcomp.txt",sep="\t",as.is=T,quote="",comment.char="",header=T)

sink("CPM_Churn_Stats.txt")

# PIID Volume Change Buckets ----------------------------------------------

#piidvolcomp % Change
Pct_Change_piid<-(piidvolcomp$DeltaCount/piidvolcomp$PrevTotal)*100
abs_Pct_Change_piid<-abs(Pct_Change_piid)
piidvolcomp<-cbind(piidvolcomp,Pct_Change_piid,abs_Pct_Change_piid)

cat("Total PIIDs\n")
nrow(piidvolcomp)

cat("PIIDs: % with No Change\n")
nochange<-piidvolcomp$abs_Pct_Change_piid==0
sum(nochange)/nrow(piidvolcomp)*100

cat("PIIDs: Abs Value of Change < 1%\n")
change_lt_1<-piidvolcomp$abs_Pct_Change_piid<1 & piidvolcomp$abs_Pct_Change_piid!=0
sum(change_lt_1)/nrow(piidvolcomp)*100

cat("PIIDs: Abs Value of Change > 1% and < 5%\n")
change_betw_1_5<-piidvolcomp$abs_Pct_Change_piid>=1 & piidvolcomp$abs_Pct_Change_piid<5
sum(change_betw_1_5)/nrow(piidvolcomp)*100

cat("PIIDs: Abs Value of Change >= 5% and < 10%\n")
change_betw_5_10<-piidvolcomp$abs_Pct_Change_piid>=5 & piidvolcomp$abs_Pct_Change_piid<10
sum(change_betw_5_10)/nrow(piidvolcomp)*100

piidvolcomp<-cbind(piidvolcomp,nochange,change_lt_1,change_betw_1_5,change_betw_5_10)


# POID Volume Change Buckets ----------------------------------------------

#poidvolcomp % Change
Pct_Change_poid<-(poidvolcomp$DeltaCount/poidvolcomp$PrevTotal)*100
abs_Pct_Change_poid<-abs(Pct_Change_poid)
poidvolcomp<-cbind(poidvolcomp,Pct_Change_poid,abs_Pct_Change_poid)


cat("Total POIDs\n")
nrow(poidvolcomp)


cat("POIDs: % with No Change\n")
poid_nochange<-poidvolcomp$abs_Pct_Change_poid==0
sum(poid_nochange)/nrow(poidvolcomp)*100

cat("POIDs: Abs Value of Change < 1%\n")
poid_change_lt_1<-poidvolcomp$abs_Pct_Change_poid<1 & poidvolcomp$abs_Pct_Change_poid!=0
sum(poid_change_lt_1)/nrow(poidvolcomp)*100

cat("POIDs: Abs Value of Change > 1% and < 5%\n")
poid_change_betw_1_5<-poidvolcomp$abs_Pct_Change_poid>=1 & poidvolcomp$abs_Pct_Change_poid<5
sum(poid_change_betw_1_5)/nrow(poidvolcomp)*100

cat("POIDs: Abs Value of Change >= 5% and < 10%\n")
poid_change_betw_5_10<-poidvolcomp$abs_Pct_Change_poid>=5 & poidvolcomp$abs_Pct_Change_poid<10
sum(poid_change_betw_5_10)/nrow(poidvolcomp)*100

poidvolcomp<-cbind(poidvolcomp,poid_nochange,poid_change_lt_1,poid_change_betw_1_5,poid_change_betw_5_10)

sink()
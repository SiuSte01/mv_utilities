#first ran the scatterqc script. questions were raised about the specialties lost.

sedwd("/vol/cs/clientprojects/rdh_ina_test/2016_08_31_ina_directionality_dxcohort4/CKD3_DxCohort_PIIDTOPIID/Comb/national_filter")
cod<-read.hms("network.txt")
con<-read.hms("../../../../2016_08_31_ina_directionality_dxcohort3/CKD3_DxCohort/Comb/national_filter/network.txt")
specd<-as.data.frame(table(cod$HMS_SPEC1_1))
specn<-as.data.frame(table(con$HMS_SPEC1_1))
spec_comb<-merge(specn,specd,by="Var1")
spec_comb$Change<-spec_comb$Freq.x-spec_comb$Freq.y
spec_comb$PctChange<-(spec_comb$Change/spec_comb$Freq.x)*100
pdf("spec_hist.pdf")
hist(spec_comb$Change)
hist(spec_comb$PctChange)
dev.off()

###now look at spec2
specd<-as.data.frame(table(cod$HMS_SPEC1_2))
specn<-as.data.frame(table(con$HMS_SPEC1_2))
spec_comb<-merge(specn,specd,by="Var1")
spec_comb$Change<-spec_comb$Freq.x-spec_comb$Freq.y
spec_comb$PctChange<-(spec_comb$Change/spec_comb$Freq.x)*100
pdf("spec2_cohort_hist.pdf")
hist(spec_comb$Change)
hist(spec_comb$PctChange)
dev.off()

dxpxd<-read.hms("../../../../2016_10_21_ina_directionality_dxtopx4/CKD3_Cardio_DxtoPx_PIIDTOPIID/Comb/national_filter/network.txt")
dxpxn<-read.hms("../../../../2016_10_21_ina_directionality_dxtopx3/CKD3_Cardio_DxtoPx/Comb/national_filter/network.txt")
specd<-as.data.frame(table(dxpxd$HMS_SPEC1_1))
specn<-as.data.frame(table(dxpxn$HMS_SPEC1_1))
spec_comb<-merge(specn,specd,by="Var1")
spec_comb$Change<-spec_comb$Freq.x-spec_comb$Freq.y
spec_comb$PctChange<-(spec_comb$Change/spec_comb$Freq.x)*100
pdf("dxpx_spec_hist.pdf")
hist(spec_comb$Change)
hist(spec_comb$PctChange)
dev.off()

specd<-as.data.frame(table(dxpxd$HMS_SPEC1_2))
specn<-as.data.frame(table(dxpxn$HMS_SPEC1_2))
spec_comb<-merge(specn,specd,by="Var1")
spec_comb$Change<-spec_comb$Freq.x-spec_comb$Freq.y
spec_comb$PctChange<-(spec_comb$Change/spec_comb$Freq.x)*100
pdf("dxpx_spec2_hist.pdf")
hist(spec_comb$Change)
hist(spec_comb$PctChange)
dev.off()






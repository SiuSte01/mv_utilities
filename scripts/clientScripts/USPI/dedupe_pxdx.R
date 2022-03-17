#166 rows were identified by USPI as being duplicated. Upon closer inspection, this was true of all non-demographic columns in those 332 rows that contained the 166 PIID-POID pairs. They were removed as follows:

pxdx<-read.csv("pxdx_duplicated.tab",sep="\t",colClasses='character')
duped<-pxdx[which(duplicated(pxdx[,c("HMS_PIID","HMS_POID")])),]
sub<-pxdx[which(pxdx$HMS_PIID %in% duped$HMS_PIID),]
duped2<-sub[which(paste(sub$HMS_PIID,sub$HMS_POID,sep="_") %in% paste(duped$HMS_PIID,duped$HMS_POID,sep="_")),]
therest<-pxdx[which(! pxdx$HMS_PIID %in% duped$HMS_PIID),]
therest<-rbind(therest,sub[which(! paste(sub$HMS_PIID,sub$HMS_POID,sep="_") %in% paste(duped$HMS_PIID,duped$HMS_POID,sep="_")),])
duped3<-duped2[which(! duped2[,3]==""),]
therest<-rbind(therest,duped3)
write.table(therest,"pxdx.tab",quote=F,sep="\t",row.names=F)

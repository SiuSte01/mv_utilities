
#do QC on newly received MEI data 
#Sudheer prepares wh_stage.mei_claim_counts
#allows code level comparison of last 2 Q to prior 2 Q
######################################## change last2sum and prior2sum to indicate recent quarters.  


#set up the database connection
library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")

#set up your query
myq1<-"select * from wh_stage.mei_claim_counts_NEW"

#executing the query
rs <- dbSendQuery(con, myq1)
data <- fetch(rs)

dbDisconnect(con)

################################################################# change 1 of 1 

last2sum<-data$Q12015+data$Q22015
prior2sum<-data$Q32014+data$Q42014

idx<-which(is.na(last2sum))
if(length(idx) > 0) {
 last2sum[idx]<-0.1
}
idx<-which(is.na(prior2sum))
if(length(idx) > 0) {
 prior2sum[idx]<-0.1
}

pdf("MEI_compqc.pdf")
plot(prior2sum,last2sum,log="xy",pch=4,cex=.5,xlab="prior2Q",
ylab="new2Q")
lines(c(.1,1e7),c(.1,1e7),lwd=3,col="red")
dev.off()


#output all data to a file called data.txt
write.table(data,file="MEI_codes.txt",col.names=T,row.names=F,quote=F,
sep="\t",na="")


diff<-log10((prior2sum)/(last2sum))
diff2<-abs((prior2sum)-(last2sum))
i1<-which(diff2<= 10)
i2<-which((diff < log10(1.1)) & (diff > log10(1/1.1)))
i<-union(i1,i2)
print(length(i1))
print(length(i2))
print(length(i))
pct.good<-100*(length(i)/length(diff2))
cat("percent good = ",pct.good,"\n")

#output only problematic records to a file called baddata.txt
b<-which((diff >= log10(1.25)) & (diff >= log10(1/1.25)))

bad.records<-data[b,]

write.table(bad.records,file="baddata.txt",col.names=T,row.names=F,quote=F,
sep="\t",na="")

library(ROracle)
drv <- dbDriver("Oracle")
#do QC on newly received MEI data 
#Sudheer prepares wh_stage.mei_claim_counts
#allows code level comparison of last 2 Q to prior 2 Q

#set up the database connection
con <- dbConnect(drv, username = "wk_claims_usr", password = "w15c0u0b", dbname = "pldwhdbr")

#set up your query
myq1<-"select * from wh_stage.mei_claim_counts_new"

#executing the query
rs <- dbSendQuery(con, myq1)
data <- fetch(rs)

dbDisconnect(con)

last2sum<-data$Q12014+data$Q22014
prior2sum<-data$Q32013+data$Q42013

idx<-which(is.na(last2sum))
if(length(idx) > 0) {
 last2sum[idx]<-0.1
}
idx<-which(is.na(prior2sum))
if(length(idx) > 0) {
 prior2sum[idx]<-0.1
}

pdf("compqc_meiQ1Q22014.pdf")
plot(prior2sum,last2sum,log="xy",pch=4,cex=.5,xlab="prior2Q",
ylab="new2Q")
lines(c(.1,1e7),c(.1,1e7),lwd=3,col="red")
dev.off()



#output the data to a file called data.txt
write.table(data,file="data_meiQ1Q22014.txt",col.names=T,row.names=F,quote=F,
sep="\t",na="")


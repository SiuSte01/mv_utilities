args = commandArgs(trailingOnly=TRUE)

if (length(args) < 1){
cat("This script requires at least one job process id to run.\nMultiple ids can be supplied separated by spaces.\nJob process ids can be found in client/project/config/logFiles/build*StatusLog.txt\n")
quit()
}

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr", password = "claims_usr123", dbname = "pldwh2dbr")

query<-paste("select * from claims_aggr.aggr_queue_jobs where job_process_id in (",paste(args,collapse=","),")",sep="")

rs <- dbSendQuery(con, query)
status <- fetch(rs)
print(status)



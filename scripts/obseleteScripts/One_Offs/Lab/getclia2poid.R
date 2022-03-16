library(ROracle)
drv <- dbDriver("Oracle")

#set up the database connection
con <- dbConnect(drv, username = "hms_pe", password = "hms_pe123", dbname = "pldeldb")

#set up your query
myq1<-" select org_pos_id as clia, hms_poid from ddb_20160720.m_org_pos
where sources like '%POS_CLIA%'"

#executing the query
rs <- dbSendQuery(con, myq1)
data <- fetch(rs)

dbDisconnect(con)

#output the data to a file called data.txt
write.table(data,file="clia2poid_20160720.txt",col.names=T,row.names=F,quote=F,
sep="\t",na="")


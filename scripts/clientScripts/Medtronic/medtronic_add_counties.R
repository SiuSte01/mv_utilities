





library(maptools)
library(maps)
library(sp)

source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")

orgs<-read.hms("organizations.tab")
latlong<-read.hms("../delivery/organizations.txt",sep="|")

orgs[,c("LATITUDE","LONGITUDE")]<-latlong[match(orgs$HMS_POID,latlong$HMS_POID),c("LATITUDE","LONGITUDE")]

counties <- map('county', fill=TRUE, col="transparent", plot=FALSE)
IDs <- sapply(strsplit(counties$names, ":"), function(x) x[1])
counties_sp <- map2SpatialPolygons(counties, IDs=IDs,proj4string=CRS("+proj=longlat +datum=WGS84"))
countyNames <- sapply(counties_sp@polygons, function(x) x@ID)
pointsSP <- SpatialPoints(orgs[which(! is.na(orgs$LATITUDE)),c("LONGITUDE","LATITUDE")],proj4string=CRS("+proj=longlat +datum=WGS84"))
indices <- over(pointsSP, counties_sp)
orgs$county_name[which(! is.na(orgs$LATITUDE))]<-countyNames[indices]

sums<-aggregate(orgs[,c(grep("TOTAL",colnames(orgs)))],by=list(orgs$county_name),sum,na.rm=T)
colnames(sums)[1]<-"County"

sums$State<-sapply(strsplit(sums$County, ","), function(x) x[1])
sums$County<-sapply(strsplit(sums$County, ","), function(x) x[2])
sums<-sums[,c(1,ncol(sums),2:(ncol(sums)-1))]

sums[,c(3:ncol(sums))][sums[,c(3:ncol(sums))]<11]<-"*"

write.hms(sums,"Sum_totals_by_county.txt",sep="|")


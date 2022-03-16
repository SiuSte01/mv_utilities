library("maps", lib.loc="/home/rhopson/R/x86_64-redhat-linux-gnu-library/3.1")
library("ggplot2", lib.loc="/home/rhopson/R/x86_64-redhat-linux-gnu-library/3.1")
library("RColorBrewer", lib.loc="/home/rhopson/R/x86_64-redhat-linux-gnu-library/3.1")
#library("rgdal", lib.loc="~/R/R-3.2.3/library")

#define function scale_state
scale_state<-function(state_data_frame,id,longscale,latscale){
  #scale long
  state_min<-min(state_data_frame[["long"]][which(state_data_frame[["id"]]==id)])
  state_range<-range(state_data_frame[["long"]][which(state_data_frame[["id"]]==id)])
  state_range<-state_range[2]-state_range[1]
  state_data_frame[["long"]][which(state_data_frame[["id"]]==id)]<-(state_data_frame[["long"]][which(state_data_frame[["id"]]==id)]-state_min)/state_range
  state_data_frame[["long"]][which(state_data_frame[["id"]]==id)]<-state_data_frame[["long"]][which(state_data_frame[["id"]]==id)]*longscale+state_min
  
  print(paste(state_min,state_range,longscale))
  
  #scale  lat####
  state_min<-min(state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)])
  state_range<-range(state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)])
  state_range<-state_range[2]-state_range[1]
  state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)]<-(state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)]-state_min)/state_range
  state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)]<-state_data_frame[["lat"]][which(state_data_frame[["id"]]==id)]*latscale+state_min
  
  print(paste(state_min,state_range,latscale))
  
  assign(paste(as.list(sys.call())[[2]]),state_data_frame,envir=.GlobalEnv)
  
}

#read in map data####
test_states<-readOGR("C:/Users/Hopsry01/Downloads/cb_2014_us_state_5m","cb_2014_us_state_5m")
test_states_df<-fortify(test_states)
test_states_names<-test_states@data[,c("GEOID","STUSPS","NAME")]
test_states_names$id<-row.names(test_states_names)

#exclude off the map territory####
test_states_df<-test_states_df[which(!test_states_df$id %in% c(53,54,55,28,47)),]


#read in value data####
state_data<-read.csv("T://VGM/2016_03_28_SS_Ortho_Dx_counts/milestones/counts/heat_map.tab",sep="\t")
fips_data<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/data/state_to_fips.txt",sep="\t")
abb_data<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/data/name_to_abb.txt",sep="\t")
abb_data[,1]<-tolower(abb_data[,1])
state_data$name<-tolower(fips_data$Name[match(state_data$FIPS_CODE,fips_data$Numeric.code)])

####crosswalk - add "group" to our data, and "name" to map####
#this was the bigegst issue, was causing weird lines, because all points in a state were listed as the same polygon, even if non-contiguous in reality
test_states_df$name<-tolower(test_states_names$NAME)[match(test_states_df$id,test_states_names$id)]
state_data$group<-test_states_df$group[match(state_data$name,test_states_df$name)]
test_states_df$abb<-abb_data$Abbreviation[match(test_states_df$name,abb_data$State)]
state_names<-aggregate(cbind(long,lat) ~ abb,data=test_states_df,FUN=function(x)mean(range(x)))
state_names$group<-test_states_df$group[match(state_names$abb,test_states_df$abb)]

#fix alaska####
#test_states_df<-backup
#first, gather all the aleutian islands on one side of the map
####CHECK THIS WITH FULL DATA
test_states_df$long[which(test_states_df$id==32 & test_states_df$long > 0)]<- (-180 - (180-test_states_df$long[which(test_states_df$id==32 & test_states_df$long > 0)]))
test_states_df$long[which(test_states_df$id==32)]<-test_states_df$long[which(test_states_df$id==32)]+60
test_states_df$lat[which(test_states_df$id==32)]<-test_states_df$lat[which(test_states_df$id==32)]-30

#scale Alaska###
scale_state(test_states_df,32,15,10)

#backup for testing####
#backup<-test_states_df
#test_states_df<-backup

####move Hawaii####
#test_states_df<-backup
test_states_df$long[which(test_states_df$id==36)]<-test_states_df$long[which(test_states_df$id==36)]+48
test_states_df$lat[which(test_states_df$id==36)]<-test_states_df$lat[which(test_states_df$id==36)]+2.5

#scale up Hawaii####
scale_state(test_states_df,36,10,7)

##plot data####
##add region to test_states_df, or it will fail
test_states_df$region<-test_states_df$name

ggplot(data=test_states_df,aes(group=group))+geom_map(data=state_data,aes(fill = state_data$TOTAL_COUNTS,map_id = name),map=test_states_df)+scale_fill_distiller(palette="RdYlBu")+theme_void()+geom_path(data=test_states_df,aes(x=long,y=lat,map_id=group),colour='grey',size=.75)+coord_map()+theme(legend.position=c(0.9,0.35))

ggplot(data=test_states_df,aes(group=group))+theme_void()+geom_path(data=test_states_df,aes(x=long,y=lat,map_id=group),colour='grey',size=.75)+coord_map()+theme(legend.position=c(0.9,0.35))

###add labels
#state_namesorig<-aggregate(cbind(long,lat) ~ abb,data=test_states_df,FUN=function(x)mean(range(x)))
#state_namesorig$group<-test_states_df$group[match(state_namesorig$abb,test_states_df$abb)]
state_names<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/data/state_names.csv",row.names = 1)

#remove DC - can't see it anyway
state_names<-state_names[which(!state_names$abb %in% c("DC")),]

#read in data for lines
lines_test<-read.csv("/vol/cs/CS_PayerProvider/Ryan/R/data/lines_for_small_states.csv",row.names = 1)

#ggplot(data=test_states_df,aes(group=group))+theme_void()+geom_path(data=test_states_df,aes(x=long,y=lat,map_id=group),colour='black',size=.75)+coord_map()+theme(legend.position=c(0.9,0.35))+geom_text(data=state_names, aes(long, lat, label = abb), size=4.7, colour='black',fontface='bold')+geom_vline(xintercept = -130:-65,colour='grey')+geom_hline(yintercept = 50:20,colour='grey')

ggplot(data=test_states_df,aes(group=group))+geom_map(data=state_data,aes(fill = state_data$TOTAL_COUNTS,map_id = name),map=test_states_df)+theme_void()+scale_fill_distiller(palette="Reds",direction = 1)+geom_path(data=test_states_df,aes(x=long,y=lat,map_id=group),colour='slategray',size=.75)+coord_map()+theme(legend.position=c(0.9,0.35))+geom_text(data=state_names, aes(long, lat, label = abb), size=4.7, colour='black',fontface='bold')+geom_path(data=lines_test,aes(x=long,y=lat,map_id=group),colour='black',size=.75)

#

#####loop for state names####
#for (i in unique(test_states_df$id)){
#  print(i)
#  test_states_df<-test_states_df[which(test_states_df$id==i),]

#  g<-ggplot(data=test_states_df,aes(group=group))+geom_path(data=test_states_df,aes(x=long,y=lat,map_id=group),colour='grey',size=.75)+coord_map()+ggtitle(i)

#  if ( i %in% c(28,39,40,47)){print(g)}

#  test_states_df<-backup

#  }
##############end####

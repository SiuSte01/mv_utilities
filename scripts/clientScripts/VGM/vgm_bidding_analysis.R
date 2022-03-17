###this script is designed to look at the claims volume associated with docs in a particular geography where a competitive bid was previously won. The intent of the analysis is to see if the bid win influenced volume in that area.
source("/vol/cs/CS_PayerProvider/Ryan/R/hms_R_functions.R")
oracle()

query<-"SELECT supplier_ptan, claim_year, date_of_serv_quarter, new_unit, units_allowed FROM Hcfa_Saf.Mei_Dmeclaims dme
inner join profiledata.practitioners_view prac
on dme.certifying_pract_npi = prac.npi
inner join profiledata.practitioner_addresses_view ad
on prac.hms_piid = ad.hms_piid
where claim_year = 2016
and prac.vintage = to_date('06/22/2016','MM/DD/YYYY')
and ad.vintage = to_date('06/22/2016','MM/DD/YYYY')
and procedure_code = 'E0601'
and zip in (80106,80132,80133,80808,80809,80813,80814,80816,80817,80819,80829,80831,80833,80840,80841,80860,80863,80864,80866,80901,
80902,80903,80904,80905,80906,80907,80908,80909,80910,80911,80912,80913,80914,80915,80916,80917,80918,80919,80920,80921,80922,80923,
80924,80925,80926,80927,80928,80929,80930,80931,80932,80933,80934,80935,80936,80937,80938,80939,80940,80941,80942,80943,80944,80945,
80946,80947,80949,80950,80951,80960,80962,80970,80977,80995,80997,80001,80002,80003,80004,80005,80006,80007,80010,80011,80012,80013,
80014,80015,80016,80017,80018,80019,80020,80021,80022,80023,80024,80030,80031,80033,80034,80035,80036,80037,80038,80040,80041,80042,
80044,80045,80046,80047,80102,80103,80104,80105,80108,80109,80110,80111,80112,80113,80116,80118,80120,80121,80122,80123,80124,80125,
80126,80127,80128,80129,80130,80131,80134,80135,80136,80137,80138,80150,80151,80155,80160,80161,80162,80163,80165,80166,80201,80202,
80203,80204,80205,80206,80207,80208,80209,80210,80211,80212,80214,80215,80216,80217,80218,80219,80220,80221,80222,80223,80224,80225,
80226,80227,80228,80229,80230,80231,80232,80233,80234,80235,80236,80237,80238,80239,80241,80243,80244,80246,80247,80248,80249,80250,
80251,80252,80256,80257,80259,80260,80261,80262,80263,80264,80265,80266,80271,80273,80274,80279,80280,80281,80290,80291,80293,80294,
80295,80299,80401,80402,80403,80419,80422,80425,80427,80433,80437,80439,80453,80454,80457,80465,80470,80474,80601,80602,80614,80640)"

data<-fetch(dbSendQuery(con, query))
#data2<-data[which(data$UNITS_ALLOWED > 0),]
data3<-aggregate(UNITS_ALLOWED ~ SUPPLIER_PTAN + DATE_OF_SERV_QUARTER,data = data, FUN=sum)
data4<-reshape(data3, idvar = "SUPPLIER_PTAN", timevar = "DATE_OF_SERV_QUARTER", direction = "wide")
data4[is.na(data4)]<-0
data4$Q1and2<-data4$UNITS_ALLOWED.Q1+data4$UNITS_ALLOWED.Q2
data4$Q3and4<-data4$UNITS_ALLOWED.Q3+data4$UNITS_ALLOWED.Q4
data4<-data4[which(! (data4$Q1and2 == 0 & data4$Q3and4 == 0)),]
data4$diff<-data4$Q3and4-data4$Q1and2
data4$SUPPLIER_PTAN[which(nchar(data4$SUPPLIER_PTAN)==9)]<-paste('0',data4$SUPPLIER_PTAN[which(nchar(data4$SUPPLIER_PTAN)==9)],sep="")

#what if we don't exclude units allowed 0 and then exclude nas?
#what if we compare this to another geographic area, or national?
#what do we do about the crazy outliers?

nat_query<-"SELECT supplier_ptan, claim_year, date_of_serv_quarter, new_unit, units_allowed FROM Hcfa_Saf.Mei_Dmeclaims dme
inner join profiledata.practitioners_view prac
on dme.certifying_pract_npi = prac.npi
inner join profiledata.practitioner_addresses_view ad
on prac.hms_piid = ad.hms_piid
where claim_year = 2016
and prac.vintage = to_date('06/22/2016','MM/DD/YYYY')
and ad.vintage = to_date('06/22/2016','MM/DD/YYYY')
and procedure_code = 'E0601'"

nat_data<-fetch(dbSendQuery(con, nat_query))
nat_data3<-aggregate(UNITS_ALLOWED ~ SUPPLIER_PTAN + DATE_OF_SERV_QUARTER, data = nat_data, FUN=sum)
nat_data4<-reshape(nat_data3, idvar = "SUPPLIER_PTAN", timevar = "DATE_OF_SERV_QUARTER", direction = "wide")
nat_data4[is.na(nat_data4)]<-0
nat_data4$Q1and2<-nat_data4$UNITS_ALLOWED.Q1+nat_data4$UNITS_ALLOWED.Q2
nat_data4$Q3and4<-nat_data4$UNITS_ALLOWED.Q3+nat_data4$UNITS_ALLOWED.Q4
nat_data4<-nat_data4[which(! (nat_data4$Q1and2 == 0 & nat_data4$Q3and4 == 0)),]
nat_data4$diff<-nat_data4$Q3and4-nat_data4$Q1and2
nat_data4<-reshape(nat_data3, idvar = "SUPPLIER_PTAN", timevar = "DATE_OF_SERV_QUARTER", direction = "wide")
nat_data4[is.na(nat_data4)]<-0
nat_data4$Q1and2<-nat_data4$UNITS_ALLOWED.Q1+nat_data4$UNITS_ALLOWED.Q2
nat_data4$Q3and4<-nat_data4$UNITS_ALLOWED.Q3+nat_data4$UNITS_ALLOWED.Q4
nat_data4$diff<-nat_data4$Q3and4-nat_data4$Q1and2
nat_data4$SUPPLIER_PTAN[which(nchar(nat_data4$SUPPLIER_PTAN)==9)]<-paste('0',nat_data4$SUPPLIER_PTAN[which(nchar(nat_data4$SUPPLIER_PTAN)==9)],sep="")
nat_data4<-nat_data4[which(nat_data4$SUPPLIER_PTAN != " "),]

#have to pull NPI from 2 places, one is directly from PE_NPI_ORG_20160914_IDENTIFIER, the other is by adding POID and crosswalking to npi
#update - crossing to poid then bringing in NPI has proven to be far more effective at generating NPIs that line up with paid deliverables
con2 <- dbConnect(dbDriver("Oracle"), username = "HMS_PE", password = "hms_pe123", dbname = "PLDELDB")
#xwalk<-fetch(dbSendQuery(con2, "select * from PE_NPI_ORG_20160914_IDENTIFIER where type = 07"))
xwalk<-fetch(dbSendQuery(con, "select * from claims_aggr.JC_PE_NPI_ORG_20170411_IDENTIF where type = 07"))

#poid2npi<-fetch(dbSendQuery(con,"SELECT * FROM profiledata.organizations_view where NPI <> ' ' and vintage = to_date('07/13/2016','MM/DD/YYYY')"))
poid2npi<-fetch(dbSendQuery(con,"SELECT * FROM profiledata.organizations_view where NPI <> ' ' and vintage = to_date('01/31/2018','MM/DD/YYYY')"))

poidxwalk<-fetch(dbSendQuery(con,"SELECT * FROM profiledata.ptan_to_poid a WHERE a.vintage = '31-JAN-2018'"))

full_xwalk<-data.frame("PTAN"=nat_data4$SUPPLIER_PTAN)
full_xwalk$NPI_PE<-xwalk$NPI[match(full_xwalk$PTAN,xwalk$IDENTIFIER)]
full_xwalk$HMS_POID<-poidxwalk$HMS_POID[match(paste("0000000000",full_xwalk$PTAN,sep=""),poidxwalk$PTAN)]
full_xwalk$NPI_POID<-poid2npi$NPI[match(full_xwalk$HMS_POID,poid2npi$HMS_POID)]

full_xwalk$NPI_comb<-full_xwalk$NPI_POID
full_xwalk$NPI_comb[which(is.na(full_xwalk$NPI_comb))]<-full_xwalk$NPI_PE[which(is.na(full_xwalk$NPI_comb))]

#validated the above method of creating a crosswalk against a recent project. there were only 2 NPIs in that project that did not match NPI_comb, likely because that project was made with a slightly older vintage.

namesq<-"select * from profiledata.organization_addresses_view where vintage = '31-JAN-2018'"
names<-fetch(dbSendQuery(con,namesq))
names$NPI<-poid2npi$NPI[match(names$HMS_POID,poid2npi$HMS_POID)]

nat_data4$NPI<-full_xwalk$NPI_comb[match(nat_data4$SUPPLIER_PTAN,full_xwalk$PTAN)]
nat_data_out<-nat_data4[,c("NPI","Q1and2","Q3and4","diff")]
nat_data_out<-nat_data_out[which(!is.na(nat_data_out$NPI)),]
nat_data_out[,c("ORG_NAME","ADDRESS1","CITY","STATE","ZIP")]<-names[match(nat_data_out$NPI,names$NPI),c("ORG_NAME","ADDRESS1","CITY","STATE","ZIP")]

data4$NPI<-full_xwalk$NPI_comb[match(data4$SUPPLIER_PTAN,full_xwalk$PTAN)]
data_out<-data4[,c("NPI","Q1and2","Q3and4","diff")]
data_out<-data_out[which(!is.na(data_out$NPI)),]
data_out[,c("ORG_NAME","ADDRESS1","CITY","STATE","ZIP")]<-names[match(data_out$NPI,names$NPI),c("ORG_NAME","ADDRESS1","CITY","STATE","ZIP")]

write.hms(nat_data_out, "national_E0601_data.tab")
write.hms(data_out, "local_E0601_data.tab")









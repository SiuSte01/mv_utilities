#Created a variable as the main directory where I want the folders. 
deliv.dir<- paste("/vol/cs/clientprojects/Memorial_Hermann/",deliv_date,"_MH_Delivery/Flat_Files_Work",sep="")
#Create folders that are needed for the delivery set up
folders <- c("ALL_ALL",
             "ALL_IP",
             "ALL_OP",
             "Diabetes_ALL",
             "Heart_Vascular_ALL_IP_OP_Px",
             "Hypertension_Dyslipidemia_ALL_Dx",
             "Neurosciences_ALL_IP_OP_Px",
             "OB_Delivery_ALL_PX",
             "Ortho_ALL_IP_OP_Px")
for (i in 1:length(folders)) {dir.create(paste(deliv.dir,folders[i], sep="/"))}



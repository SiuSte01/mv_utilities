# prefix<-"Y16M11"

#Note: This script uses Linux commands to tar zip the files, so this script must be run in plr01 to work.


# Freestanding ------------------------------------------------------------
#Navigate to Freestanding directory
setwd("Freestanding")

#Rename pxdxresult file and add prefix
freestanding_pxdx_name<-paste0(prefix,"FREESTANDINGPXDXresult.txt")
file.copy("pxdxresult.txt","pxdxresult_copy.txt",overwrite=F)
file.rename("pxdxresult_copy.txt",freestanding_pxdx_name)

#Create tar.gz file for splitter
#Note: This uses a Linux command to tar zip the files, so this script must be run in plr01 to work.
system("tar -cvf freestandingsplitter.tar *FREESTANDINGPXDXresult.txt")
system("gzip freestandingsplitter.tar")

#Rename migrations file and add prefix
freestanding_mig_name<-paste0(prefix,"freestandingmigrations.txt")
file.copy("final_migrations.txt","final_migrations_copy.txt",overwrite=F)
file.rename("final_migrations_copy.txt",freestanding_mig_name)

#Create tar.gz file for migrations
system("tar -cvf freestandingmigrations.tar *freestandingmigrations.txt")
system("gzip freestandingmigrations.tar")


# IP ----------------------------------------------------------------------

#Navigate to IP directory
setwd("../IP")

#Rename pxdxresult file and add prefix
ip_pxdx_name<-paste0(prefix,"IPPXDXresult.txt")
file.copy("pxdxresult.txt","pxdxresult_copy.txt",overwrite=F)
file.rename("pxdxresult_copy.txt",ip_pxdx_name)

#Create tar.gz file for splitter
system("tar -cvf ipsplitter.tar *IPPXDXresult.txt")
system("gzip ipsplitter.tar")

#Rename migrations file and add prefix
ip_mig_name<-paste0(prefix,"ipmigrations.txt")
file.copy("final_migrations.txt","final_migrations_copy.txt",overwrite=F)
file.rename("final_migrations_copy.txt",ip_mig_name)

#Create tar.gz file for migrations
system("tar -cvf ipmigrations.tar *ipmigrations.txt")
system("gzip ipmigrations.tar")


# OP ----------------------------------------------------------------------
#Navigate to OP directory
setwd("../OP")

#Rename pxdxresult file and add prefix
op_pxdx_name<-paste0(prefix,"OPPXDXresult.txt")
file.copy("pxdxresult.txt","pxdxresult_copy.txt",overwrite=F)
file.rename("pxdxresult_copy.txt",op_pxdx_name)

#Create tar.gz file for splitter
system("tar -cvf opsplitter.tar *OPPXDXresult.txt")
system("gzip opsplitter.tar")

#Rename migrations file and add prefix
op_mig_name<-paste0(prefix,"opmigrations.txt")
file.copy("final_migrations.txt","final_migrations_copy.txt",overwrite=F)
file.rename("final_migrations_copy.txt",op_mig_name)

#Create tar.gz file for migrations
system("tar -cvf opmigrations.tar *opmigrations.txt")
system("gzip opmigrations.tar")

setwd("..")

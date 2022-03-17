[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 2

indir=/vol/cs/clientprojects/Tea_Leaves/2016_04_30_Tea_Leaves_Delivery/2016_04_30_Tea_Leaves_Emdeon_Delivery/AllCodes_PxDx/milestones
outdir=/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_05_02_All_Codes_SS_Sample/delivery_test
npi_list=/vol/cs/clientprojects/Tea_Leaves/TL_Emdeon_SalesSupport/2016_05_02_All_Codes_SS_Sample/Client_PIID_List/client_npis.tab
filter_column=1
all_codes=1 #expect allcodes style headers: 0=no,1=yes

Rscript --vanilla /vol/cs/CS_PayerProvider/Ryan/R/Tea_Leaves_SS_filter.R $indir $outdir $npi_list $filter_column $all_codes




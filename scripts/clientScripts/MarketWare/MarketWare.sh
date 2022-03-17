if [ ! -e HMS_Organizations_AllCodes.tab ];then
 abtab_join indivs_grp1_fordelivery.tab indivs_soab.tab --j1 HMS_PIID --j2 HMS_PIID --format 1:1-  --format 2:NPI_TAXONOMY_CODE > indivs_w_taxonomy.tab

 abtab_join indivs_w_taxonomy.tab addr_soab.tab --j1 HMS_PIID --j2 HMS_PIID --format 1:1-  --format 2:LATITUDE,LONGITUDE > HMS_Individuals_AllCodes.tab

 rm indivs_w_taxonomy.tab

 abtab_join orgs_grp1_fordelivery.tab organization.tab --j1 HMS_POID --j2 HMS_POID --format 1:1-  --format 2:LATITUDE,LONGITUDE > HMS_Organizations_AllCodes.tab

fi

mv affils_grp1_fordelivery.tab HMS_PxDx_AllCodes.tab
mv network.txt HMS_Network_AllCodes.tab

wc -l HMS_*

echo "copy line counts to T:\MarketWare\QA\nonPAC_QA.xlsx"

echo "please enter name of new deliverable, in this form: YYYY_MM_DD_ClientName"
read foldername

zip /vol/cs/clientprojects/MarketWare/$foldername/HMS_AllCodes.zip HMS_*





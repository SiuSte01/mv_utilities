[ $HOSTNAME != "plsas01.hmsonline.com" ] && echo "This script must be run from plsas01" && exit 1


new_date=2017_11_30


/vol/datadev/Statistics/Katie/Tea_Leaves/Ortho_INA_Filter/TL_ortho_INA_filter_v2.sh $new_date



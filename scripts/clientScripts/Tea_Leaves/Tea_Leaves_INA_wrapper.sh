#[ $HOSTNAME != "bctlpsas01.risk.regn.net" ] && echo "This script must be run from plsas01" && exit 1

#command -v Rscript >/dev/null 2>&1 || { echo >&2 "This script must be run from a system with R"; exit 1; }

[[ $HOSTNAME != *"sas"* ]] && [[ $HOSTNAME != *"plr"* ]] && echo "This script must be run from plsas01 or plr01" && exit 1

old_date=2018_12_31
new_date=2019_01_31 


/vol/cs/CS_PayerProvider/Ryan/utilities/Tea_Leaves/update_INAs_v2.sh $old_date $new_date



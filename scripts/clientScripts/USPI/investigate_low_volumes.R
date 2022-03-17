#this script is intended to help investigate the low volumes at certain centers identified by USPI. KE wrote the initial query.

library(ROracle)
drv <- dbDriver("Oracle")
con <- dbConnect(drv, username = "claims_usr",
password = "claims_usr123", dbname = "pldwh2dbr")

#query<-"select count(distinct prof.claim_id), pos.pos_type_code, pos.description, xwalk.id_value,ven.vendor_name
#from claimswh.prof_claim_procs prof
#inner join CLAIMSWH.PRACTITIONER_GROUP_MEMBERS pgm
#on  prof.claim_practitioner_group_id = pgm.practitioner_group_id
#inner join CLAIMSWH.PRACTITIONER_ID_CROSSWALK xwalk
#on pgm.practitioner_id = xwalk.practitioner_id
#inner join claimswh.vendors ven
#on prof.Vendor_Id = ven.vendor_id
#inner join claimswh.procedures proc
#on proc.procedure_id = prof.line_procedure_id
#inner join claimswh.plc_of_srvc_types pos
#on prof.line_pos_id = pos.pos_type_id
#where prof.claim_through_date between ven.first_vend_date and ven.last_vend_date
#and prof.load_batch <= ven.last_vend_batch
#and xwalk.id_value in ('PI0KXBK9C1',
#'PITF2775B5')
#group by xwalk.id_value,pos.pos_type_code, pos.description, ven.vendor_name"


query<-"select count(distinct prof.claim_id), pos.pos_type_code, pos.description, xwalk.id_value,ven.vendor_name
from claimswh.prof_claim_procs prof
inner join CLAIMSWH.PRACTITIONER_GROUP_MEMBERS pgm
on  prof.claim_practitioner_group_id = pgm.practitioner_group_id
inner join CLAIMSWH.PRACTITIONER_ID_CROSSWALK xwalk
on pgm.practitioner_id = xwalk.practitioner_id
inner join claimswh.vendors ven
on prof.Vendor_Id = ven.vendor_id
inner join claimswh.procedures proc
on proc.procedure_id = prof.line_procedure_id
inner join claimswh.plc_of_srvc_types pos
on prof.line_pos_id = pos.pos_type_id
where prof.claim_through_date between ven.first_vend_date and ven.last_vend_date
and prof.load_batch <= ven.last_vend_batch
and (to_date('20160309','YYYYMMDD') between xwalk.start_date and xwalk.end_date)
and xwalk.id_value in ('PI91KFTEA9','PIJ2NXREN1','PIDHUU2GC4','PI135VUMJ4','PIA31X5KH8','PIAF27A6M9','PIB1863XP5','PIR2VBDN59','PI1R46BC79','PI9KXV5V58','PI3JNMM0B3','PIRP3C6KR7','PIG2P4PKU7','PIDK14DH31','PIBPXPT1T8','PITF2775B5','PIE0Q1GTH3','PIC13TPFJ0','PIGPNBDRP4','PI7E020NF2','PIMRH4D6Q2','PIN7WPN0A3','PI0KXBK9C1','PITQNFBXK9','PIBK7QFKF2','PIX526VA41','PIX0NQWVT9','PIPAH333F0','PI69KJK3V1','PIRBE1Q532','PIHT3CHRJ6','PI7KGN94J7','PIE4QXTRG4','PI04FA9JC8','PIPDWV2WC0','PIUW4JPKR3','PI58VU40V0','PIUMVAHDU6','PIHFUMU5C8','PI4RXKQBW3','PIPANXE4W7','PI2FFD7AC2','PIU7U8TW72','PI6QPK0AP4','PI463K57W0','PIV2TP4KD6','PIEH8DVQK2','PI37E82NW9','PI1VR793T2','PIA7XFCTB3','PICC0N6DB2','PIQC6055B1','PIX62A0VM9','PI5764AGP4','PI31GC3C92')
group by xwalk.id_value,pos.pos_type_code, pos.description, ven.vendor_name
order by count (distinct prof.claim_id) desc"

rs <- dbSendQuery(con, query)
claims1500 <- fetch(rs)



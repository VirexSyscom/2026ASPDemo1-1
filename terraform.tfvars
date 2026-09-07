############################################
# 命名前綴
############################################

name_prefix    = "demo"
name_separator = "-"

############################################
# 基本設定
############################################

location       = "japaneast"
location_short = "jpe"

resource_group_name   = "spoke-network-rg"
create_resource_group = true

############################################
# 標籤
############################################

environment = "prod"
owner       = "network-team"
cost_center = "CC-1001"

# 額外自訂標籤，與系統共用標籤合併（同名時以此處為準）
tags = {
  Project        = "Spoke-Network"
  BusinessUnit   = "HR"
  DataClass      = "Confidential"
  Criticality    = "High"
  ReviewDate     = "2027-01-01"
}

############################################
# 網路位址
############################################

spoke_vnet_address_space     = ["10.10.0.0/16"]
uat_spoke_vnet_address_space = ["10.20.0.0/16"]

ap_subnet_prefix           = "10.10.1.0/24"
db_subnet_prefix           = "10.10.2.0/24"
pe_subnet_prefix           = "10.10.3.0/24"
bastion_subnet_prefix      = "10.10.250.0/26"
uat_workload_subnet_prefix = "10.20.1.0/24"

############################################
# 警示規則
############################################

# 若已有 Action Group，填入其資源 ID
alert_action_group_id = ""

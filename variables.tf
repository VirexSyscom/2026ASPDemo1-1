############################################
# 命名前綴
############################################

variable "name_prefix" {
  description = "所有資源名稱的前綴詞，例如 hr、corp、contoso。留空則不加前綴。"
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "name_prefix 僅能包含英數字與連字號。"
  }

  validation {
    condition     = length(var.name_prefix) <= 10
    error_message = "name_prefix 建議不超過 10 字元，避免資源名稱超出 Azure 長度限制。"
  }
}

variable "name_separator" {
  description = "前綴與資源名稱之間的分隔符號"
  type        = string
  default     = "-"
}

############################################
# 基本設定
############################################

variable "location" {
  description = "資源部署區域"
  type        = string
  default     = "japaneast"
}

variable "location_short" {
  description = "區域縮寫，用於資源命名（japaneast = jpe）"
  type        = string
  default     = "jpe"
}

variable "resource_group_name" {
  description = "既有或欲建立的資源群組名稱（此名稱不套用前綴，請填完整名稱）"
  type        = string
  default     = "spoke-network-rg"
}

variable "create_resource_group" {
  description = "true = 由本組態建立 RG；false = 沿用既有 RG"
  type        = bool
  default     = true
}

############################################
# 標籤
############################################

variable "environment" {
  description = "環境代號，會自動寫入 Environment 標籤"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "uat", "dev", "test"], var.environment)
    error_message = "environment 必須為 prod、uat、dev 或 test。"
  }
}

variable "owner" {
  description = "資源擁有者，會自動寫入 Owner 標籤"
  type        = string
  default     = "network-team"
}

variable "cost_center" {
  description = "成本中心代碼，會自動寫入 CostCenter 標籤"
  type        = string
  default     = ""
}

variable "tags" {
  description = "額外的自訂標籤，會與系統自動產生的共用標籤合併（同名時以此處為準）"
  type        = map(string)
  default     = {}
}

############################################
# 網路位址（圖片未顯示，請依實際環境調整）
############################################

variable "spoke_vnet_address_space" {
  type    = list(string)
  default = ["10.10.0.0/16"]
}

variable "uat_spoke_vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "ap_subnet_prefix" {
  type    = string
  default = "10.10.1.0/24"
}

variable "db_subnet_prefix" {
  type    = string
  default = "10.10.2.0/24"
}

variable "pe_subnet_prefix" {
  description = "Private Endpoint 專用子網路"
  type        = string
  default     = "10.10.3.0/24"
}

variable "bastion_subnet_prefix" {
  description = "AzureBastionSubnet 至少需 /26（僅在 create_bastion_subnet = true 時使用）"
  type        = string
  default     = "10.10.250.0/26"
}

############################################
# Bastion
############################################
variable "bastion_sku" {
  description = "Bastion SKU。Developer 免公用 IP、免 AzureBastionSubnet，但不支援 VNet peering 與並行連線"
  type        = string
  default     = "Developer"

  validation {
    condition     = contains(["Developer", "Basic", "Standard", "Premium"], var.bastion_sku)
    error_message = "bastion_sku 必須為 Developer、Basic、Standard 或 Premium。"
  }
}

variable "create_bastion_subnet" {
  description = "是否建立 AzureBastionSubnet。Developer SKU 不需要，設為 false 可省去該子網路"
  type        = bool
  default     = false

  validation {
    condition     = !(var.bastion_sku != "Developer" && var.create_bastion_subnet == false)
    error_message = "Basic/Standard/Premium SKU 必須建立 AzureBastionSubnet，請將 create_bastion_subnet 設為 true。"
  }
}

variable "uat_workload_subnet_prefix" {
  type    = string
  default = "10.20.1.0/24"
}

############################################
# 警示規則
############################################

variable "alert_action_group_id" {
  description = "活動記錄警示要通知的 Action Group 資源 ID；留空則只記錄不通知"
  type        = string
  default     = ""
}

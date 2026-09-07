############################################
# 命名與標籤的共用邏輯
############################################

data "azurerm_client_config" "current" {}

locals {
  # 前綴：留空時不加分隔符號，例如 name_prefix = "hr" -> "hr-"
  prefix = var.name_prefix == "" ? "" : "${var.name_prefix}${var.name_separator}"

  # 統一命名函式（以 local 表達式模擬）
  name = {
    spoke_vnet     = "${local.prefix}Spoke-VNET"
    uat_spoke_vnet = "${local.prefix}UAT-Spoke-VNET"
    ap_nsg         = "${local.prefix}AP-Subnet-NSG"
    db_nsg         = "${local.prefix}DB-Subnet-NSG"
    nat_pip        = "${local.prefix}nat-pip"
    nat_gateway    = "${local.prefix}SpokeHRNatGW"
    bastion        = "${local.prefix}Spoke-VNET-bastion"
    bastion_pip    = "${local.prefix}Spoke-VNET-bastion-pip"
    alert_nsg_write = "${local.prefix}Create or Update Network Security Group Alert"
    alert_nsg_delete = "${local.prefix}Delete Network Security Group Alert"

    # 子網路（AzureBastionSubnet 為 Azure 保留名稱，不可加前綴）
    ap_subnet      = "${local.prefix}AP-Subnet"
    db_subnet      = "${local.prefix}DB-Subnet"
    pe_subnet      = "${local.prefix}PrivateEndpoint-Subnet"
    uat_subnet     = "${local.prefix}Workload-Subnet"
    bastion_subnet = "AzureBastionSubnet"
  }

  # 所有資源共用的基準標籤
  common_tags = merge(
    {
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "Terraform"
      Location    = var.location
      Prefix      = var.name_prefix
    },
    var.cost_center == "" ? {} : { CostCenter = var.cost_center },
    var.tags
  )

  # UAT 資源改寫 Environment
  uat_tags = merge(local.common_tags, { Environment = "uat" })

  rg_name         = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  rg_location     = var.create_resource_group ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
  subscription_id = data.azurerm_client_config.current.subscription_id
  alert_scope     = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}

############################################
# Resource Group
############################################

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "this" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    ResourceType = "ResourceGroup"
  })
}

############################################
# Virtual Network - Spoke-VNET（正式環境）
############################################

resource "azurerm_virtual_network" "spoke" {
  name                = local.name.spoke_vnet
  location            = local.rg_location
  resource_group_name = local.rg_name
  address_space       = var.spoke_vnet_address_space

  tags = merge(local.common_tags, {
    ResourceType = "VirtualNetwork"
    Tier         = "Spoke"
    Workload     = "Production"
  })
}

resource "azurerm_subnet" "ap" {
  name                 = local.name.ap_subnet
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.ap_subnet_prefix]
}

resource "azurerm_subnet" "db" {
  name                 = local.name.db_subnet
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.db_subnet_prefix]
}

resource "azurerm_subnet" "pe" {
  name                 = local.name.pe_subnet
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.pe_subnet_prefix]

  private_endpoint_network_policies = "Disabled"
}

# Bastion 專用子網路，名稱為 Azure 保留字，不可加前綴
resource "azurerm_subnet" "bastion" {
  name                 = local.name.bastion_subnet
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

############################################
# Virtual Network - UAT-Spoke-VNET（測試環境）
############################################

resource "azurerm_virtual_network" "uat_spoke" {
  name                = local.name.uat_spoke_vnet
  location            = local.rg_location
  resource_group_name = local.rg_name
  address_space       = var.uat_spoke_vnet_address_space

  tags = merge(local.uat_tags, {
    ResourceType = "VirtualNetwork"
    Tier         = "Spoke"
    Workload     = "UAT"
  })
}

resource "azurerm_subnet" "uat_workload" {
  name                 = local.name.uat_subnet
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.uat_spoke.name
  address_prefixes     = [var.uat_workload_subnet_prefix]
}

############################################
# Network Security Group - AP-Subnet-NSG
############################################

resource "azurerm_network_security_group" "ap" {
  name                = local.name.ap_nsg
  location            = local.rg_location
  resource_group_name = local.rg_name

  tags = merge(local.common_tags, {
    ResourceType = "NetworkSecurityGroup"
    Tier         = "Application"
  })

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

############################################
# Network Security Group - DB-Subnet-NSG
############################################

resource "azurerm_network_security_group" "db" {
  name                = local.name.db_nsg
  location            = local.rg_location
  resource_group_name = local.rg_name

  tags = merge(local.common_tags, {
    ResourceType = "NetworkSecurityGroup"
    Tier         = "Database"
  })

  # 僅允許 AP Subnet 連 SQL
  security_rule {
    name                       = "Allow-SQL-From-AP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.ap_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "ap" {
  subnet_id                 = azurerm_subnet.ap.id
  network_security_group_id = azurerm_network_security_group.ap.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

############################################
# NAT Gateway - nat-pip / SpokeHRNatGW
############################################

resource "azurerm_public_ip" "nat" {
  name                = local.name.nat_pip
  location            = local.rg_location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = merge(local.common_tags, {
    ResourceType = "PublicIP"
    Purpose      = "NAT-Egress"
  })
}

resource "azurerm_nat_gateway" "spoke" {
  name                    = local.name.nat_gateway
  location                = local.rg_location
  resource_group_name     = local.rg_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4

  tags = merge(local.common_tags, {
    ResourceType = "NatGateway"
    Purpose      = "Outbound-Connectivity"
  })
}

resource "azurerm_nat_gateway_public_ip_association" "spoke" {
  nat_gateway_id       = azurerm_nat_gateway.spoke.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "ap" {
  subnet_id      = azurerm_subnet.ap.id
  nat_gateway_id = azurerm_nat_gateway.spoke.id
}

resource "azurerm_subnet_nat_gateway_association" "db" {
  subnet_id      = azurerm_subnet.db.id
  nat_gateway_id = azurerm_nat_gateway.spoke.id
}

############################################
# Bastion - Spoke-VNET-bastion
############################################

resource "azurerm_public_ip" "bastion" {
  name                = local.name.bastion_pip
  location            = local.rg_location
  resource_group_name = local.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.common_tags, {
    ResourceType = "PublicIP"
    Purpose      = "Bastion"
  })
}

resource "azurerm_bastion_host" "spoke" {
  name                = local.name.bastion
  location            = local.rg_location
  resource_group_name = local.rg_name
  sku                 = "Standard"

  tags = merge(local.common_tags, {
    ResourceType = "Bastion"
    Purpose      = "SecureRemoteAccess"
  })

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

############################################
# Private DNS Zone
# 名稱由 Azure Private Link 規範固定，絕對不可加前綴
############################################

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = local.rg_name

  tags = merge(local.common_tags, {
    ResourceType = "PrivateDnsZone"
    Service      = "Storage-Blob"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_spoke" {
  name                  = "${local.prefix}link-spoke-vnet"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false

  tags = merge(local.common_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_uat" {
  name                  = "${local.prefix}link-uat-spoke-vnet"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.uat_spoke.id
  registration_enabled  = false

  tags = merge(local.uat_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = local.rg_name

  tags = merge(local.common_tags, {
    ResourceType = "PrivateDnsZone"
    Service      = "Azure-SQL"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_spoke" {
  name                  = "${local.prefix}link-spoke-vnet"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false

  tags = merge(local.common_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_uat" {
  name                  = "${local.prefix}link-uat-spoke-vnet"
  resource_group_name   = local.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.uat_spoke.id
  registration_enabled  = false

  tags = merge(local.uat_tags, {
    ResourceType = "PrivateDnsZoneLink"
  })
}

############################################
# Activity Log Alert（location 固定為 global）
############################################

resource "azurerm_monitor_activity_log_alert" "nsg_write" {
  name                = local.name.alert_nsg_write
  resource_group_name = local.rg_name
  location            = "global"
  scopes              = [local.alert_scope]
  description         = "當 NSG 被建立或更新時觸發"
  enabled             = true

  tags = merge(local.common_tags, {
    ResourceType = "ActivityLogAlert"
    Purpose      = "Security-Monitoring"
  })

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/networkSecurityGroups/write"
    level          = "Informational"
  }

  dynamic "action" {
    for_each = var.alert_action_group_id == "" ? [] : [1]
    content {
      action_group_id = var.alert_action_group_id
    }
  }
}

resource "azurerm_monitor_activity_log_alert" "nsg_delete" {
  name                = local.name.alert_nsg_delete
  resource_group_name = local.rg_name
  location            = "global"
  scopes              = [local.alert_scope]
  description         = "當 NSG 被刪除時觸發"
  enabled             = true

  tags = merge(local.common_tags, {
    ResourceType = "ActivityLogAlert"
    Purpose      = "Security-Monitoring"
  })

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Network/networkSecurityGroups/delete"
    level          = "Informational"
  }

  dynamic "action" {
    for_each = var.alert_action_group_id == "" ? [] : [1]
    content {
      action_group_id = var.alert_action_group_id
    }
  }
}

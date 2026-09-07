output "name_prefix_applied" {
  description = "實際套用的前綴字串"
  value       = local.prefix
}

output "resource_names" {
  description = "所有資源的最終名稱，可用於驗證前綴是否正確套用"
  value       = local.name
}

output "common_tags" {
  description = "套用到所有資源的共用標籤"
  value       = local.common_tags
}

output "resource_group_name" {
  value = local.rg_name
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "uat_spoke_vnet_id" {
  value = azurerm_virtual_network.uat_spoke.id
}

output "subnet_ids" {
  value = {
    ap      = azurerm_subnet.ap.id
    db      = azurerm_subnet.db.id
    pe      = azurerm_subnet.pe.id
    bastion = azurerm_subnet.bastion.id
    uat     = azurerm_subnet.uat_workload.id
  }
}

output "nat_gateway_public_ip" {
  value = azurerm_public_ip.nat.ip_address
}

output "private_dns_zone_ids" {
  value = {
    blob = azurerm_private_dns_zone.blob.id
    sql  = azurerm_private_dns_zone.sql.id
  }
}

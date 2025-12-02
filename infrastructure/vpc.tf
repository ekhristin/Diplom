resource "yandex_vpc_network" "diplom" {
  name = var.vpc_name

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
    },
    var.additional_labels
  )
}

resource "yandex_vpc_gateway" "internet" {
  name = "${replace(var.vpc_name, "_", "-")}-gateway"

  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "internet" {
  name       = "${var.vpc_name}-rt"
  network_id = yandex_vpc_network.diplom.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.internet.id
  }

  depends_on = [yandex_vpc_gateway.internet]
}

resource "yandex_vpc_subnet" "private" {
  for_each       = var.subnet_cidrs
  name           = "${var.vpc_name}-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.diplom.id
  v4_cidr_blocks = [each.value]
  route_table_id = yandex_vpc_route_table.internet.id

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
      zone        = each.key
    },
    var.additional_labels
  )
}

output "network_id" {
  description = "ID созданной VPC сети"
  value       = yandex_vpc_network.diplom.id
}

output "subnet_ids" {
  description = "Идентификаторы подсетей по зонам"
  value       = { for zone, subnet in yandex_vpc_subnet.private : zone => subnet.id }
}

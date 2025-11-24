resource "yandex_container_registry" "registry" {
  name      = var.registry_name
  folder_id = var.folder_id

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
    },
    var.additional_labels
  )
}

# Выводы
output "registry_id" {
  description = "ID созданного Container Registry"
  value       = yandex_container_registry.registry.id
}

output "registry_name" {
  description = "Имя созданного Container Registry"
  value       = yandex_container_registry.registry.name
}



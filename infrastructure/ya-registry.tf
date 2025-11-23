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



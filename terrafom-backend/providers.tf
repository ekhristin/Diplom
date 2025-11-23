provider "yandex" {
  service_account_key_file = file("~/.authorized_key.json")
  folder_id                = var.folder_id
  zone                     = var.zone
  
  # cloud_id опционален - если не указан, будет использован каталог
  # Раскомментируйте следующую строку, если нужно указать cloud_id
  # cloud_id = var.cloud_id
}

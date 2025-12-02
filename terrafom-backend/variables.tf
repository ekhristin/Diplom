variable "bucket_name" {
  description = "Имя бакета Object Storage для хранения Terraform state файлов (должно быть уникальным)"
  type        = string
}

variable "service_account_name" {
  description = "Имя сервисного аккаунта для работы с Object Storage"
  type        = string
  default     = "terraform-state-sa"
}

variable "environment" {
  description = "Окружение (например, dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Название проекта"
  type        = string
  default     = "diplom"
}

variable "state_retention_days" {
  description = "Количество дней хранения старых версий state файлов"
  type        = number
  default     = 90
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud"
  type        = string
}

variable "cloud_id" {
  description = "ID облака Yandex Cloud (опционально, если не указан, будет использован каталог)"
  type        = string
  default     = ""
}

variable "zone" {
  description = "Зона доступности Yandex Cloud"
  type        = string
  default     = "ru-central1-a"
}

variable "endpoint" {
  description = "Endpoint для Object Storage"
  type        = string
  default     = "storage.yandexcloud.net"
}

variable "skip_region_validation" {
  description = "Пропустить валидацию региона (необходимо для Yandex Cloud)"
  type        = bool
  default     = true
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95"
    }
  }
}

provider "yandex" {
  # Поддержка аутентификации:
  # 1. Через переменную окружения YC_SERVICE_ACCOUNT_KEY_FILE (для CI/CD) - автоматически используется провайдером
  # 2. Через переменную service_account_key_file (путь к файлу для локальной разработки)
  # Если service_account_key_file указан, используется он; иначе используется переменная окружения
  service_account_key_file = var.service_account_key_file != "" ? pathexpand(var.service_account_key_file) : null
  folder_id                = var.folder_id
  cloud_id                 = var.cloud_id == "" ? null : var.cloud_id
}


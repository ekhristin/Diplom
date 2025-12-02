terraform {
  required_version = ">= 1.0"
  
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.95"
    }
  }
}

# Сервисный аккаунт для работы с Object Storage
resource "yandex_iam_service_account" "terraform_state_sa" {
  name        = var.service_account_name
  description = "Service account for Terraform state storage in Object Storage"
  folder_id   = var.folder_id
}

# Назначение роли storage.editor сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "storage_editor" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_state_sa.id}"
}

# Назначение роли editor сервисному аккаунту (для работы с ресурсами)
resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.terraform_state_sa.id}"
}

# Static Access Key для Object Storage
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.terraform_state_sa.id
  description        = "Static access key for Object Storage"
}

# IAM ключ сервисного аккаунта для доступа к Yandex Cloud API
resource "yandex_iam_service_account_key" "sa_key" {
  service_account_id = yandex_iam_service_account.terraform_state_sa.id
  description        = "IAM key for Yandex Cloud API access"
  key_algorithm      = "RSA_2048"
}

# Бакет Object Storage для хранения Terraform state файлов
# Примечание: для создания бакета используем аутентификацию через провайдер Yandex Cloud
# (файл ~/.authorized_key.json), а не через Static Access Keys
# Static Access Keys будут использоваться только для доступа к бакету из Terraform backend
resource "yandex_storage_bucket" "terraform_state" {
  bucket = var.bucket_name
  
  # НЕ используем access_key и secret_key здесь, чтобы избежать проблем с правами доступа
  # Бакет создается с правами сервисного аккаунта из ~/.authorized_key.json
  # Static Access Keys будут использоваться только в backend конфигурации Terraform

  # Версионирование включено
  versioning {
    enabled = true
  }

  # Примечание: Yandex Cloud Object Storage автоматически шифрует данные на стороне сервера
  # Явная настройка шифрования не требуется и может вызывать ошибки из-за требований KMS ключа

  # Политика жизненного цикла для удаления старых версий
  lifecycle_rule {
    id      = "delete-old-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.state_retention_days
    }
  }

  # Зависимость от назначения ролей
  # Важно: роли должны быть назначены до создания бакета
  depends_on = [
    yandex_resourcemanager_folder_iam_member.storage_editor,
    yandex_resourcemanager_folder_iam_member.editor
  ]

  # Теги для удобства управления
  tags = {
    Name        = "Terraform State Bucket"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Примечание: YDB не поддерживает DynamoDB API напрямую для блокировки state
# Terraform backend для Yandex Cloud использует только Object Storage
# Версионирование обеспечивает защиту от потери данных
# Для командной работы рекомендуется использовать механизмы координации на уровне CI/CD

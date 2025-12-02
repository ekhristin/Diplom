output "service_account_id" {
  description = "ID созданного сервисного аккаунта"
  value       = yandex_iam_service_account.terraform_state_sa.id
}

output "service_account_name" {
  description = "Имя созданного сервисного аккаунта"
  value       = yandex_iam_service_account.terraform_state_sa.name
}

output "access_key_id" {
  description = "Access Key ID для Object Storage"
  value       = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret Access Key для Object Storage"
  value       = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  sensitive   = true
}

output "bucket_name" {
  description = "Имя созданного бакета Object Storage"
  value       = yandex_storage_bucket.terraform_state.bucket
}

output "bucket_domain_name" {
  description = "Доменное имя бакета"
  value       = yandex_storage_bucket.terraform_state.bucket_domain_name
}

output "backend_config" {
  description = "Конфигурация backend для Terraform (S3-совместимый)"
  value = {
    bucket                      = yandex_storage_bucket.terraform_state.bucket
    key                         = "terraform.tfstate"
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    access_key                  = yandex_iam_service_account_static_access_key.sa_static_key.access_key
    secret_key                  = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  }
  sensitive = true
}

output "backend_config_simple" {
  description = "Упрощенная конфигурация backend для использования в terraform.tf (без секретов)"
  value = {
    bucket                      = yandex_storage_bucket.terraform_state.bucket
    key                         = "terraform.tfstate"
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

output "service_account_key_json" {
  description = "JSON ключ сервисного аккаунта для доступа к Yandex Cloud API"
  value       = yandex_iam_service_account_key.sa_key.private_key
  sensitive   = true
}

output "credentials_file" {
  description = "Путь к файлу с учетными данными (будет создан скриптом)"
  value       = "${path.root}/credentials.env"
}

output "instructions" {
  description = "Инструкции по настройке backend"
  value = <<-EOT
    Для использования этого backend в вашем Terraform проекте:
    
    1. Используйте созданные учетные данные из credentials.env:
    source credentials.env
    
    2. Добавьте в ваш terraform.tf или backend.tf:
    
    terraform {
      backend "s3" {
        bucket                      = "${yandex_storage_bucket.terraform_state.bucket}"
        key                         = "terraform.tfstate"
        endpoint                    = "https://storage.yandexcloud.net"
        region                      = "ru-central1"
        skip_region_validation      = true
        skip_credentials_validation = true
      }
    }
    
    3. Выполните: terraform init -migrate-state
  EOT
}

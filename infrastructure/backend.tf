terraform {
  backend "s3" {
    bucket                      = "diplom-kh-20251109-204448"
    key                         = "terraform.tfstate"
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    
    # Учетные данные загружаются из переменных окружения:
    # export AWS_ACCESS_KEY_ID="..."
    # export AWS_SECRET_ACCESS_KEY="..."
    # Или через параметры командной строки: -backend-config="access_key=..." -backend-config="secret_key=..."
  }
}

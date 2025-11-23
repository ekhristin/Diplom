# Terraform Backend для State файлов в Yandex Cloud

Этот модуль создает Object Storage бакет в Yandex Cloud для хранения Terraform state файлов.

## Компоненты

- **Сервисный аккаунт**: Автоматически создается для работы с Object Storage
  - Назначаются роли: `storage.editor` и `editor`
  
- **Static Access Keys**: Автоматически создаются для доступа к Object Storage
  
- **Object Storage Bucket**: Хранилище для Terraform state файлов
  - Версионирование включено
  - Шифрование на стороне сервера (автоматическое, встроенное в Yandex Cloud Object Storage)
  - Политика жизненного цикла для удаления старых версий (90 дней по умолчанию)

## Предварительные требования

1. **Yandex Cloud аккаунт** с созданным каталогом (folder)
2. **Terraform** установлен (>= 1.0)
3. **Файл ключа сервисного аккаунта** (`~/.authorized_key.json`) для аутентификации провайдера
   - Сервисный аккаунт должен иметь права на создание других сервисных аккаунтов и назначение ролей
   - Обычно требуется роль `admin` или `editor` на уровне каталога

## Получение учетных данных для провайдера

Для работы Terraform провайдера необходим файл ключа сервисного аккаунта с правами на создание ресурсов.

### 1. Создание сервисного аккаунта для провайдера

```bash
# Установите Yandex Cloud CLI (если еще не установлен)
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

# Авторизуйтесь
yc init

# Создайте сервисный аккаунт для провайдера (должен иметь права admin или editor)
yc iam service-account create --name terraform-provider-sa

# Сохраните ID созданного аккаунта
PROVIDER_SA_ID=$(yc iam service-account get terraform-provider-sa --format json | jq -r '.id')

# Назначьте роль admin или editor на каталог
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role admin \
  --subject serviceAccount:$PROVIDER_SA_ID

# Создайте ключ сервисного аккаунта и сохраните в ~/.authorized_key.json
yc iam key create --service-account-name terraform-provider-sa --output ~/.authorized_key.json

# Установите безопасные права доступа
chmod 600 ~/.authorized_key.json
```

**Примечание**: Сервисный аккаунт для хранения state будет создан автоматически через Terraform. Вам не нужно создавать его вручную.

### 2. Получение ID каталога и облака

```bash
# Список каталогов
yc resource-manager folder list

# Список облаков
yc resource-manager cloud list
```

## Настройка

1. Скопируйте файл с переменными:
   ```bash
   cd terrafom-backend
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Убедитесь, что файл ключа сервисного аккаунта находится в `~/.authorized_key.json`

3. Отредактируйте `terraform.tfvars` и укажите:
   - `bucket_name` - уникальное имя для бакета Object Storage
   - `folder_id` - ID каталога Yandex Cloud
   - `service_account_name` - имя сервисного аккаунта (по умолчанию: `terraform-state-sa`)
   - `cloud_id` - ID облака (опционально)
   - Другие параметры при необходимости

**Внимание**: 
- Файл `terraform.tfvars` содержит чувствительные данные и не должен коммититься в репозиторий!
- Файл `~/.authorized_key.json` также содержит чувствительные данные и должен быть защищен
- Сервисный аккаунт и Static Keys для Object Storage создаются автоматически через Terraform
- Учетные данные сохраняются в файл `credentials.env` после развертывания

## Развертывание

Используйте интерактивный скрипт управления из корневой директории проекта:

```bash
./manage-backend.sh
```

Скрипт предоставляет интерактивное меню для:
1. **Создания S3 бакета и настройки backend** - автоматически создает:
   - Сервисный аккаунт
   - Static Access Keys
   - S3 бакет с настройками безопасности
   - Назначает необходимые роли
   - Создает файл конфигурации backend
   - Сохраняет учетные данные в `credentials.env`

2. **Удаления всех созданных ресурсов** - полностью удаляет:
   - S3 бакет со всеми данными
   - Сервисный аккаунт
   - Static Access Keys
   - Назначенные роли

3. **Просмотра текущей конфигурации**

## Ручное развертывание

Если вы предпочитаете развернуть вручную:

```bash
cd terrafom-backend
terraform init
terraform plan
terraform apply
```

После развертывания используйте выходные значения для настройки backend в ваших других Terraform конфигурациях.

## Переменные

| Переменная | Описание | Тип | Обязательно |
|------------|----------|-----|-------------|
| `bucket_name` | Имя бакета Object Storage | string | Да |
| `service_account_name` | Имя сервисного аккаунта | string | Нет (по умолчанию: `terraform-state-sa`) |
| `folder_id` | ID каталога Yandex Cloud | string | Да |
| `cloud_id` | ID облака Yandex Cloud | string | Нет |
| `environment` | Окружение | string | Нет (по умолчанию: `dev`) |
| `project_name` | Название проекта | string | Нет (по умолчанию: `diplom`) |
| `state_retention_days` | Дни хранения старых версий | number | Нет (по умолчанию: `90`) |
| `zone` | Зона доступности | string | Нет (по умолчанию: `ru-central1-a`) |

**Примечания**: 
- Для аутентификации провайдера используется файл ключа сервисного аккаунта `~/.authorized_key.json`. Этот файл должен существовать и содержать валидный ключ сервисного аккаунта с правами на создание ресурсов.
- Сервисный аккаунт и Static Keys для Object Storage создаются автоматически через Terraform.
- Учетные данные (access_key_id и secret_access_key) доступны через выходные значения Terraform и сохраняются в `credentials.env`.

## Выходные значения

После развертывания доступны следующие выходные значения:

- `bucket_name` - Имя созданного бакета Object Storage
- `bucket_domain_name` - Доменное имя бакета
- `backend_config` - Полная конфигурация backend для использования в других модулях
- `backend_config_simple` - Упрощенная конфигурация backend
- `instructions` - Инструкции по настройке backend

## Использование в других Terraform проектах

После развертывания добавьте в ваш основной Terraform файл:

```hcl
terraform {
  backend "s3" {
    bucket                      = "<bucket_name>"
    key                         = "terraform.tfstate"
    endpoint                    = "https://storage.yandexcloud.net"
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    access_key                  = "<access_key_id>"
    secret_key                  = "<secret_access_key>"
  }
}
```

Или используйте переменные окружения:

```bash
export AWS_ACCESS_KEY_ID="<access_key_id>"
export AWS_SECRET_ACCESS_KEY="<secret_access_key>"
```

Затем выполните миграцию state:

```bash
terraform init -migrate-state
```

## Особенности Yandex Cloud

- Yandex Object Storage совместим с S3 API, поэтому Terraform может использовать стандартный S3 backend
- Блокировка state через DynamoDB не поддерживается в Yandex Cloud напрямую
- Версионирование Object Storage обеспечивает защиту от потери данных
- Рекомендуется использовать версионирование и регулярные бэкапы

## Безопасность

- State файлы хранятся в зашифрованном виде (AES256)
- Используйте сервисные аккаунты для аутентификации
- Ограничьте права доступа сервисного аккаунта только необходимыми ролями
- Не коммитьте файлы `terraform.tfvars` с реальными учетными данными
- Защитите файл `~/.authorized_key.json` (установите права доступа: `chmod 600 ~/.authorized_key.json`)
- Не коммитьте файл ключа сервисного аккаунта в репозиторий
- Используйте переменные окружения или секреты для хранения Static Keys

## Удаление ресурсов

Для удаления всех созданных ресурсов:

```bash
cd terrafom-backend
terraform destroy
```

**⚠️ Внимание**: Убедитесь, что state файлы сохранены перед удалением бакета!

## Troubleshooting

### Ошибка: "access denied"
- Проверьте права сервисного аккаунта
- Убедитесь, что у аккаунта есть роль `storage.editor` или `storage.admin`

### Ошибка: "bucket already exists"
- Имя бакета должно быть глобально уникальным в Yandex Cloud
- Выберите другое имя для бакета

### Ошибка при инициализации backend
- Проверьте правильность учетных данных (access_key_id и secret_access_key)
- Убедитесь, что endpoint указан правильно: `https://storage.yandexcloud.net`
- Проверьте, что `skip_region_validation = true`

## Дополнительные ресурсы

- [Документация Yandex Object Storage](https://cloud.yandex.ru/docs/storage/)
- [Terraform Provider для Yandex Cloud](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs)
- [Документация Terraform Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)

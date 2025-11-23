# Инструкция по настройке

## Шаг 1: Установка Yandex Cloud CLI

```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
source ~/.bashrc  # или перезапустите терминал
```

## Шаг 2: Инициализация Yandex Cloud CLI

```bash
yc init
```

Следуйте инструкциям на экране. Вам потребуется:
- Выбрать облако
- Выбрать каталог
- Указать зону по умолчанию

## Шаг 3: Получение ID каталога и облака

```bash
# Получить ID каталога
yc resource-manager folder list

# Получить ID облака
yc resource-manager cloud list
```

Сохраните эти значения - они понадобятся для `terraform.tfvars`.

## Шаг 4: Создание сервисного аккаунта и ключа

### Создание сервисного аккаунта

```bash
# Создать сервисный аккаунт
yc iam service-account create --name terraform-state-sa

# Сохраните ID созданного аккаунта
SERVICE_ACCOUNT_ID=$(yc iam service-account get terraform-state-sa --format json | jq -r '.id')
echo "Service Account ID: $SERVICE_ACCOUNT_ID"
```

### Создание ключа сервисного аккаунта

```bash
# Создать ключ сервисного аккаунта и сохранить в ~/.authorized_key.json
yc iam key create --service-account-name terraform-state-sa --output ~/.authorized_key.json

# Установить безопасные права доступа на файл ключа
chmod 600 ~/.authorized_key.json
```

**Внимание**: Файл `~/.authorized_key.json` содержит чувствительные данные и должен быть защищен!

### Назначение ролей

```bash
# Назначить роль storage.editor (замените <FOLDER_ID> и <SERVICE_ACCOUNT_ID>)
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role storage.editor \
  --subject serviceAccount:<SERVICE_ACCOUNT_ID>

# Назначить роль editor для работы с ресурсами (опционально)
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role editor \
  --subject serviceAccount:<SERVICE_ACCOUNT_ID>
```

Где:
- `<FOLDER_ID>` - ID вашего каталога
- `<SERVICE_ACCOUNT_ID>` - ID созданного сервисного аккаунта

### Создание Static Access Keys для Object Storage

```bash
# Создать Static Keys для Object Storage
yc iam access-key create --service-account-name terraform-state-sa
```

Сохраните `key_id` и `secret` - они понадобятся для `terraform.tfvars`.

**Внимание**: `secret` показывается только один раз при создании! Сохраните его в безопасном месте.

## Шаг 6: Настройка terraform.tfvars

### Автоматическая настройка (рекомендуется)

Файл `terraform.tfvars` будет автоматически создан при создании S3 бакета (опция 1 в меню `manage-backend.sh`). 

Скрипт автоматически:
- Получит `folder_id` из `yc config get folder-id`
- Получит `cloud_id` из `yc config get cloud-id` (если доступен)
- Получит `zone` из `yc config get compute-default-zone`
- Запросит у вас только имя бакета и другие параметры

Просто запустите:
```bash
./manage-backend.sh
# Выберите опцию 1: Создать S3 бакет и настроить backend
# Если файл terraform.tfvars отсутствует, он будет создан автоматически
```

### Ручная настройка (альтернатива)

Если вы предпочитаете создать `terraform.tfvars` вручную перед созданием backend:

```bash
cd terrafom-backend
cp terraform.tfvars.example terraform.tfvars
```

Получите значения из конфигурации yc:
```bash
yc config get folder-id      # ID каталога
yc config get cloud-id       # ID облака (опционально)
yc config get compute-default-zone  # Зона
```

Отредактируйте `terraform.tfvars` и заполните все необходимые поля:

```hcl
bucket_name          = "my-unique-terraform-state-bucket"  # Должно быть уникальным
folder_id            = "b1gxxxxxxxxxxxxxxxx"                # ID вашего каталога
cloud_id             = "b1gxxxxxxxxxxxxxxxx"                # ID вашего облака (опционально)
zone                 = "ru-central1-a"                      # Зона
environment          = "dev"
project_name         = "diplom"
state_retention_days = 90
```

**Внимание**: 
- Убедитесь, что файл `~/.authorized_key.json` существует и содержит валидный ключ сервисного аккаунта!
- Сервисный аккаунт и Static Keys для Object Storage создаются автоматически через Terraform

## Шаг 7: Развертывание

```bash
# Вернуться в корневую директорию
cd ..

# Запустить интерактивный скрипт управления
./manage-backend.sh
```

Скрипт выполнит все необходимые операции и создаст файл конфигурации backend.

## Шаг 8: Использование backend

После успешного развертывания:

```bash
# вариант через меню
./manage-backend.sh  # выберите пункт 4 (Инициализировать backend)

# или вручную:
cd infrastructure
terraform init -backend-config=backend-secrets.tfvars -migrate-state
```

При запросе подтверждения миграции введите `yes`. Для удаления файлов `.terraform` и локального state используйте пункт 5 (Деинициализировать backend) в меню `manage-backend.sh`.

Для проверки конфигурации (создание ресурсов с последующим удалением; используйте осторожно) запустите пункт 6 меню (`Протестировать инфраструктуру`) или выполните вручную:

```bash
cd infrastructure
terraform validate
terraform plan -backend-config=backend-secrets.tfvars
terraform apply -backend-config=backend-secrets.tfvars -auto-approve
terraform destroy -backend-config=backend-secrets.tfvars -auto-approve
```

## Альтернативный способ: использование переменных окружения

Вместо указания Static Keys в `terraform.tfvars`, можно использовать переменные окружения:

```bash
export AWS_ACCESS_KEY_ID="YCA..."
export AWS_SECRET_ACCESS_KEY="YCM..."
```

**Примечание**: Файл ключа сервисного аккаунта `~/.authorized_key.json` все равно необходим для аутентификации провайдера Terraform.

## Troubleshooting

### Ошибка: "access denied"
- Проверьте, что сервисный аккаунт имеет роль `storage.editor`
- Убедитесь, что указан правильный `folder_id`

### Ошибка: "bucket already exists"
- Имя бакета должно быть глобально уникальным в Yandex Cloud
- Попробуйте добавить уникальный суффикс (например, UUID)

### Ошибка: "cannot read file ~/.authorized_key.json"
- Убедитесь, что файл `~/.authorized_key.json` существует
- Проверьте права доступа к файлу: `ls -la ~/.authorized_key.json`
- Установите права доступа: `chmod 600 ~/.authorized_key.json`
- Проверьте, что файл содержит валидный JSON с ключом сервисного аккаунта

## Безопасность

- ✅ Не коммитьте файл `terraform.tfvars` с реальными учетными данными
- ✅ Не коммитьте файл `~/.authorized_key.json` в репозиторий
- ✅ Защитите файл ключа: `chmod 600 ~/.authorized_key.json`
- ✅ Используйте сервисные аккаунты для аутентификации
- ✅ Ограничьте права доступа только необходимыми ролями
- ✅ Храните секреты в безопасном месте (например, в секретных менеджерах)
- ✅ Регулярно ротируйте ключи доступа


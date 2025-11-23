# Дипломный проект - Terraform Backend в Yandex Cloud

Проект для настройки удаленного хранилища Terraform state файлов в Yandex Cloud Object Storage.

## Структура проекта

```
.
├── terrafom-backend/          # Terraform модуль для создания backend
│   ├── main.tf                # Основной манифест
│   ├── variables.tf           # Переменные
│   ├── outputs.tf             # Выходные значения
│   ├── providers.tf           # Конфигурация провайдера
│   ├── terraform.tfvars.example  # Пример переменных
│   └── README.md              # Документация модуля
├── infrastructure/            # Основная инфраструктура (будет использовать backend)
│   └── backend.tf.example     # Пример конфигурации backend
├── manage-backend.sh          # Интерактивный скрипт управления backend (включает настройку terraform.tfvars)
└── README.md                  # Этот файл
```

## Быстрый старт

### 1. Предварительные требования

- **Yandex Cloud аккаунт** с созданным каталогом
- **Terraform** >= 1.0
- **Сервисный аккаунт** с правами `storage.editor`
- **Static Access Keys** для Object Storage

### 2. Получение учетных данных

#### Создание сервисного аккаунта и ключа:

```bash
# Установите Yandex Cloud CLI (если еще не установлен)
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
yc init

# Создайте сервисный аккаунт
yc iam service-account create --name terraform-state-sa

# Сохраните ID созданного аккаунта
SERVICE_ACCOUNT_ID=$(yc iam service-account get terraform-state-sa --format json | jq -r '.id')

# Создайте ключ сервисного аккаунта и сохраните в ~/.authorized_key.json
yc iam key create --service-account-name terraform-state-sa --output ~/.authorized_key.json

# Установите безопасные права доступа
chmod 600 ~/.authorized_key.json

# Назначьте роль (замените <FOLDER_ID>)
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role storage.editor \
  --subject serviceAccount:$SERVICE_ACCOUNT_ID

# Создайте Static Keys для Object Storage
yc iam access-key create --service-account-name terraform-state-sa
```

Сохраните `key_id` и `secret` для Static Keys.

#### Получение ID каталога:

```bash
# Список каталогов
yc resource-manager folder list
```

### 3. Настройка переменных

**Примечание**: Файл `terraform.tfvars` будет автоматически создан при создании S3 бакета (см. шаг 4). Если вы хотите создать его вручную, выполните следующие шаги:

#### Ручная настройка (опционально)

```bash
cd terrafom-backend
cp terraform.tfvars.example terraform.tfvars
```

Отредактируйте `terraform.tfvars` и укажите:
- `bucket_name` - уникальное имя для бакета Object Storage
- `folder_id` - ID каталога Yandex Cloud (можно получить: `yc config get folder-id`)
- `cloud_id` - ID облака (опционально, можно получить: `yc config get cloud-id`)
- Другие параметры при необходимости

**Внимание**: 
- Файл `terraform.tfvars` содержит чувствительные данные и не должен коммититься!
- Убедитесь, что файл `~/.authorized_key.json` существует и содержит валидный ключ сервисного аккаунта
- Сервисный аккаунт и Static Keys создаются автоматически через Terraform

### 4. Развертывание backend

Используйте интерактивный скрипт управления из корневой директории:

```bash
./manage-backend.sh
```

Скрипт предоставляет меню с опциями:
1. **Создать S3 бакет и настроить backend** - создает:
   - Автоматически генерирует имя бакета из статической части "diplom-kh" и даты/времени (формат: `diplom-kh-YYYYMMDD-HHMMSS`)
   - Автоматически создает `terraform.tfvars` из конфигурации Yandex Cloud CLI (если файл отсутствует)
   - Сервисный аккаунт
   - Static Access Keys
   - S3 бакет с версионированием и шифрованием
   - Назначает необходимые роли
   - Создает файл конфигурации backend (`backend.tf` - несекретный, можно коммитить)
   - Создает файл секретов (`backend-secrets.tfvars` - секретный, не коммитится)
   - Сохраняет учетные данные в `credentials.env`

2. **Удалить S3 бакет и все ресурсы** - удаляет:
   - S3 бакет со всеми данными
   - Сервисный аккаунт
   - Static Access Keys
   - Назначенные роли
   - Файлы конфигурации backend (`backend.tf` и `backend-secrets.tfvars`)
   - Файл учетных данных (`credentials.env`)

3. **Показать текущую конфигурацию** - отображает информацию о созданных ресурсах

4. **Инициализировать backend** - выполняет `terraform init -backend-config=backend-secrets.tfvars` в директории `infrastructure`

5. **Деинициализировать backend** - очищает директорию `infrastructure` от файлов, созданных `terraform init` (`.terraform/`, `.terraform.lock.hcl`, `terraform.tfstate*`)

6. **Протестировать инфраструктуру** - выполняет `terraform validate`, `terraform plan`, `terraform apply` и `terraform destroy` в директории `infrastructure` с автоматической загрузкой ключей доступа (создает и тут же удаляет ресурсы из проекта; используйте осторожно)

**Примечание**: Если файл `terraform.tfvars` отсутствует, он будет автоматически создан при выборе опции 1 из конфигурации Yandex Cloud CLI.

### 5. Использование backend в других проектах

После развертывания создаются два файла в директории `infrastructure`:

1. **`backend.tf`** (несекретный) - основная конфигурация backend, можно коммитить
2. **`backend-secrets.tfvars`** (секретный) - учетные данные, НЕ коммитится (в .gitignore)

Для использования:

1. Перейдите в директорию `infrastructure`:
   ```bash
   cd infrastructure
   ```

2. Загрузите учетные данные и инициализируйте Terraform:
```bash
# Загрузите учетные данные из файла секретов
export AWS_ACCESS_KEY_ID="$(grep access_key backend-secrets.tfvars | cut -d'"' -f2)"
export AWS_SECRET_ACCESS_KEY="$(grep secret_key backend-secrets.tfvars | cut -d'"' -f2)"

# Инициализируйте Terraform
terraform init -backend-config=backend-secrets.tfvars -migrate-state
```

При запросе подтверждения миграции введите `yes`. Вместо ручных шагов можно выбрать пункт 4 в меню `manage-backend.sh`.

**Альтернатива**: Учетные данные также сохранены в `terrafom-backend/credentials.env`:
```bash
source ../terrafom-backend/credentials.env
terraform init -backend-config=backend-secrets.tfvars -migrate-state
```

**Примечание**: 
- Файл `backend.tf` можно коммитить в репозиторий (не содержит секретов)
- Файл `backend-secrets.tfvars` автоматически добавлен в `.gitignore` и не коммитится
- Учетные данные также сохраняются в файл `credentials.env` для удобства
- Для повторной инициализации или очистки используйте пункты 4 и 5 меню `manage-backend.sh`
- Для проверки конфигурации используйте пункт 6 меню `manage-backend.sh` (выполняет `terraform validate`, `plan`, `apply`, `destroy`; ресурсы будут созданы и сразу удалены)

## Особенности реализации

### Object Storage Bucket
- ✅ Версионирование включено (для восстановления старых версий state)
- ✅ Шифрование на стороне сервера (автоматическое, встроенное в Yandex Cloud Object Storage)
- ✅ Политика жизненного цикла (автоматическое удаление старых версий через 90 дней)

### Автоматическое создание ресурсов
- ✅ Сервисный аккаунт создается автоматически через Terraform
- ✅ Static Access Keys создаются автоматически
- ✅ Роли назначаются автоматически (`storage.editor` и `editor`)
- ✅ Учетные данные сохраняются в `credentials.env`

### Интерактивное меню управления
- ✅ Создание всех ресурсов одной командой
- ✅ Удаление всех ресурсов с подтверждением
- ✅ Просмотр текущей конфигурации
- ✅ Инициализация backend одной командой через меню
- ✅ Деинициализация backend (очистка `.terraform` и локального state) через меню
- ✅ Автоматическое тестирование инфраструктуры (`terraform validate` → `terraform plan` → `terraform apply` → `terraform destroy`) из меню
- ✅ Автоматическая настройка terraform.tfvars из Yandex Cloud CLI
- ✅ Разделение конфигурации на секретную и несекретную части
- ✅ Цветной вывод для лучшей читаемости
- ✅ Обработка ошибок и проверка зависимостей

### Автоматизация настройки
- ✅ Автоматическое получение `folder_id` из `yc config`
- ✅ Автоматическое получение `cloud_id` из `yc config`
- ✅ Автоматическое получение `zone` из `yc config`
- ✅ Интерактивный скрипт для создания terraform.tfvars
- ✅ Автоматическое создание terraform.tfvars при отсутствии файла

### Разделение конфигурации backend
- ✅ Несекретная часть (`backend.tf`) - можно коммитить в репозиторий
- ✅ Секретная часть (`backend-secrets.tfvars`) - не коммитится, добавлена в .gitignore
- ✅ Безопасное хранение учетных данных отдельно от конфигурации

### Автоматическая генерация имени бакета
- ✅ Имя бакета автоматически генерируется из статической части "diplom-kh" и даты/времени
- ✅ Формат: `diplom-kh-YYYYMMDD-HHMMSS` (например: `diplom-kh-20241201-143025`)
- ✅ Гарантирует уникальность имени бакета
- ✅ Соответствует требованиям S3-совместимых хранилищ (только строчные буквы, цифры, дефисы)

## Безопасность

- State файлы хранятся в зашифрованном виде (автоматическое шифрование Yandex Cloud Object Storage)
- Конфигурация backend разделена на секретную и несекретную части
- Секретные файлы (`backend-secrets.tfvars`) автоматически добавлены в `.gitignore`
- Используйте сервисные аккаунты вместо личных токенов
- Ограничьте права доступа только необходимыми ролями
- Не коммитьте файлы с реальными учетными данными
- Файл `backend.tf` можно коммитить (не содержит секретов)

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
- Убедитесь, что у аккаунта есть роль `storage.editor`

### Ошибка: "bucket already exists"
- Имя бакета должно быть глобально уникальным
- Выберите другое имя для бакета

### Ошибка при миграции state
- Проверьте правильность учетных данных
- Убедитесь, что переменные окружения установлены (если используются)
- Проверьте endpoint: `https://storage.yandexcloud.net`

## Дополнительная информация

Подробная документация по модулю backend находится в [terrafom-backend/README.md](terrafom-backend/README.md)

## Лицензия

Этот проект создан для дипломной работы.

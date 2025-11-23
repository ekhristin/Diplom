# Инструкция по добавлению переменных в GitHub Actions

## Введение

Для работы Terraform workflow в GitHub Actions необходимо добавить следующие секреты и переменные в настройках репозитория.

## Необходимые секреты (Secrets)

Секреты используются для аутентификации и доступа к облачным ресурсам. Они не отображаются в логах и истории коммитов.

### Как добавить секреты:

1. Откройте ваш репозиторий на GitHub
2. Перейдите в **Settings** (Настройки)
3. В левом меню выберите **Secrets and variables** → **Actions**
4. Нажмите на вкладку **Secrets**
5. Нажмите **New repository secret** (Новый секрет репозитория)
6. Введите имя секрета и его значение
7. Нажмите **Add secret** (Добавить секрет)

### Список необходимых секретов:

#### 1. YC_SERVICE_ACCOUNT_KEY

**Описание**: JSON ключ сервисного аккаунта Yandex Cloud для аутентификации провайдера Terraform.

**Как получить**:
```bash
cd terrafom-backend
terraform output -raw service_account_key_json
```

**Формат**: Полный JSON объект со следующими полями:
```json
{
  "id": "...",
  "service_account_id": "...",
  "created_at": "...",
  "key_algorithm": "RSA_2048",
  "public_key": "-----BEGIN PUBLIC KEY-----\n...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n..."
}
```

**Важно**: 
- Копируйте весь JSON целиком, включая фигурные скобки
- JSON должен содержать все поля: `id`, `service_account_id`, `created_at`, `key_algorithm`, `public_key`, `private_key`
- Это полный JSON ключ IAM, полученный от `terraform output -raw service_account_key_json`

---

#### 2. AWS_ACCESS_KEY_ID

**Описание**: Access Key ID для доступа к Terraform backend (S3-совместимое хранилище Yandex Cloud).

**Как получить**:
```bash
cd terrafom-backend
terraform output -raw access_key_id
```

Или из файла:
```bash
grep access_key terrafom-backend/credentials.env | cut -d'=' -f2 | tr -d '"'
```

**Формат**: Строка вида `YCAJ...` (Access Key ID для Yandex Object Storage)

---

#### 3. AWS_SECRET_ACCESS_KEY

**Описание**: Secret Access Key для доступа к Terraform backend (S3-совместимое хранилище Yandex Cloud).

**Как получить**:
```bash
cd terrafom-backend
terraform output -raw secret_access_key
```

Или из файла:
```bash
grep secret_key terrafom-backend/credentials.env | cut -d'=' -f2 | tr -d '"'
```

**Формат**: Строка вида `YCM...` (Secret Access Key для Yandex Object Storage)

---

#### 4. TF_VAR_folder_id

**Описание**: ID каталога Yandex Cloud, в котором создается инфраструктура. Обязательная переменная для Terraform.

**Как получить**:
```bash
# Из terraform.tfvars
grep folder_id infrastructure/terraform.tfvars | cut -d'"' -f2
```

Или через Yandex Cloud CLI:
```bash
yc config get folder-id
```

**Формат**: Строка вида `b1gb7eigrg8f1c85cu89` (ID каталога Yandex Cloud)

**Важно**: Это обязательная переменная. Без неё Terraform не сможет создать ресурсы.

---

#### 5. TF_VAR_cloud_id (Опционально)

**Описание**: ID облака Yandex Cloud. Опциональная переменная для Terraform.

**Как получить**:
```bash
# Из terraform.tfvars
grep cloud_id infrastructure/terraform.tfvars | cut -d'"' -f2
```

Или через Yandex Cloud CLI:
```bash
yc config get cloud-id
```

**Формат**: Строка вида `b1gl1mia19itahjudhdr` (ID облака Yandex Cloud)

**Примечание**: Если переменная не установлена, будет использовано значение по умолчанию (пустая строка).

---

#### 6. TF_VAR_environment (Опционально)

**Описание**: Окружение для развертывания (dev, staging, prod). Используется для меток ресурсов.

**Как получить**:
```bash
# Из terraform.tfvars
grep environment infrastructure/terraform.tfvars | cut -d'"' -f2
```

**Формат**: Строка (`dev`, `staging`, `prod` и т.д.)

**По умолчанию**: `dev` (если переменная не установлена)

---

#### 7. TF_VAR_project_name (Опционально)

**Описание**: Название проекта для меток ресурсов.

**Как получить**:
```bash
# Из terraform.tfvars
grep project_name infrastructure/terraform.tfvars | cut -d'"' -f2
```

**Формат**: Строка (например, `diplom`)

**По умолчанию**: `diplom` (если переменная не установлена)

---

## Переменные (Variables)

Переменные используются для управления поведением workflow. В отличие от секретов, они не скрываются в логах.

### Как добавить переменные:

1. Откройте ваш репозиторий на GitHub
2. Перейдите в **Settings** (Настройки)
3. В левом меню выберите **Secrets and variables** → **Actions**
4. Нажмите на вкладку **Variables**
5. Нажмите **New repository variable** (Новая переменная репозитория)
6. Введите имя переменной и её значение
7. Нажмите **Add variable** (Добавить переменную)

### Список переменных (опционально):

#### UP_INF (Опционально)

**Описание**: Булева переменная для управления развертыванием инфраструктуры.

**Значения**:
- `true` - развертывание включено (выполняются все шаги CI/CD)
- `false` - развертывание отключено (все шаги пропускаются)

**По умолчанию**: Значение установлено в файле `.github/workflows/terraform.yml` на строке 18

**Примечание**: Если переменная не установлена в репозитории, будет использоваться значение из файла workflow.

---

## Получение значений из Terraform output

Если у вас уже развернут backend через скрипт `manage-backend.sh`, вы можете получить все необходимые значения одной командой:

```bash
cd terrafom-backend

# Получить JSON ключ сервисного аккаунта
terraform output -raw service_account_key_json

# Получить Access Key ID
terraform output -raw access_key_id

# Получить Secret Access Key
terraform output -raw secret_access_key
```

### Альтернативный способ получения из файлов:

```bash
# JSON ключ сервисного аккаунта (полный JSON для провайдера)
cat ~/.authorized_key.json

# Access Key ID и Secret Access Key
source terrafom-backend/credentials.env
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

**Важно**: 
- Файл `~/.authorized_key.json` должен содержать полный JSON ключ (со всеми полями: `id`, `service_account_id`, `created_at`, `key_algorithm`, `public_key`, `private_key`)
- Для локальной разработки путь к файлу указывается в `infrastructure/terraform.tfvars` как `service_account_key_file = "~/.authorized_key.json"`
- Файл `infrastructure/.authorized_key.json` (если существует) может содержать только приватный ключ в формате PEM и не подходит для использования провайдером Terraform

---

## Проверка настройки

После добавления всех секретов и переменных, проверьте:

1. **Секреты**:
   - ✅ `YC_SERVICE_ACCOUNT_KEY` - добавлен
   - ✅ `AWS_ACCESS_KEY_ID` - добавлен
   - ✅ `AWS_SECRET_ACCESS_KEY` - добавлен
   - ✅ `TF_VAR_folder_id` - добавлен (обязательно)
   - ✅ `TF_VAR_cloud_id` - добавлен (опционально)
   - ✅ `TF_VAR_environment` - добавлен (опционально, по умолчанию `dev`)
   - ✅ `TF_VAR_project_name` - добавлен (опционально, по умолчанию `diplom`)

2. **Переменные** (опционально):
   - ✅ `UP_INF` - установлена в нужное значение (или используется значение из workflow файла)

3. **Workflow файл**:
   - ✅ Файл `.github/workflows/terraform.yml` существует
   - ✅ Переменная `UP_INF` установлена в нужное значение (строка 18)

---

## Безопасность

⚠️ **Важные рекомендации по безопасности**:

1. **Никогда не коммитьте секреты** в репозиторий
2. **Проверьте `.gitignore`** - убедитесь, что следующие файлы исключены:
   - `**/.authorized_key.json`
   - `**/credentials.env`
   - `**/backend-secrets.tfvars`
   - `**/*.tfvars` (кроме `.example` файлов)

3. **Ограничьте доступ** к секретам GitHub Actions - только доверенные пользователи должны иметь доступ к настройкам репозитория

4. **Регулярно ротируйте ключи** - периодически создавайте новые ключи и обновляйте секреты

5. **Используйте минимально необходимые права** - сервисный аккаунт должен иметь только те роли, которые действительно необходимы

---

## Пример настройки через веб-интерфейс GitHub

### Добавление секрета YC_SERVICE_ACCOUNT_KEY:

1. Скопируйте JSON ключ:
   ```bash
   cd terrafom-backend
   terraform output -raw service_account_key_json | pbcopy  # на macOS
   # или
   terraform output -raw service_account_key_json | xclip -selection clipboard  # на Linux
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `YC_SERVICE_ACCOUNT_KEY`
   - Secret: вставьте скопированный JSON (Ctrl+V / Cmd+V)
   - Add secret

### Добавление секрета AWS_ACCESS_KEY_ID:

1. Скопируйте Access Key ID:
   ```bash
   terraform output -raw access_key_id | pbcopy
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `AWS_ACCESS_KEY_ID`
   - Secret: вставьте значение
   - Add secret

### Добавление секрета AWS_SECRET_ACCESS_KEY:

1. Скопируйте Secret Access Key:
   ```bash
   terraform output -raw secret_access_key | pbcopy
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Secret: вставьте значение
   - Add secret

### Добавление секрета TF_VAR_folder_id:

1. Получите folder_id:
   ```bash
   cd infrastructure
   grep folder_id terraform.tfvars | cut -d'"' -f2 | pbcopy  # на macOS
   # или
   grep folder_id terraform.tfvars | cut -d'"' -f2 | xclip -selection clipboard  # на Linux
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `TF_VAR_folder_id`
   - Secret: вставьте значение (например, `b1gb7eigrg8f1c85cu89`)
   - Add secret

**Важно**: Это обязательный секрет. Без него Terraform не сможет создать ресурсы.

### Добавление секрета TF_VAR_cloud_id (опционально):

1. Получите cloud_id:
   ```bash
   cd infrastructure
   grep cloud_id terraform.tfvars | cut -d'"' -f2 | pbcopy
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `TF_VAR_cloud_id`
   - Secret: вставьте значение (например, `b1gl1mia19itahjudhdr`)
   - Add secret

**Примечание**: Этот секрет опционален. Если не установлен, будет использовано пустое значение.

### Добавление секрета TF_VAR_environment (опционально):

1. Получите environment:
   ```bash
   cd infrastructure
   grep environment terraform.tfvars | cut -d'"' -f2 | pbcopy
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `TF_VAR_environment`
   - Secret: вставьте значение (например, `dev`)
   - Add secret

**Примечание**: Этот секрет опционален. Если не установлен, будет использовано значение по умолчанию `dev`.

### Добавление секрета TF_VAR_project_name (опционально):

1. Получите project_name:
   ```bash
   cd infrastructure
   grep project_name terraform.tfvars | cut -d'"' -f2 | pbcopy
   ```

2. В GitHub:
   - Settings → Secrets and variables → Actions → Secrets
   - New repository secret
   - Name: `TF_VAR_project_name`
   - Secret: вставьте значение (например, `diplom`)
   - Add secret

**Примечание**: Этот секрет опционален. Если не установлен, будет использовано значение по умолчанию `diplom`.

---

## Использование переменной UP_INF в workflow

Переменная `UP_INF` управляет выполнением всех шагов CI/CD:

- **`UP_INF: 'true'`** - все шаги выполняются:
  - Terraform Init
  - Terraform Validate
  - Terraform Plan
  - Terraform Apply (только для main/master веток)

- **`UP_INF: 'false'`** - все шаги пропускаются, выводится информационное сообщение

### Изменение значения UP_INF:

Отредактируйте файл `.github/workflows/terraform.yml`:

```yaml
env:
  # Переменная для управления развертыванием инфраструктуры
  # Измените значение на 'false', чтобы отключить развертывание
  # 'true' - развертывание включено, 'false' - развертывание отключено
  UP_INF: 'true'  # Измените на 'false' для отключения
```

---

## Устранение неполадок

### Ошибка: "No valid credential sources found"

**Причина**: Не установлена переменная окружения `YC_SERVICE_ACCOUNT_KEY_FILE` или секрет `YC_SERVICE_ACCOUNT_KEY` неверный.

**Решение**:
1. Проверьте, что секрет `YC_SERVICE_ACCOUNT_KEY` добавлен правильно в GitHub Secrets
2. Убедитесь, что JSON ключ полный и корректный (должен содержать все поля: id, service_account_id, created_at, key_algorithm, public_key, private_key)
3. Проверьте логи workflow - шаг "Configure Yandex Cloud credentials" должен выполняться успешно

### Ошибка: "Invalid function argument" или "file name too long" (локально)

**Причина**: В переменной `service_account_key_file` указан неверный путь или содержится JSON вместо пути к файлу.

**Решение**:
1. Проверьте файл `infrastructure/terraform.tfvars` - переменная `service_account_key_file` должна содержать путь к файлу (например, `"~/.authorized_key.json"`), а не сам JSON
2. Убедитесь, что файл `~/.authorized_key.json` существует и содержит полный JSON ключ
3. Проверьте, что путь указан правильно (используйте `~/.authorized_key.json` для домашней директории)

### Ошибка: "Error initializing backend"

**Причина**: Неверные учетные данные для S3 backend или они не установлены.

**Решение**:
1. Проверьте секреты `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY`
2. Убедитесь, что шаг "Configure Terraform backend credentials" выполняется
3. Проверьте, что бакет существует и доступен

### Workflow пропускает все шаги

**Причина**: Переменная `UP_INF` установлена в `'false'`.

**Решение**:
1. Откройте файл `.github/workflows/terraform.yml`
2. Измените значение `UP_INF: 'false'` на `UP_INF: 'true'`
3. Закоммитьте и запушьте изменения

### Ошибка: "Missing required argument" или "No value for required variable"

**Причина**: Не установлена обязательная переменная Terraform (например, `TF_VAR_folder_id`).

**Решение**:
1. Проверьте, что секрет `TF_VAR_folder_id` добавлен в GitHub Secrets
2. Убедитесь, что значение соответствует значению из `infrastructure/terraform.tfvars`
3. Проверьте логи workflow - шаг "Configure Terraform variables" должен выполняться успешно
4. Для опциональных переменных (`TF_VAR_cloud_id`, `TF_VAR_environment`, `TF_VAR_project_name`) убедитесь, что они установлены или будут использованы значения по умолчанию

### Ошибка: "Error: Invalid folder ID" или проблемы с созданием ресурсов

**Причина**: Неверный `folder_id` или отсутствие прав у сервисного аккаунта.

**Решение**:
1. Проверьте, что секрет `TF_VAR_folder_id` содержит корректный ID каталога
2. Убедитесь, что сервисный аккаунт (из `YC_SERVICE_ACCOUNT_KEY`) имеет необходимые права в указанном каталоге
3. Проверьте, что `cloud_id` (если указан) соответствует каталогу

---

## Дополнительные ресурсы

- [GitHub Actions - Encrypted secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitHub Actions - Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Yandex Cloud - Service Accounts](https://cloud.yandex.ru/docs/iam/concepts/users/service-accounts)
- [Terraform - Yandex Cloud Provider](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs)

---

## Быстрая справка

```bash
# Получить все необходимые значения для GitHub Secrets

# 1. Секреты для аутентификации (из terrafom-backend)
cd terrafom-backend

echo "=== YC_SERVICE_ACCOUNT_KEY ==="
terraform output -raw service_account_key_json
echo ""
echo "=== AWS_ACCESS_KEY_ID ==="
terraform output -raw access_key_id
echo ""
echo "=== AWS_SECRET_ACCESS_KEY ==="
terraform output -raw secret_access_key
echo ""

# 2. Переменные Terraform (из infrastructure/terraform.tfvars)
cd ../infrastructure

echo "=== TF_VAR_folder_id ==="
grep folder_id terraform.tfvars | cut -d'"' -f2
echo ""
echo "=== TF_VAR_cloud_id ==="
grep cloud_id terraform.tfvars | cut -d'"' -f2
echo ""
echo "=== TF_VAR_environment ==="
grep environment terraform.tfvars | cut -d'"' -f2
echo ""
echo "=== TF_VAR_project_name ==="
grep project_name terraform.tfvars | cut -d'"' -f2
```

Скопируйте каждое значение и добавьте в соответствующие секреты GitHub Actions.

**Примечание**: 
- `TF_VAR_cloud_id`, `TF_VAR_environment` и `TF_VAR_project_name` являются опциональными
- Если они не установлены, будут использованы значения по умолчанию: `cloud_id = ""`, `environment = "dev"`, `project_name = "diplom"`
- `TF_VAR_folder_id` является обязательной переменной


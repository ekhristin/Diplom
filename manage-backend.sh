#!/bin/bash

# Интерактивный скрипт для управления Terraform Backend в Yandex Cloud
# Создание и удаление S3 бакета для хранения state файлов

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Переменные
BACKEND_DIR="terrafom-backend"
INFRASTRUCTURE_DIR="infrastructure"
BACKEND_CONFIG_FILE="${INFRASTRUCTURE_DIR}/backend.tf"
BACKEND_SECRETS_FILE="${INFRASTRUCTURE_DIR}/backend-secrets.tfvars"
TERRAFORM_CONFIG_FILE="${INFRASTRUCTURE_DIR}/terraform.tf"
CREDENTIALS_FILE="${BACKEND_DIR}/credentials.env"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Функция генерации имени бакета
generate_bucket_name() {
    # Генерируем имя бакета из статической части и даты/времени
    # Формат: diplom-kh-YYYYMMDD-HHMMSS
    # Используем дефисы вместо подчеркиваний для соответствия требованиям S3
    DATE_TIME=$(date +%Y%m%d-%H%M%S)
    echo "diplom-kh-${DATE_TIME}"
}

# Функция для отображения заголовка
show_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Управление Terraform Backend в Yandex Cloud              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Функция для отображения меню
show_menu() {
    echo -e "${BLUE}Выберите действие:${NC}"
    echo -e "  ${GREEN}1${NC}) Создать S3 бакет и настроить backend"
    echo -e "  ${GREEN}2${NC}) Удалить S3 бакет и все ресурсы"
    echo -e "  ${GREEN}3${NC}) Показать текущую конфигурацию"
    echo -e "  ${GREEN}4${NC}) Инициализировать backend (terraform init)"
    echo -e "  ${GREEN}5${NC}) Деинициализировать backend (очистить инфраструктуру)"
    echo -e "  ${GREEN}6${NC}) Протестировать инфраструктуру (terraform plan)"
    echo -e "  ${GREEN}7${NC}) Выход"
    echo ""
    read -p "Ваш выбор [1-7]: " choice
    echo ""
}

# Функция проверки предварительных требований
check_requirements() {
    local errors=0

    echo -e "${YELLOW}Проверка предварительных требований...${NC}"

    # Проверка Terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}✗ Terraform не установлен${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Terraform установлен${NC}"
    fi

    # Проверка файла ключа сервисного аккаунта
    if [ ! -f ~/.authorized_key.json ]; then
        echo -e "${RED}✗ Файл ~/.authorized_key.json не найден${NC}"
        echo -e "${YELLOW}  Создайте ключ: yc iam key create --service-account-name <name> --output ~/.authorized_key.json${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Файл ключа сервисного аккаунта найден${NC}"
    fi

    # Проверка директории backend
    if [ ! -d "$BACKEND_DIR" ]; then
        echo -e "${RED}✗ Директория $BACKEND_DIR не найдена${NC}"
        errors=$((errors + 1))
    else
        echo -e "${GREEN}✓ Директория backend найдена${NC}"
    fi

    # Проверка terraform.tfvars
    if [ ! -f "${BACKEND_DIR}/terraform.tfvars" ]; then
        echo -e "${YELLOW}⚠ Файл ${BACKEND_DIR}/terraform.tfvars не найден${NC}"
        
        # Попытка автоматически создать из yc CLI
        if command -v yc &> /dev/null && yc config list &> /dev/null; then
            echo -e "${BLUE}  Будет автоматически создан при создании backend (опция 1)${NC}"
        else
            echo -e "${YELLOW}  Yandex Cloud CLI не настроен. Создайте файл вручную или настройте yc CLI${NC}"
        fi
        # Не считаем это ошибкой, так как файл будет создан автоматически при создании backend
    else
        echo -e "${GREEN}✓ Файл terraform.tfvars найден${NC}"
        
        # Проверка и предложение обновить значения из yc CLI
        if command -v yc &> /dev/null && yc config list &> /dev/null; then
            YC_FOLDER_ID=$(yc config get folder-id 2>/dev/null || echo "")
            TFVARS_FOLDER_ID=$(grep -E "^folder_id\s*=" "${BACKEND_DIR}/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/' | sed "s/.*=\s*'\(.*\)'/\1/" | sed 's/.*=\s*\(.*\)/\1/' | tr -d ' ' | head -1)
            
            if [ -n "$YC_FOLDER_ID" ] && [ -n "$TFVARS_FOLDER_ID" ] && [ "$YC_FOLDER_ID" != "$TFVARS_FOLDER_ID" ]; then
                echo -e "${YELLOW}⚠ Обнаружено несоответствие folder_id${NC}"
                echo -e "${YELLOW}  В terraform.tfvars: ${TFVARS_FOLDER_ID}${NC}"
                echo -e "${YELLOW}  В yc config: ${YC_FOLDER_ID}${NC}"
            fi
        fi
    fi

    echo ""
    if [ $errors -gt 0 ]; then
        echo -e "${RED}Обнаружены ошибки. Исправьте их перед продолжением.${NC}"
        return 1
    fi

    return 0
}

# Функция создания бакета и настройки backend
create_backend() {
    echo -e "${GREEN}=== Создание S3 бакета и настройка backend ===${NC}"
    echo ""

    # Проверка и создание terraform.tfvars, если он отсутствует
    if [ ! -f "${BACKEND_DIR}/terraform.tfvars" ]; then
        echo -e "${YELLOW}Файл terraform.tfvars не найден${NC}"
        
        # Попытка автоматически создать из yc CLI
        if command -v yc &> /dev/null && yc config list &> /dev/null; then
            echo -e "${BLUE}Автоматическое создание terraform.tfvars из конфигурации Yandex Cloud CLI...${NC}"
            setup_tfvars
            
            if [ ! -f "${BACKEND_DIR}/terraform.tfvars" ]; then
                echo -e "${RED}Не удалось создать terraform.tfvars${NC}"
                return 1
            fi
        else
            echo -e "${RED}Ошибка: Yandex Cloud CLI не настроен или terraform.tfvars отсутствует${NC}"
            echo -e "${YELLOW}Создайте файл terraform.tfvars вручную из terraform.tfvars.example${NC}"
            return 1
        fi
    else
        # Проверка, есть ли bucket_name в существующем файле
        if ! grep -q "^bucket_name" "${BACKEND_DIR}/terraform.tfvars" 2>/dev/null; then
            echo -e "${YELLOW}Имя бакета не найдено в terraform.tfvars${NC}"
            echo -e "${BLUE}Генерация имени бакета...${NC}"
            BUCKET_NAME=$(generate_bucket_name)
            echo -e "${GREEN}✓ Сгенерировано имя бакета: ${BUCKET_NAME}${NC}"
            
            # Добавление bucket_name в terraform.tfvars
            # Проверяем, есть ли уже bucket_name (закомментированный или нет)
            if grep -q "^bucket_name" "${BACKEND_DIR}/terraform.tfvars" 2>/dev/null; then
                # Если bucket_name уже есть, обновляем его
                sed -i "s|^bucket_name.*|bucket_name          = \"${BUCKET_NAME}\"|" "${BACKEND_DIR}/terraform.tfvars"
            elif grep -q "^#.*bucket_name" "${BACKEND_DIR}/terraform.tfvars" 2>/dev/null; then
                # Если есть закомментированная строка, заменяем её
                sed -i "s|^#.*bucket_name.*|bucket_name          = \"${BUCKET_NAME}\"|" "${BACKEND_DIR}/terraform.tfvars"
            else
                # Добавляем bucket_name после первого комментария или в начало файла
                # Создаем новый файл с bucket_name
                TEMP_FILE=$(mktemp)
                # Добавляем комментарий и bucket_name после первой строки с комментарием
                if head -1 "${BACKEND_DIR}/terraform.tfvars" | grep -q "^#"; then
                    # Если первая строка - комментарий, добавляем после неё
                    {
                        head -1 "${BACKEND_DIR}/terraform.tfvars"
                        echo "# Имя бакета автоматически сгенерировано: ${BUCKET_NAME}"
                        echo "bucket_name          = \"${BUCKET_NAME}\""
                        echo ""
                        tail -n +2 "${BACKEND_DIR}/terraform.tfvars"
                    } > "$TEMP_FILE"
                else
                    # Если комментариев нет в начале, добавляем в начало
                    {
                        echo "# Имя бакета автоматически сгенерировано: ${BUCKET_NAME}"
                        echo "bucket_name          = \"${BUCKET_NAME}\""
                        echo ""
                        cat "${BACKEND_DIR}/terraform.tfvars"
                    } > "$TEMP_FILE"
                fi
                mv "$TEMP_FILE" "${BACKEND_DIR}/terraform.tfvars"
            fi
            echo -e "${GREEN}✓ Имя бакета добавлено в terraform.tfvars${NC}"
        fi
    fi

    # Переход в директорию backend
    cd "$BACKEND_DIR"

    # Инициализация Terraform
    echo -e "${YELLOW}Инициализация Terraform...${NC}"
    terraform init

    # Планирование изменений
    echo -e "${YELLOW}Планирование изменений...${NC}"
    terraform plan

    # Подтверждение
    echo ""
    read -p "Применить изменения? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Операция отменена${NC}"
        cd ..
        return 1
    fi

    # Применение изменений
    echo -e "${GREEN}Применение изменений...${NC}"
    terraform apply -auto-approve

    # Получение выходных значений
    echo -e "${GREEN}Получение выходных значений...${NC}"
    BUCKET_NAME=$(terraform output -raw bucket_name)
    ACCESS_KEY=$(terraform output -raw access_key_id)
    SECRET_KEY=$(terraform output -raw secret_access_key)
    SERVICE_ACCOUNT_NAME=$(terraform output -raw service_account_name)
    SA_KEY_JSON=$(terraform output -raw service_account_key_json)

    # Возврат в корневую директорию для сохранения файла
    cd ..

    # Сохранение учетных данных в файл
    echo -e "${GREEN}Сохранение учетных данных...${NC}"
    # Убеждаемся, что директория существует
    mkdir -p "$(dirname "$CREDENTIALS_FILE")"
    cat > "$CREDENTIALS_FILE" << EOF
# Учетные данные для Terraform Backend
# Создано: $(date)
# ВНИМАНИЕ: Этот файл содержит чувствительные данные!
# Не коммитьте его в репозиторий!

export AWS_ACCESS_KEY_ID="${ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${SECRET_KEY}"
export TERRAFORM_STATE_BUCKET="${BUCKET_NAME}"
export TERRAFORM_STATE_SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME}"
EOF
    chmod 600 "$CREDENTIALS_FILE"

    echo -e "${GREEN}✓ Учетные данные сохранены в ${CREDENTIALS_FILE}${NC}"

    # Создание директории infrastructure, если её нет
    mkdir -p "$INFRASTRUCTURE_DIR"

    # Создание несекретного файла конфигурации backend (можно коммитить)
    echo -e "${GREEN}Создание конфигурации backend (несекретная часть)...${NC}"
    cat > "$BACKEND_CONFIG_FILE" << EOF
terraform {
  backend "s3" {
    bucket                      = "${BUCKET_NAME}"
    key                         = "terraform.tfstate"
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    
    # Учетные данные загружаются из переменных окружения:
    # export AWS_ACCESS_KEY_ID="..."
    # export AWS_SECRET_ACCESS_KEY="..."
    # Или через параметры командной строки: -backend-config="access_key=..." -backend-config="secret_key=..."
  }
}
EOF
    echo -e "${GREEN}✓ Файл создан: ${BACKEND_CONFIG_FILE}${NC}"

    # Создание секретного файла с учетными данными (не коммитится)
    echo -e "${GREEN}Создание секретного файла с учетными данными...${NC}"
    cat > "$BACKEND_SECRETS_FILE" << EOF
# Секретные данные для Terraform Backend
# ВНИМАНИЕ: Этот файл содержит чувствительные данные!
# Не коммитьте его в репозиторий!
# Файл добавлен в .gitignore

access_key = "${ACCESS_KEY}"
secret_key = "${SECRET_KEY}"
EOF
    chmod 600 "$BACKEND_SECRETS_FILE"
    echo -e "${GREEN}✓ Файл создан: ${BACKEND_SECRETS_FILE}${NC}"
    echo -e "${YELLOW}  (файл защищен и добавлен в .gitignore)${NC}"

    # Сохранение статического ключа в файл для локальной разработки
    # И подготовка инструкций для GitHub Actions
    INFRASTRUCTURE_TFVARS="${INFRASTRUCTURE_DIR}/terraform.tfvars"
    SA_KEY_FILE="${INFRASTRUCTURE_DIR}/.authorized_key.json"
    
    echo -e "${GREEN}Сохранение статического ключа для локальной разработки...${NC}"
    
    # Сохранение JSON ключа в файл (для локальной разработки)
    echo "$SA_KEY_JSON" > "$SA_KEY_FILE"
    chmod 600 "$SA_KEY_FILE"
    echo -e "${GREEN}✓ Ключ сохранен в ${SA_KEY_FILE}${NC}"
    
    # Обновление infrastructure/terraform.tfvars
    echo -e "${GREEN}Обновление ${INFRASTRUCTURE_TFVARS}...${NC}"
    
    # Получение значений из yc config для создания/обновления файла
    YC_FOLDER_ID=$(yc config get folder-id 2>/dev/null || echo "")
    YC_CLOUD_ID=$(yc config get cloud-id 2>/dev/null || echo "")
    
    # Создание временного файла
    TEMP_TFVARS=$(mktemp)
    
    if [ -f "$INFRASTRUCTURE_TFVARS" ]; then
        # Копируем существующий файл, исключая старую строку service_account_key_file
        grep -v "^service_account_key_file" "$INFRASTRUCTURE_TFVARS" > "$TEMP_TFVARS" || true
    else
        # Создаем новый файл с базовыми значениями
        cat > "$TEMP_TFVARS" << EOF
# Yandex Cloud конфигурация
# Автоматически создано: $(date)
# Использованы значения из: yc config
# Имя бакета автоматически сгенерировано: ${BUCKET_NAME}
# Формат: diplom-kh-YYYYMMDD-HHMMSS

folder_id            = "${YC_FOLDER_ID:-}"
cloud_id             = "${YC_CLOUD_ID:-}"
environment          = "dev"
project_name         = "diplom"
EOF
    fi
    
    # Добавляем service_account_key_file с путем к файлу (для локальной разработки)
    # Для CI/CD будет использоваться переменная окружения YC_SERVICE_ACCOUNT_KEY_FILE
    echo "" >> "$TEMP_TFVARS"
    echo "# Для локальной разработки используется файл ключа" >> "$TEMP_TFVARS"
    echo "# Для CI/CD (GitHub Actions) установите переменную окружения YC_SERVICE_ACCOUNT_KEY_FILE" >> "$TEMP_TFVARS"
    echo "service_account_key_file = \"~/.authorized_key.json\"" >> "$TEMP_TFVARS"
    
    # Перемещаем временный файл на место оригинала
    mv "$TEMP_TFVARS" "$INFRASTRUCTURE_TFVARS"
    
    echo -e "${GREEN}✓ Статический ключ добавлен в ${INFRASTRUCTURE_TFVARS}${NC}"
    
    # Создание файла с инструкциями для GitHub Actions
    GITHUB_ACTIONS_README="${INFRASTRUCTURE_DIR}/.github/README.md"
    mkdir -p "$(dirname "$GITHUB_ACTIONS_README")"
    cat > "$GITHUB_ACTIONS_README" << 'EOF'
# Настройка GitHub Actions для Terraform

## Необходимые секреты GitHub

Добавьте следующие секреты в настройках репозитория (Settings -> Secrets and variables -> Actions):

1. **YC_SERVICE_ACCOUNT_KEY** - JSON ключ сервисного аккаунта Yandex Cloud (полный JSON)
2. **AWS_ACCESS_KEY_ID** - Access Key ID для Terraform backend (S3)
3. **AWS_SECRET_ACCESS_KEY** - Secret Access Key для Terraform backend (S3)

## Пример workflow

Создайте файл `.github/workflows/terraform.yml`:

```yaml
name: Terraform

on:
  push:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'infrastructure/**'
  workflow_dispatch:

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Configure Yandex Cloud credentials
        run: |
          mkdir -p ~/.config
          echo "${{ secrets.YC_SERVICE_ACCOUNT_KEY }}" > ~/.config/yc_sa_key.json
          chmod 600 ~/.config/yc_sa_key.json
          export YC_SERVICE_ACCOUNT_KEY_FILE="$HOME/.config/yc_sa_key.json"
          echo "YC_SERVICE_ACCOUNT_KEY_FILE=$HOME/.config/yc_sa_key.json" >> $GITHUB_ENV
      
      - name: Configure Terraform backend credentials
        run: |
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          echo "AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}" >> $GITHUB_ENV
          echo "AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}" >> $GITHUB_ENV
      
      - name: Terraform Init
        working-directory: ./infrastructure
        run: terraform init
      
      - name: Terraform Validate
        working-directory: ./infrastructure
        run: terraform validate
      
      - name: Terraform Plan
        working-directory: ./infrastructure
        run: terraform plan -no-color
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        working-directory: ./infrastructure
        run: terraform apply -auto-approve -no-color
```

## Получение значений секретов

### YC_SERVICE_ACCOUNT_KEY
JSON ключ сервисного аккаунта можно получить из вывода Terraform:
```bash
cd terrafom-backend
terraform output -raw service_account_key_json
```

### AWS_ACCESS_KEY_ID и AWS_SECRET_ACCESS_KEY
Эти значения можно получить из файла `terrafom-backend/credentials.env` или из Terraform output:
```bash
cd terrafom-backend
terraform output -raw access_key_id
terraform output -raw secret_access_key
```
EOF
    echo -e "${GREEN}✓ Инструкции для GitHub Actions созданы в ${GITHUB_ACTIONS_README}${NC}"

    echo ""
    echo -e "${GREEN}=== Backend успешно создан и настроен! ===${NC}"
    echo ""
    echo -e "${CYAN}Созданные ресурсы:${NC}"
    echo -e "  • Сервисный аккаунт: ${SERVICE_ACCOUNT_NAME}"
    echo -e "  • S3 бакет: ${BUCKET_NAME}"
    echo -e "  • Файл конфигурации (несекретный): ${BACKEND_CONFIG_FILE}"
    echo -e "  • Файл секретов: ${BACKEND_SECRETS_FILE}"
    echo -e "  • Файл учетных данных: ${CREDENTIALS_FILE}"
    echo -e "  • Ключ сервисного аккаунта (локально): ${SA_KEY_FILE}"
    echo ""
    echo -e "${CYAN}Для использования в GitHub Actions:${NC}"
    echo -e "  ${YELLOW}1. Добавьте секреты в GitHub (Settings -> Secrets and variables -> Actions):${NC}"
    echo -e "     • ${GREEN}YC_SERVICE_ACCOUNT_KEY${NC} - JSON ключ сервисного аккаунта"
    echo -e "     • ${GREEN}AWS_ACCESS_KEY_ID${NC} - Access Key для S3 backend"
    echo -e "     • ${GREEN}AWS_SECRET_ACCESS_KEY${NC} - Secret Key для S3 backend"
    echo -e "  ${YELLOW}2. Workflow файл:${NC} .github/workflows/terraform.yml (должен быть в корне репозитория)"
    echo -e "  ${YELLOW}3. Инструкции:${NC} ${GITHUB_ACTIONS_README}"
    echo -e "  ${YELLOW}4. Получить значения секретов:${NC}"
    echo -e "     cd ${BACKEND_DIR}"
    echo -e "     terraform output -raw service_account_key_json  # для YC_SERVICE_ACCOUNT_KEY"
    echo -e "     terraform output -raw access_key_id              # для AWS_ACCESS_KEY_ID"
    echo -e "     terraform output -raw secret_access_key          # для AWS_SECRET_ACCESS_KEY"
    echo -e "  • Ключ сервисного аккаунта (локально): ${SA_KEY_FILE}"
    echo ""
    echo -e "${CYAN}Для использования в GitHub Actions:${NC}"
    echo -e "  • Добавьте секрет YC_SERVICE_ACCOUNT_KEY со значением:"
    echo -e "    terraform output -raw service_account_key_json"
    echo -e "  • Добавьте секреты AWS_ACCESS_KEY_ID и AWS_SECRET_ACCESS_KEY"
    echo -e "  • См. инструкции в: ${GITHUB_ACTIONS_README}"
    echo ""
    echo -e "${YELLOW}Следующие шаги:${NC}"
    echo -e "  1. Перейдите в директорию ${INFRASTRUCTURE_DIR}"
    echo -e "  2. Загрузите учетные данные и выполните инициализацию:"
    echo -e "     cd ${INFRASTRUCTURE_DIR}"
    echo -e "     export AWS_ACCESS_KEY_ID=\"\$(grep access_key ${BACKEND_SECRETS_FILE} | cut -d'\"' -f2)\""
    echo -e "     export AWS_SECRET_ACCESS_KEY=\"\$(grep secret_key ${BACKEND_SECRETS_FILE} | cut -d'\"' -f2)\""
    echo -e "     terraform init -migrate-state"
    echo ""
    echo -e "${CYAN}Примечание:${NC}"
    echo -e "  • Файл ${BACKEND_CONFIG_FILE} можно коммитить в репозиторий"
    echo -e "  • Файл ${BACKEND_SECRETS_FILE} НЕ коммитится (добавлен в .gitignore)"
    echo -e "  • Учетные данные можно также загрузить из ${CREDENTIALS_FILE}: source ${CREDENTIALS_FILE}"
    echo -e "  • Для автоматической инициализации backend используйте опцию 4 меню"
    echo ""
}

# Функция удаления всех ресурсов
destroy_backend() {
    echo -e "${RED}=== Удаление S3 бакета и всех ресурсов ===${NC}"
    echo ""
    echo -e "${YELLOW}ВНИМАНИЕ: Это действие удалит:${NC}"
    echo -e "  • S3 бакет со всеми state файлами"
    echo -e "  • Сервисный аккаунт"
    echo -e "  • Static Access Keys"
    echo -e "  • Назначенные роли"
    echo ""

    read -p "Вы уверены, что хотите продолжить? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Операция отменена${NC}"
        return 1
    fi

    # Переход в директорию backend
    cd "$BACKEND_DIR"

    # Проверка наличия terraform state
    if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
        echo -e "${YELLOW}Terraform state не найден. Возможно, ресурсы уже удалены.${NC}"
        cd ..
        return 1
    fi

    # Планирование удаления
    echo -e "${YELLOW}Планирование удаления...${NC}"
    terraform plan -destroy

    # Подтверждение
    echo ""
    read -p "Продолжить удаление? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Операция отменена${NC}"
        cd ..
        return 1
    fi

    # Удаление ресурсов
    echo -e "${RED}Удаление ресурсов...${NC}"
    terraform destroy -auto-approve

    # Возврат в корневую директорию
    cd ..

    # Удаление файлов конфигурации backend
    echo ""
    echo -e "${BLUE}Удаление файлов конфигурации backend...${NC}"
    
    if [ -f "$BACKEND_CONFIG_FILE" ]; then
        rm -f "$BACKEND_CONFIG_FILE"
        echo -e "${GREEN}✓ Удален файл: ${BACKEND_CONFIG_FILE}${NC}"
    fi
    
    if [ -f "$BACKEND_SECRETS_FILE" ]; then
        rm -f "$BACKEND_SECRETS_FILE"
        echo -e "${GREEN}✓ Удален файл: ${BACKEND_SECRETS_FILE}${NC}"
    fi

    # Удаление файла учетных данных
    if [ -f "$CREDENTIALS_FILE" ]; then
        rm -f "$CREDENTIALS_FILE"
        echo -e "${GREEN}✓ Файл учетных данных удален${NC}"
    fi

    echo ""
    echo -e "${GREEN}=== Все ресурсы успешно удалены ===${NC}"
    echo -e "${CYAN}Файлы конфигурации backend удалены${NC}"
    echo ""
}

# Функция настройки terraform.tfvars из Yandex Cloud CLI
setup_tfvars() {
    echo -e "${CYAN}=== Автоматическая настройка terraform.tfvars ===${NC}"
    echo ""

    # Проверка наличия yc CLI
    if ! command -v yc &> /dev/null; then
        echo -e "${RED}Ошибка: Yandex Cloud CLI (yc) не установлен${NC}"
        echo -e "${YELLOW}Установите его: curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash${NC}"
        return 1
    fi

    # Проверка инициализации yc
    if ! yc config list &> /dev/null; then
        echo -e "${RED}Ошибка: Yandex Cloud CLI не инициализирован${NC}"
        echo -e "${YELLOW}Выполните: yc init${NC}"
        return 1
    fi

    # Генерация имени бакета
    BUCKET_NAME=$(generate_bucket_name)
    echo -e "${GREEN}✓ Сгенерировано имя бакета: ${BUCKET_NAME}${NC}"

    # Получение значений из конфигурации yc
    echo -e "${BLUE}Получение значений из конфигурации Yandex Cloud CLI...${NC}"

    FOLDER_ID=$(yc config get folder-id 2>/dev/null || echo "")
    CLOUD_ID=$(yc config get cloud-id 2>/dev/null || echo "")
    ZONE=$(yc config get compute-default-zone 2>/dev/null || echo "ru-central1-a")

    if [ -z "$FOLDER_ID" ]; then
        echo -e "${YELLOW}Предупреждение: folder-id не найден через yc config get${NC}"
        echo -e "${YELLOW}Попытка получить из yc config list...${NC}"
        FOLDER_ID=$(yc config list 2>/dev/null | grep -E "folder-id" | awk -F'=' '{print $2}' | tr -d ' ' || echo "")
    fi

    if [ -z "$FOLDER_ID" ]; then
        echo -e "${RED}Ошибка: Не удалось определить folder-id${NC}"
        echo -e "${YELLOW}Убедитесь, что yc CLI настроен: yc init${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Folder ID: ${FOLDER_ID}${NC}"
    if [ -n "$CLOUD_ID" ]; then
        echo -e "${GREEN}✓ Cloud ID: ${CLOUD_ID}${NC}"
    else
        echo -e "${YELLOW}⚠ Cloud ID не найден (опционально)${NC}"
    fi
    echo -e "${GREEN}✓ Zone: ${ZONE}${NC}"
    echo ""

    # Проверка наличия директории
    if [ ! -d "$BACKEND_DIR" ]; then
        echo -e "${RED}Ошибка: Директория $BACKEND_DIR не найдена${NC}"
        return 1
    fi

    TFVARS_FILE="${BACKEND_DIR}/terraform.tfvars"

    # Используем значения по умолчанию для других параметров
    SERVICE_ACCOUNT_NAME="terraform-state-sa"
    ENVIRONMENT="dev"
    PROJECT_NAME="diplom"
    RETENTION_DAYS=90

    # Создание файла terraform.tfvars
    echo ""
    echo -e "${GREEN}Создание файла terraform.tfvars...${NC}"

    cat > "$TFVARS_FILE" << EOF
# Yandex Cloud конфигурация
# Автоматически создано: $(date)
# Использованы значения из: yc config
# Имя бакета автоматически сгенерировано: ${BUCKET_NAME}
# Формат: diplom-kh-YYYYMMDD-HHMMSS

bucket_name          = "${BUCKET_NAME}"
service_account_name = "${SERVICE_ACCOUNT_NAME}"
folder_id            = "${FOLDER_ID}"
EOF

    # Добавление cloud_id, если он найден
    if [ -n "$CLOUD_ID" ]; then
        echo "cloud_id             = \"${CLOUD_ID}\"" >> "$TFVARS_FILE"
    fi

    cat >> "$TFVARS_FILE" << EOF
zone                 = "${ZONE}"
environment          = "${ENVIRONMENT}"
project_name         = "${PROJECT_NAME}"
state_retention_days = ${RETENTION_DAYS}

# Примечание: 
# - Для аутентификации провайдера используется файл ключа сервисного аккаунта:
#   ~/.authorized_key.json
# 
# - Сервисный аккаунт и Static Keys будут созданы автоматически через Terraform
# - Учетные данные будут сохранены в файл credentials.env после развертывания
# - Имя бакета генерируется автоматически из статической части "diplom-kh" и даты/времени
#   Формат: diplom-kh-YYYYMMDD-HHMMSS
EOF

    echo -e "${GREEN}✓ Файл terraform.tfvars создан: ${TFVARS_FILE}${NC}"
    echo ""
    echo -e "${CYAN}Следующие шаги:${NC}"
    echo -e "1. Убедитесь, что файл ~/.authorized_key.json существует"
    echo -e "2. Запустите опцию 1 из меню для создания backend"
    echo ""
}

# Функция отображения текущей конфигурации
show_config() {
    echo -e "${CYAN}=== Текущая конфигурация ===${NC}"
    echo ""

    if [ ! -d "$BACKEND_DIR" ]; then
        echo -e "${RED}Директория backend не найдена${NC}"
        return 1
    fi

    cd "$BACKEND_DIR"

    # Проверка terraform state
    if [ -f "terraform.tfstate" ]; then
        echo -e "${GREEN}Текущие ресурсы:${NC}"
        echo ""
        
        # Попытка получить информацию о ресурсах
        if terraform output bucket_name &>/dev/null; then
            BUCKET_NAME=$(terraform output -raw bucket_name 2>/dev/null || echo "N/A")
            SERVICE_ACCOUNT=$(terraform output -raw service_account_name 2>/dev/null || echo "N/A")
            
            echo -e "  Бакет: ${BUCKET_NAME}"
            echo -e "  Сервисный аккаунт: ${SERVICE_ACCOUNT}"
        else
            echo -e "${YELLOW}  Не удалось получить информацию о ресурсах${NC}"
        fi
    else
        echo -e "${YELLOW}Ресурсы не созданы${NC}"
    fi

    echo ""
    
    # Проверка файлов конфигурации backend
    cd ..
    if [ -f "$BACKEND_CONFIG_FILE" ]; then
        echo -e "${GREEN}Файл конфигурации backend (несекретный):${NC}"
        echo -e "  ${BACKEND_CONFIG_FILE}"
        echo ""
        echo -e "${CYAN}Содержимое:${NC}"
        cat "$BACKEND_CONFIG_FILE"
        echo ""
    else
        echo -e "${YELLOW}Файл конфигурации backend не найден${NC}"
    fi
    
    if [ -f "$BACKEND_SECRETS_FILE" ]; then
        echo -e "${GREEN}Файл секретов backend:${NC}"
        echo -e "  ${BACKEND_SECRETS_FILE}"
        echo -e "${YELLOW}  (содержимое скрыто из соображений безопасности)${NC}"
        echo ""
    else
        echo -e "${YELLOW}Файл секретов backend не найден${NC}"
        echo ""
    fi

    # Проверка файла учетных данных
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo -e "${GREEN}Файл учетных данных найден:${NC}"
        echo -e "  ${CREDENTIALS_FILE}"
        echo -e "${YELLOW}  (содержимое скрыто из соображений безопасности)${NC}"
    else
        echo -e "${YELLOW}Файл учетных данных не найден${NC}"
    fi

    echo ""
}

# Функция инициализации backend в директории infrastructure
initialize_backend() {
    echo -e "${GREEN}=== Инициализация backend в директории ${INFRASTRUCTURE_DIR} ===${NC}"
    echo ""

    if [ ! -d "$INFRASTRUCTURE_DIR" ]; then
        echo -e "${RED}Ошибка: директория ${INFRASTRUCTURE_DIR} не найдена${NC}"
        echo -e "${YELLOW}Создайте backend (опция 1), чтобы сгенерировать необходимые файлы${NC}"
        return 1
    fi

    if [ ! -f "$BACKEND_CONFIG_FILE" ]; then
        echo -e "${RED}Ошибка: файл конфигурации backend (${BACKEND_CONFIG_FILE}) не найден${NC}"
        echo -e "${YELLOW}Создайте backend (опция 1), чтобы сгенерировать необходимые файлы${NC}"
        return 1
    fi

    if [ ! -f "$BACKEND_SECRETS_FILE" ]; then
        echo -e "${RED}Ошибка: файл секретов (${BACKEND_SECRETS_FILE}) не найден${NC}"
        echo -e "${YELLOW}Создайте backend (опция 1), чтобы сгенерировать необходимые файлы${NC}"
        return 1
    fi

    cd "$INFRASTRUCTURE_DIR"

    echo -e "${YELLOW}Выполняется terraform init с использованием backend-secrets.tfvars...${NC}"
    if terraform init -backend-config=backend-secrets.tfvars; then
        echo ""
        echo -e "${GREEN}✓ Backend успешно инициализирован${NC}"
    else
        echo ""
        echo -e "${RED}Ошибка: terraform init завершился с ошибкой${NC}"
        cd ..
        return 1
    fi

    cd ..
    echo ""
    echo -e "${CYAN}Напоминание:${NC} terraform init создает директорию .terraform и файл .terraform.lock.hcl в ${INFRASTRUCTURE_DIR}"
    echo -e "${CYAN}Для их удаления используйте опцию 5: Деинициализировать backend${NC}"
    echo ""
}

# Функция деинициализации backend в директории infrastructure
deinitialize_backend() {
    echo -e "${YELLOW}=== Деинициализация backend в директории ${INFRASTRUCTURE_DIR} ===${NC}"
    echo ""

    if [ ! -d "$INFRASTRUCTURE_DIR" ]; then
        echo -e "${RED}Ошибка: директория ${INFRASTRUCTURE_DIR} не найдена${NC}"
        return 1
    fi

    cd "$INFRASTRUCTURE_DIR"

    REMOVED_ANY=0

    if [ -d ".terraform" ]; then
        rm -rf ".terraform"
        echo -e "${GREEN}✓ Удалена директория .terraform${NC}"
        REMOVED_ANY=1
    fi

    if [ -f ".terraform.lock.hcl" ]; then
        rm -f ".terraform.lock.hcl"
        echo -e "${GREEN}✓ Удален файл .terraform.lock.hcl${NC}"
        REMOVED_ANY=1
    fi

    if [ -f "terraform.tfstate" ]; then
        rm -f "terraform.tfstate"
        echo -e "${GREEN}✓ Удален файл terraform.tfstate${NC}"
        REMOVED_ANY=1
    fi

    if [ -f "terraform.tfstate.backup" ]; then
        rm -f "terraform.tfstate.backup"
        echo -e "${GREEN}✓ Удален файл terraform.tfstate.backup${NC}"
        REMOVED_ANY=1
    fi

    if [ $REMOVED_ANY -eq 0 ]; then
        echo -e "${YELLOW}Файлы и директории, созданные terraform init, не найдены${NC}"
    else
        echo -e "${GREEN}✓ Backend деинициализирован. Файлы terraform init удалены.${NC}"
    fi

    cd ..
    echo ""
}

# Функция тестирования инфраструктуры (terraform validate + plan)
test_infrastructure() {
    echo -e "${GREEN}=== Тестирование Terraform инфраструктуры (${INFRASTRUCTURE_DIR}) ===${NC}"
    echo ""
    echo -e "${YELLOW}Предупреждение: будут выполнены terraform apply и terraform destroy в директории ${INFRASTRUCTURE_DIR}.${NC}"
    echo -e "${YELLOW}Убедитесь, что конфигурация не содержит критичных ресурсов.${NC}"
    echo ""

    if [ ! -d "$INFRASTRUCTURE_DIR" ]; then
        echo -e "${RED}Ошибка: директория ${INFRASTRUCTURE_DIR} не найдена${NC}"
        return 1
    fi

    if [ ! -f "$BACKEND_CONFIG_FILE" ]; then
        echo -e "${RED}Ошибка: файл конфигурации backend (${BACKEND_CONFIG_FILE}) не найден${NC}"
        echo -e "${YELLOW}Создайте backend (опция 1), чтобы сгенерировать необходимые файлы${NC}"
        return 1
    fi

    if [ ! -f "$BACKEND_SECRETS_FILE" ]; then
        echo -e "${RED}Ошибка: файл секретов (${BACKEND_SECRETS_FILE}) не найден${NC}"
        echo -e "${YELLOW}Создайте backend (опция 1), чтобы сгенерировать необходимые файлы${NC}"
        return 1
    fi

    ACCESS_KEY=$(grep -E '^access_key' "$BACKEND_SECRETS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' | head -1)
    SECRET_KEY=$(grep -E '^secret_key' "$BACKEND_SECRETS_FILE" | sed 's/.*=\s*"\(.*\)"/\1/' | head -1)

    if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
        echo -e "${RED}Ошибка: не удалось получить access_key/secret_key из ${BACKEND_SECRETS_FILE}${NC}"
        return 1
    fi

    cd "$INFRASTRUCTURE_DIR"

    echo -e "${YELLOW}Инициализация backend...${NC}"
    if ! AWS_ACCESS_KEY_ID="$ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SECRET_KEY" terraform init -backend-config=backend-secrets.tfvars >/dev/null; then
        echo -e "${RED}Ошибка: terraform init завершился с ошибкой${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ terraform init${NC}"

    echo ""
    echo -e "${YELLOW}Выполнение terraform validate...${NC}"
    if ! AWS_ACCESS_KEY_ID="$ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SECRET_KEY" terraform validate; then
        echo -e "${RED}Ошибка: terraform validate завершился с ошибкой${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ terraform validate${NC}"

    echo ""
    echo -e "${YELLOW}Выполнение terraform plan...${NC}"
    if ! AWS_ACCESS_KEY_ID="$ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SECRET_KEY" terraform plan -input=false; then
        echo -e "${RED}Ошибка: terraform plan завершился с ошибкой${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ terraform plan${NC}"

    echo ""
    echo -e "${YELLOW}Применение инфраструктуры (terraform apply)...${NC}"
    if ! AWS_ACCESS_KEY_ID="$ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SECRET_KEY" terraform apply -auto-approve -input=false; then
        echo -e "${RED}Ошибка: terraform apply завершился с ошибкой${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ terraform apply${NC}"

    echo ""
    echo -e "${YELLOW}Удаление инфраструктуры (terraform destroy)...${NC}"
    if ! AWS_ACCESS_KEY_ID="$ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SECRET_KEY" terraform destroy -auto-approve -input=false; then
        echo -e "${RED}Ошибка: terraform destroy завершился с ошибкой${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ terraform destroy${NC}"

    cd ..
    echo ""
    echo -e "${GREEN}=== Тестирование завершено успешно ===${NC}"
    echo ""
}

# Главный цикл
main() {
            while true; do
                show_header
                show_menu

                case $choice in
                    1)
                        if check_requirements; then
                            create_backend
                        else
                            echo -e "${RED}Проверка предварительных требований не пройдена${NC}"
                        fi
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    2)
                        if check_requirements; then
                            destroy_backend
                        else
                            echo -e "${RED}Проверка предварительных требований не пройдена${NC}"
                        fi
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    3)
                        show_config
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    4)
                        if check_requirements; then
                            initialize_backend
                        else
                            echo -e "${RED}Проверка предварительных требований не пройдена${NC}"
                        fi
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    5)
                        if [ -d "$INFRASTRUCTURE_DIR" ]; then
                            deinitialize_backend
                        else
                            echo -e "${RED}Директория ${INFRASTRUCTURE_DIR} не найдена${NC}"
                        fi
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    6)
                        if check_requirements; then
                            test_infrastructure
                        else
                            echo -e "${RED}Проверка предварительных требований не пройдена${NC}"
                        fi
                        echo ""
                        read -p "Нажмите Enter для продолжения..."
                        clear
                        ;;
                    7)
                        echo -e "${GREEN}Выход...${NC}"
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
                        sleep 2
                        clear
                        ;;
                esac
            done
}

# Запуск главного цикла
main


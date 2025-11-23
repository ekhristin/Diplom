#!/bin/bash

# Интерактивный скрипт для управления инфраструктурой Kubernetes в Yandex Cloud
# Развертывание и удаление Kubernetes кластера и всех сопутствующих компонентов

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Переменные
INFRASTRUCTURE_DIR="infrastructure"
KUBE_CONFIG_FILE="${HOME}/.kube/config"
KUBE_CONFIG_BACKUP="${HOME}/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"

# Функция для отображения заголовка
show_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Управление инфраструктурой Kubernetes в Yandex Cloud     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Функция для отображения меню
show_menu() {
    echo -e "${BLUE}Выберите действие:${NC}"
    echo -e "  ${GREEN}1${NC}) Развернуть инфраструктуру (terraform apply)"
    echo -e "  ${GREEN}2${NC}) Удалить инфраструктуру (terraform destroy)"
    echo -e "  ${GREEN}3${NC}) Показать текущую конфигурацию"
    echo -e "  ${GREEN}4${NC}) Проверить подключение к Kubernetes"
    echo -e "  ${GREEN}5${NC}) Удалить контекст Kubernetes из ~/.kube/config"
    echo -e "  ${GREEN}6${NC}) Выход"
    echo ""
    read -p "Ваш выбор [1-6]: " choice
    echo ""
}

# Функция получения имени кластера из Terraform
get_cluster_name() {
    cd "$INFRASTRUCTURE_DIR"
    if terraform output -raw k8s_cluster_name &> /dev/null; then
        terraform output -raw k8s_cluster_name
    else
        # Пытаемся получить из terraform.tfvars
        if [ -f "terraform.tfvars" ]; then
            grep -E "^k8s_cluster_name\s*=" terraform.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1
        else
            echo "diplom-k8s-cluster"  # Значение по умолчанию
        fi
    fi
    cd ..
}

# Функция получения ID кластера из Terraform
get_cluster_id() {
    cd "$INFRASTRUCTURE_DIR"
    if terraform output -raw k8s_cluster_id &> /dev/null; then
        terraform output -raw k8s_cluster_id
    else
        echo ""
    fi
    cd ..
}

# Функция добавления конфигурации Kubernetes в ~/.kube/config
add_kube_config() {
    local cluster_id=$1
    local cluster_name=$2

    echo -e "${GREEN}Добавление конфигурации Kubernetes в ~/.kube/config...${NC}"

    # Создание директории .kube, если её нет
    mkdir -p "$(dirname "$KUBE_CONFIG_FILE")"

    # Резервная копия существующего конфига
    if [ -f "$KUBE_CONFIG_FILE" ]; then
        echo -e "${YELLOW}Создание резервной копии существующего конфига...${NC}"
        cp "$KUBE_CONFIG_FILE" "$KUBE_CONFIG_BACKUP"
        echo -e "${GREEN}✓ Резервная копия создана: ${KUBE_CONFIG_BACKUP}${NC}"
    fi

    # Добавление конфигурации через yc CLI
    if [ -n "$cluster_id" ]; then
        echo -e "${BLUE}Добавление конфигурации для кластера ID: ${cluster_id}${NC}"
        if yc managed-kubernetes cluster get-credentials "$cluster_id" --external &> /dev/null; then
            echo -e "${GREEN}✓ Конфигурация добавлена через yc CLI${NC}"
        else
            echo -e "${YELLOW}⚠ Не удалось добавить через yc CLI, попробуем по имени...${NC}"
            if yc managed-kubernetes cluster get-credentials "$cluster_name" --external &> /dev/null; then
                echo -e "${GREEN}✓ Конфигурация добавлена через yc CLI (по имени)${NC}"
            else
                echo -e "${RED}✗ Не удалось добавить конфигурацию через yc CLI${NC}"
                echo -e "${YELLOW}  Вы можете добавить её вручную:${NC}"
                echo -e "${YELLOW}  yc managed-kubernetes cluster get-credentials ${cluster_name} --external${NC}"
                return 1
            fi
        fi
    else
        echo -e "${YELLOW}⚠ ID кластера не найден, попробуем по имени: ${cluster_name}${NC}"
        if yc managed-kubernetes cluster get-credentials "$cluster_name" --external &> /dev/null; then
            echo -e "${GREEN}✓ Конфигурация добавлена через yc CLI${NC}"
        else
            echo -e "${RED}✗ Не удалось добавить конфигурацию${NC}"
            return 1
        fi
    fi

    echo -e "${GREEN}✓ Конфигурация Kubernetes добавлена в ${KUBE_CONFIG_FILE}${NC}"
    return 0
}

# Функция проверки подключения к Kubernetes
check_kube_connection() {
    echo -e "${YELLOW}Проверка подключения к Kubernetes...${NC}"

    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗ kubectl не установлен${NC}"
        return 1
    fi

    # Проверка наличия конфига
    if [ ! -f "$KUBE_CONFIG_FILE" ]; then
        echo -e "${RED}✗ Файл ~/.kube/config не найден${NC}"
        echo -e "${YELLOW}  Сначала разверните инфраструктуру (опция 1)${NC}"
        return 1
    fi

    # Получение имени кластера
    local cluster_name=$(get_cluster_name)
    
    # Установка контекста
    if kubectl config use-context "$cluster_name" &> /dev/null || kubectl config use-context "yc-$cluster_name" &> /dev/null; then
        echo -e "${GREEN}✓ Контекст установлен${NC}"
    else
        echo -e "${YELLOW}⚠ Не удалось установить контекст автоматически${NC}"
        echo -e "${BLUE}Доступные контексты:${NC}"
        kubectl config get-contexts
        echo ""
        read -p "Введите имя контекста для использования: " context_name
        if kubectl config use-context "$context_name" &> /dev/null; then
            echo -e "${GREEN}✓ Контекст установлен${NC}"
        else
            echo -e "${RED}✗ Не удалось установить контекст${NC}"
            return 1
        fi
    fi

    # Проверка подключения
    echo -e "${BLUE}Проверка подключения к кластеру...${NC}"
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ Подключение к кластеру успешно${NC}"
        echo ""
        echo -e "${CYAN}Информация о кластере:${NC}"
        kubectl cluster-info
        echo ""
        echo -e "${CYAN}Поды во всех namespace:${NC}"
        if kubectl get pods --all-namespaces &> /dev/null; then
            kubectl get pods --all-namespaces
            echo ""
            echo -e "${GREEN}✓ Проверка подключения завершена успешно${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Не удалось получить список подов${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Не удалось подключиться к кластеру${NC}"
        return 1
    fi
}

# Функция удаления контекста Kubernetes из ~/.kube/config
remove_kube_context() {
    echo -e "${YELLOW}=== Удаление контекста Kubernetes из ~/.kube/config ===${NC}"
    echo ""

    if [ ! -f "$KUBE_CONFIG_FILE" ]; then
        echo -e "${YELLOW}Файл ~/.kube/config не найден${NC}"
        return 0
    fi

    # Получение имени кластера
    local cluster_name=$(get_cluster_name)
    local context_name=""
    
    # Поиск контекста
    if kubectl config get-contexts -o name 2>/dev/null | grep -q "$cluster_name"; then
        context_name=$(kubectl config get-contexts -o name 2>/dev/null | grep "$cluster_name" | head -1)
    elif kubectl config get-contexts -o name 2>/dev/null | grep -q "yc-$cluster_name"; then
        context_name=$(kubectl config get-contexts -o name 2>/dev/null | grep "yc-$cluster_name" | head -1)
    fi

    if [ -z "$context_name" ]; then
        echo -e "${YELLOW}Контекст для кластера ${cluster_name} не найден${NC}"
        echo -e "${BLUE}Доступные контексты:${NC}"
        kubectl config get-contexts
        echo ""
        read -p "Введите имя контекста для удаления (или нажмите Enter для отмены): " context_name
        if [ -z "$context_name" ]; then
            echo -e "${YELLOW}Операция отменена${NC}"
            return 0
        fi
    fi

    echo -e "${YELLOW}Будет удален контекст: ${context_name}${NC}"
    read -p "Продолжить? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Операция отменена${NC}"
        return 0
    fi

    # Удаление контекста, кластера и пользователя
    local cluster_name_in_config=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${context_name}')].context.cluster}" 2>/dev/null)
    local user_name_in_config=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='${context_name}')].context.user}" 2>/dev/null)

    if [ -n "$context_name" ]; then
        kubectl config delete-context "$context_name" 2>/dev/null || true
        echo -e "${GREEN}✓ Контекст удален${NC}"
    fi

    if [ -n "$cluster_name_in_config" ]; then
        kubectl config delete-cluster "$cluster_name_in_config" 2>/dev/null || true
        echo -e "${GREEN}✓ Кластер удален из конфига${NC}"
    fi

    if [ -n "$user_name_in_config" ]; then
        kubectl config delete-user "$user_name_in_config" 2>/dev/null || true
        echo -e "${GREEN}✓ Пользователь удален из конфига${NC}"
    fi

    echo -e "${GREEN}✓ Контекст Kubernetes удален из ~/.kube/config${NC}"
}

# Функция автоматической инициализации Terraform
auto_init_terraform() {
    cd "$INFRASTRUCTURE_DIR"

    # Загрузка учетных данных для backend, если они есть
    if [ -f "../terrafom-backend/credentials.env" ]; then
        source ../terrafom-backend/credentials.env
    elif [ -f "backend-secrets.tfvars" ]; then
        export AWS_ACCESS_KEY_ID=$(grep -E '^\s*access_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
        export AWS_SECRET_ACCESS_KEY=$(grep -E '^\s*secret_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
    fi

    # Всегда выполняем terraform init для проверки и исправления lock файла
    # Terraform сам определит, нужна ли переинициализация или обновление провайдеров
    if [ ! -d ".terraform" ]; then
        echo -e "${YELLOW}Terraform не инициализирован. Выполняется инициализация...${NC}"
    else
        echo -e "${YELLOW}Проверка инициализации Terraform...${NC}"
    fi
    
    if ! terraform init; then
        echo -e "${RED}✗ Ошибка инициализации Terraform${NC}"
        cd ..
        return 1
    fi
    
    echo -e "${GREEN}✓ Terraform успешно инициализирован${NC}"

    cd ..
    return 0
}

# Функция развертывания инфраструктуры
deploy_infrastructure() {
    echo -e "${GREEN}=== Развертывание инфраструктуры ===${NC}"
    echo ""

    # Автоматическая инициализация Terraform
    if ! auto_init_terraform; then
        return 1
    fi

    # Переход в директорию infrastructure
    cd "$INFRASTRUCTURE_DIR"

    # Загрузка учетных данных для backend (если еще не загружены)
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        if [ -f "../terrafom-backend/credentials.env" ]; then
            source ../terrafom-backend/credentials.env
        elif [ -f "backend-secrets.tfvars" ]; then
            export AWS_ACCESS_KEY_ID=$(grep -E '^\s*access_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
            export AWS_SECRET_ACCESS_KEY=$(grep -E '^\s*secret_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
        fi
    fi

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
    echo -e "${YELLOW}Это может занять несколько минут...${NC}"
    if ! terraform apply -auto-approve; then
        echo -e "${RED}✗ Ошибка применения изменений${NC}"
        cd ..
        return 1
    fi

    # Получение выходных значений
    echo -e "${GREEN}Получение информации о кластере...${NC}"
    local cluster_id=$(terraform output -raw k8s_cluster_id 2>/dev/null || echo "")
    local cluster_name=$(terraform output -raw k8s_cluster_name 2>/dev/null || echo "")
    
    if [ -z "$cluster_name" ]; then
        cluster_name=$(get_cluster_name)
    fi

    cd ..

    # Добавление конфигурации Kubernetes
    echo ""
    if [ -n "$cluster_id" ] || [ -n "$cluster_name" ]; then
        if add_kube_config "$cluster_id" "$cluster_name"; then
            echo ""
            # Проверка подключения
            echo -e "${BLUE}Проверка подключения к кластеру...${NC}"
            sleep 5  # Небольшая задержка для инициализации кластера
            if check_kube_connection; then
                echo ""
                echo -e "${GREEN}=== Инфраструктура успешно развернута! ===${NC}"
            else
                echo -e "${YELLOW}⚠ Кластер создан, но подключение пока недоступно${NC}"
                echo -e "${YELLOW}  Попробуйте проверить подключение позже (опция 6)${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ Инфраструктура развернута, но конфигурация Kubernetes не добавлена${NC}"
            echo -e "${YELLOW}  Добавьте её вручную: yc managed-kubernetes cluster get-credentials ${cluster_name} --external${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Не удалось получить информацию о кластере${NC}"
    fi

    echo ""
    echo -e "${CYAN}Созданные ресурсы:${NC}"
    cd "$INFRASTRUCTURE_DIR"
    terraform output
    cd ..
    echo ""
}

# Функция удаления инфраструктуры
destroy_infrastructure() {
    echo -e "${RED}=== Удаление инфраструктуры ===${NC}"
    echo ""
    echo -e "${YELLOW}ВНИМАНИЕ: Это действие удалит:${NC}"
    echo -e "  • Kubernetes кластер"
    echo -e "  • Node groups"
    echo -e "  • VPC сеть и подсети"
    echo -e "  • Container Registry"
    echo -e "  • Все связанные ресурсы"
    echo ""

    read -p "Вы уверены, что хотите продолжить? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Операция отменена${NC}"
        return 1
    fi

    # Удаление контекста Kubernetes
    echo ""
    echo -e "${YELLOW}Удаление контекста Kubernetes из ~/.kube/config...${NC}"
    remove_kube_context
    echo ""

    # Переход в директорию infrastructure
    cd "$INFRASTRUCTURE_DIR"

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

    # Удаление
    echo -e "${RED}Удаление ресурсов...${NC}"
    echo -e "${YELLOW}Это может занять несколько минут...${NC}"
    if terraform destroy -auto-approve; then
        echo ""
        echo -e "${GREEN}=== Инфраструктура успешно удалена! ===${NC}"
    else
        echo -e "${RED}✗ Ошибка при удалении ресурсов${NC}"
        cd ..
        return 1
    fi

    cd ..
    echo ""
}

# Функция показа конфигурации
show_config() {
    echo -e "${CYAN}=== Текущая конфигурация ===${NC}"
    echo ""

    cd "$INFRASTRUCTURE_DIR"

    if [ -f "terraform.tfvars" ]; then
        echo -e "${BLUE}Переменные Terraform (terraform.tfvars):${NC}"
        cat terraform.tfvars
        echo ""
    else
        echo -e "${YELLOW}Файл terraform.tfvars не найден${NC}"
    fi

    if terraform output &> /dev/null; then
        echo -e "${BLUE}Выходные значения Terraform:${NC}"
        terraform output
        echo ""
    else
        echo -e "${YELLOW}Инфраструктура еще не развернута${NC}"
    fi

    cd ..
    echo ""
}

# Функция планирования изменений
plan_terraform() {
    echo -e "${GREEN}=== Планирование изменений Terraform ===${NC}"
    echo ""

    # Автоматическая инициализация Terraform (включает загрузку учетных данных)
    if ! auto_init_terraform; then
        return 1
    fi

    cd "$INFRASTRUCTURE_DIR"

    # Загрузка учетных данных для backend (если еще не загружены)
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        if [ -f "../terrafom-backend/credentials.env" ]; then
            source ../terrafom-backend/credentials.env
        elif [ -f "backend-secrets.tfvars" ]; then
            export AWS_ACCESS_KEY_ID=$(grep -E '^\s*access_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
            export AWS_SECRET_ACCESS_KEY=$(grep -E '^\s*secret_key\s*=' backend-secrets.tfvars | sed 's/.*=\s*"\(.*\)".*/\1/' | head -1)
        fi
    fi

    terraform plan

    cd ..
    echo ""
}

# Главный цикл
main() {
    show_header

    while true; do
        show_menu

        case $choice in
            1)
                deploy_infrastructure
                ;;
            2)
                destroy_infrastructure
                ;;
            3)
                show_config
                ;;
            4)
                check_kube_connection
                ;;
            5)
                remove_kube_context
                ;;
            6)
                echo -e "${GREEN}Выход${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
                ;;
        esac

        echo ""
        read -p "Нажмите Enter для продолжения..."
        echo ""
    done
}

# Запуск главной функции
main


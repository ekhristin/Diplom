variable "registry_name" {
  description = "Имя Yandex Container Registry"
  type        = string
  default     = "diplom-netology-kh"
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud, в котором создается реестр"
  type        = string
}

variable "cloud_id" {
  description = "ID облака Yandex Cloud (опционально)"
  type        = string
  default     = ""
}

variable "service_account_key_file" {
  description = "Путь к файлу ключа сервисного аккаунта для Yandex Cloud. Для CI/CD (GitHub Actions) оставьте пустым - будет использована переменная окружения YC_SERVICE_ACCOUNT_KEY_FILE. Для локальной разработки укажите путь, например: ~/.authorized_key.json"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Название проекта для меток"
  type        = string
  default     = "diplom"
}

variable "environment" {
  description = "Окружение (например, dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "additional_labels" {
  description = "Дополнительные метки для контейнерного реестра"
  type        = map(string)
  default     = {}
}

variable "vpc_name" {
  description = "Имя VPC сети"
  type        = string
  default     = "diplom_private_net"
}

variable "subnet_cidrs" {
  description = "Список подсетей по зонам доступности"
  type        = map(string)
  default = {
    "ru-central1-a" = "10.0.10.0/24"
    "ru-central1-b" = "10.0.20.0/24"
    "ru-central1-d" = "10.0.30.0/24"
  }
}

# Переменные для Kubernetes
variable "k8s_cluster_name" {
  description = "Имя Kubernetes кластера"
  type        = string
  default     = "diplom-k8s-cluster"
}

variable "k8s_public_ip" {
  description = "Использовать публичный IP для доступа к API кластера"
  type        = bool
  default     = true
}

variable "k8s_version" {
  description = "Версия Kubernetes (оставьте пустым для использования версии по умолчанию для канала релиза)"
  type        = string
  default     = ""  # Пустое значение означает использование версии по умолчанию
}

variable "k8s_auto_upgrade" {
  description = "Автоматическое обновление кластера"
  type        = bool
  default     = true
}

variable "k8s_maintenance_day" {
  description = "День недели для обслуживания (monday, tuesday, wednesday, thursday, friday, saturday, sunday)"
  type        = string
  default     = "sunday"
}

variable "k8s_maintenance_start_time" {
  description = "Время начала обслуживания (формат: HH:MM)"
  type        = string
  default     = "03:00"
}

variable "k8s_network_policy_provider" {
  description = "Провайдер сетевой политики (CALICO, CILIUM)"
  type        = string
  default     = "CALICO"
}

variable "k8s_release_channel" {
  description = "Канал релиза (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "STABLE"
}

variable "k8s_node_platform_id" {
  description = "Платформа для нод (standard-v1, standard-v2, etc.)"
  type        = string
  default     = "standard-v2"
}

variable "k8s_node_memory" {
  description = "Объем памяти для нод в ГБ"
  type        = number
  default     = 4
}

variable "k8s_node_cores" {
  description = "Количество CPU ядер для нод"
  type        = number
  default     = 2
}

variable "k8s_node_disk_type" {
  description = "Тип диска для нод (network-ssd, network-hdd, network-ssd-nonreplicated)"
  type        = string
  default     = "network-ssd"
}

variable "k8s_node_disk_size" {
  description = "Размер диска для нод в ГБ"
  type        = number
  default     = 64
}

variable "k8s_node_nat" {
  description = "Использовать NAT для нод (доступ в интернет)"
  type        = bool
  default     = true
}

variable "k8s_node_count" {
  description = "Количество нод в группе"
  type        = number
  default     = 2
}

variable "k8s_node_auto_upgrade" {
  description = "Автоматическое обновление нод"
  type        = bool
  default     = true
}

variable "k8s_node_auto_repair" {
  description = "Автоматическое восстановление нод"
  type        = bool
  default     = true
}

variable "k8s_node_ssh_key" {
  description = "SSH ключ для доступа к нодам (опционально)"
  type        = string
  default     = ""
}

variable "k8s_node_preemptible" {
  description = "Использовать прерываемые (preemptible) инстансы для нод (минимизация расходов)"
  type        = bool
  default     = true
}


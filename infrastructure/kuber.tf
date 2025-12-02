# Сервисный аккаунт для кластера Kubernetes
resource "yandex_iam_service_account" "k8s_cluster_sa" {
  name        = "${var.k8s_cluster_name}-cluster-sa"
  description = "Service account for Kubernetes cluster"
  folder_id   = var.folder_id
}

# Назначение ролей сервисному аккаунту кластера
resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_sa_roles" {
  for_each = toset([
    "k8s.clusters.agent",
    "vpc.publicAdmin",
    "vpc.user",  # Дополнительные права для работы с сетью
    "container-registry.images.puller",
    "compute.viewer",
    "load-balancer.admin",
    "editor"  # Полные права на папку для создания LoadBalancer и других ресурсов
  ])
  
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster_sa.id}"
}

# Сервисный аккаунт для нод Kubernetes
resource "yandex_iam_service_account" "k8s_node_sa" {
  name        = "${var.k8s_cluster_name}-node-sa"
  description = "Service account for Kubernetes node group"
  folder_id   = var.folder_id
}

# Назначение ролей сервисному аккаунту нод
resource "yandex_resourcemanager_folder_iam_member" "k8s_node_sa_roles" {
  for_each = toset([
    "container-registry.images.puller",
    "compute.viewer"
  ])
  
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_sa.id}"
}

# Региональный мастер Kubernetes
resource "yandex_kubernetes_cluster" "diplom_k8s" {
  name        = var.k8s_cluster_name
  description = "Regional Kubernetes cluster for diplom project"
  network_id  = yandex_vpc_network.diplom.id
  folder_id   = var.folder_id

  # Сервисные аккаунты для кластера и нод
  service_account_id      = yandex_iam_service_account.k8s_cluster_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_node_sa.id

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
    },
    var.additional_labels
  )

  # Региональный мастер с размещением в 3 подсетях
  master {
    regional {
      region = "ru-central1"
      
      location {
        zone      = "ru-central1-a"
        subnet_id = yandex_vpc_subnet.private["ru-central1-a"].id
      }
      
      location {
        zone      = "ru-central1-b"
        subnet_id = yandex_vpc_subnet.private["ru-central1-b"].id
      }
      
      location {
        zone      = "ru-central1-d"
        subnet_id = yandex_vpc_subnet.private["ru-central1-d"].id
      }
    }

    # Публичный доступ к API кластера
    public_ip = var.k8s_public_ip

    # Настройки обслуживания
    maintenance_policy {
      auto_upgrade = var.k8s_auto_upgrade
      
      maintenance_window {
        day        = var.k8s_maintenance_day
        start_time = var.k8s_maintenance_start_time
        duration   = "3h"
      }
    }
  }

  # Настройки сетевой политики
  network_policy_provider = var.k8s_network_policy_provider

  # Настройки релиза
  release_channel = var.k8s_release_channel

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_sa_roles,
    yandex_resourcemanager_folder_iam_member.k8s_node_sa_roles,
    yandex_vpc_subnet.private
  ]
}

# Node Group с двумя воркерами
resource "yandex_kubernetes_node_group" "diplom_workers" {
  name        = "${var.k8s_cluster_name}-workers"
  description = "Node group for Kubernetes cluster workers"
  cluster_id  = yandex_kubernetes_cluster.diplom_k8s.id

  labels = merge(
    {
      project     = var.project_name
      environment = var.environment
    },
    var.additional_labels
  )

  # Конфигурация нод
  instance_template {
    platform_id = var.k8s_node_platform_id

    # Прерываемые инстансы для минимизации расходов
    scheduling_policy {
      preemptible = var.k8s_node_preemptible
    }

    resources {
      memory = var.k8s_node_memory
      cores  = var.k8s_node_cores
    }

    boot_disk {
      type = var.k8s_node_disk_type
      size = var.k8s_node_disk_size
    }

    # Настройки сети
    network_interface {
      subnet_ids = [
        yandex_vpc_subnet.private["ru-central1-a"].id,
        yandex_vpc_subnet.private["ru-central1-b"].id,
        yandex_vpc_subnet.private["ru-central1-d"].id
      ]
      nat = var.k8s_node_nat
    }

    # Метки для нод
    labels = merge(
      {
        project     = var.project_name
        environment = var.environment
      },
      var.additional_labels
    )
  }

  # Настройки масштабирования
  scale_policy {
    fixed_scale {
      size = var.k8s_node_count
    }
  }

  # Настройки размещения
  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
    location {
      zone = "ru-central1-b"
    }
    location {
      zone = "ru-central1-d"
    }
  }

  # Настройки обслуживания
  maintenance_policy {
    auto_upgrade = var.k8s_node_auto_upgrade
    auto_repair  = var.k8s_node_auto_repair

    maintenance_window {
      day        = var.k8s_maintenance_day
      start_time = var.k8s_maintenance_start_time
      duration   = "3h"
    }
  }

  depends_on = [
    yandex_kubernetes_cluster.diplom_k8s,
    yandex_resourcemanager_folder_iam_member.k8s_node_sa_roles
  ]
}

# Выводы
output "k8s_cluster_id" {
  description = "ID созданного Kubernetes кластера"
  value       = yandex_kubernetes_cluster.diplom_k8s.id
}

output "k8s_cluster_name" {
  description = "Имя созданного Kubernetes кластера"
  value       = yandex_kubernetes_cluster.diplom_k8s.name
}

output "k8s_cluster_endpoint" {
  description = "Endpoint Kubernetes кластера"
  value       = yandex_kubernetes_cluster.diplom_k8s.master[0].external_v4_endpoint
}

output "k8s_node_group_id" {
  description = "ID созданной группы нод"
  value       = yandex_kubernetes_node_group.diplom_workers.id
}

output "k8s_cluster_sa_id" {
  description = "ID Service Account кластера Kubernetes"
  value       = yandex_iam_service_account.k8s_cluster_sa.id
}


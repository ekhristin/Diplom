#!/bin/bash

set -e

echo "=========================================="
echo "Диагностика доступа к Grafana"
echo "=========================================="
echo ""

export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

echo "1. Проверка статуса LoadBalancer Ingress Controller:"
kubectl get service ingress-nginx-controller -n ingress-nginx
echo ""

echo "2. Проверка Ingress ресурсов:"
kubectl get ingress --all-namespaces
echo ""

echo "3. Детальная информация о Ingress Grafana:"
kubectl describe ingress grafana-ingress -n monitoring
echo ""

echo "4. Проверка подов Grafana:"
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
echo ""

echo "5. Проверка сервиса Grafana:"
kubectl get service grafana -n monitoring
kubectl get endpoints grafana -n monitoring
echo ""

echo "6. Переменные окружения в поде Grafana:"
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo "Проверка переменных окружения в поде: $GRAFANA_POD"
    kubectl exec -n monitoring "$GRAFANA_POD" -- env | grep -E "GF_SERVER" || echo "Переменные GF_SERVER не найдены"
    echo ""
    echo "Логи Grafana (последние 30 строк):"
    kubectl logs -n monitoring "$GRAFANA_POD" --tail=30 || echo "Не удалось получить логи"
else
    echo "Поды Grafana не найдены"
fi
echo ""

echo "7. Проверка конфигурации nginx в Ingress Controller:"
INGRESS_POD=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$INGRESS_POD" ]; then
    echo "Проверка конфигурации nginx для Grafana:"
    kubectl exec -n ingress-nginx "$INGRESS_POD" -- cat /etc/nginx/nginx.conf | grep -A 20 "grafana" || echo "Конфигурация для grafana не найдена"
    echo ""
    echo "Логи Ingress Controller (последние 30 строк):"
    kubectl logs -n ingress-nginx "$INGRESS_POD" --tail=30 || echo "Не удалось получить логи"
else
    echo "Поды Ingress Controller не найдены"
fi
echo ""

echo "8. Проверка доступности Grafana изнутри кластера:"
if [ -n "$GRAFANA_POD" ]; then
    echo "Проверка доступности через port-forward..."
    kubectl port-forward -n monitoring "$GRAFANA_POD" 3000:3000 &
    PF_PID=$!
    sleep 3
    curl -s http://localhost:3000 | head -20 || echo "Не удалось подключиться к Grafana"
    kill $PF_PID 2>/dev/null || true
fi
echo ""

echo "9. Проверка правил маршрутизации:"
kubectl get ingress app-test-web-ingress -n app-test-web -o yaml | grep -A 10 "path:" || echo "Ingress для приложения не найден"
echo ""

echo "=========================================="
echo "Диагностика завершена"
echo "=========================================="


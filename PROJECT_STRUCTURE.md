# Структура проекту

```
aiops-quality-project/
├── app/
│   ├── main.py              # FastAPI inference сервіс з drift детектором
│   ├── requirements.txt     # Python залежності для inference сервісу
│   ├── Dockerfile           # Docker образ для сервісу
│   └── .dockerignore        # Файли для ігнорування при збірці
├── model/
│   ├── train.py             # Скрипт для retrain моделі та drift детектора
│   ├── requirements.txt     # Python залежності для тренування
│   └── Dockerfile           # Docker образ для тренування (опціонально)
├── helm/
│   ├── Chart.yaml           # Helm чарт метадані
│   ├── values.yaml          # Значення за замовчуванням
│   └── templates/           # Kubernetes маніфести
│       ├── deployment.yaml  # Deployment для inference сервісу
│       ├── service.yaml     # Service для доступу до сервісу
│       ├── serviceaccount.yaml  # ServiceAccount для RBAC
│       ├── servicemonitor.yaml  # ServiceMonitor для Prometheus
│       └── _helpers.tpl     # Helm helper функції
├── argocd/
│   └── application.yaml     # ArgoCD application конфігурація
├── .gitlab-ci.yml           # GitLab CI пайплайн для retrain та деплою
├── grafana/
│   └── dashboards.json      # Grafana дашборд з метриками
├── prometheus/
│   └── additionalScrapeConfigs.yaml  # Prometheus scrape конфігурація
├── README.md                # Детальна документація проекту
├── PROJECT_STRUCTURE.md     # Цей файл
└── .gitignore               # Git ignore правила
```

## Опис компонентів

### app/
Містить FastAPI inference сервіс:
- **main.py**: Основний код сервісу з drift детекцією
- **requirements.txt**: Залежності (FastAPI, Alibi Detect, Prometheus client)
- **Dockerfile**: Збірка Docker образу для сервісу

### model/
Містить скрипти для тренування:
- **train.py**: Скрипт тренування моделі та drift детектора
- **requirements.txt**: Залежності для тренування
- **Dockerfile**: Опціональний Docker образ для тренування

### helm/
Helm чарт для деплою в Kubernetes:
- **Chart.yaml**: Метадані чарту
- **values.yaml**: Конфігурація за замовчуванням
- **templates/**: Kubernetes маніфести

### argocd/
ArgoCD конфігурація для GitOps деплою:
- **application.yaml**: Application ресурс для ArgoCD

### .gitlab-ci.yml
CI/CD пайплайн з трьома stages:
1. **train**: Retrain моделі
2. **build**: Збірка Docker образу
3. **deploy**: Оновлення Helm чарту

### grafana/
Grafana дашборд:
- **dashboards.json**: JSON конфігурація дашборду

### prometheus/
Prometheus конфігурація:
- **additionalScrapeConfigs.yaml**: Додаткові scrape конфігурації


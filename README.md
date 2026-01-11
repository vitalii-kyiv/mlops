# MLOps Quality Project

Complete MLOps project for inference service with quality monitoring, drift detection, and automatic retraining.

## Project Structure

```
aiops-quality-project/
├── app/
│   ├── main.py              # FastAPI inference service
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile           # Docker image for service
├── model/
│   ├── train.py             # Script for model retraining
│   └── requirements.txt     # Training dependencies
├── helm/
│   ├── Chart.yaml           # Helm chart metadata
│   ├── values.yaml          # Default values
│   └── templates/           # Kubernetes manifests
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceaccount.yaml
│       ├── servicemonitor.yaml
│       └── _helpers.tpl
├── argocd/
│   └── application.yaml     # ArgoCD application configuration
├── .gitlab-ci.yml           # GitLab CI pipeline for retraining
├── grafana/
│   └── dashboards.json      # Grafana dashboard
├── prometheus/
│   └── additionalScrapeConfigs.yaml  # Prometheus configuration
└── README.md                # This file
```

## System Components

### 1. FastAPI Inference Service

**Location:** `app/main.py`

**Features:**
- Model loading on service startup
- `/predict` endpoint for predictions
- Input data drift detection (Alibi Detect)
- Logging of all requests and responses
- Prometheus metrics:
  - `inference_requests_total` - request count
  - `inference_request_duration_seconds` - latency
  - `drift_detections_total` - number of detected drifts
  - `model_loaded` - model loading status

**Endpoints:**
- `GET /health` - health check
- `GET /metrics` - Prometheus metrics
- `POST /predict` - prediction with drift detection
- `POST /webhook/drift` - webhook for retrain trigger

### 2. Drift Detector

**Implementation:** Alibi Detect (KSDrift)

**Features:**
- Input data drift check against reference data
- Logging of detected drifts
- Ability to call webhook for retrain pipeline

**Configuration:**
- Reference data stored in `/app/models/reference_data.pkl`
- Detector stored in `/app/models/drift_detector.pkl`
- Drift threshold: p-value < 0.05

### 3. GitLab CI Pipeline

**Location:** `.gitlab-ci.yml`

**Stages:**
1. **train** - Model retraining (`retrain-model` job)
2. **build** - Docker image build (`build-image` job)
3. **deploy** - Helm chart update (`update-helm-chart` job)

**Triggers:**
- Manual execution
- Webhook (for automatic retraining on drift)

### 4. Helm Chart

**Location:** `helm/`

**Components:**
- Deployment with 2 replicas by default
- Service for service access
- ServiceMonitor for Prometheus
- ServiceAccount for RBAC

**Configuration:**
- Edit `helm/values.yaml` to change configuration
- Change `image.repository` to your Docker registry
- Configure resources, replicas, etc.

### 5. ArgoCD

**Location:** `argocd/application.yaml`

**Features:**
- Automatic sync from Git repository
- Self-healing on changes
- Auto-prune of stale resources

**Configuration:**
- Update `repoURL` to your Git repository
- Configure `destination.namespace` if needed

### 6. Monitoring

**Prometheus:**
- ServiceMonitor automatically collects metrics from pods
- Scrape interval: 30 seconds
- Metrics available at `/metrics` endpoint

**Grafana:**
- Dashboard with key metrics:
  - Request Rate (requests/sec)
  - Request Latency (p50, p95)
  - Drift Detections (count and rate)
  - Model Status
  - Error Rate

**Loki:**
- Logging via stdout automatically collected by Promtail
- All logs available in Loki for analysis

## How to Run the Project

### Prerequisites

1. Kubernetes cluster with access
2. Helm 3.x installed
3. ArgoCD installed and configured
4. Prometheus Operator installed
5. Loki + Promtail installed
6. GitLab CI/CD configured
7. Docker registry for storing images

### Step 1: Model Preparation

```bash
# Install dependencies
pip install -r model/requirements.txt

# Train model
python model/train.py

# Verify files are created
ls -la models/
# Should contain: model.pkl, drift_detector.pkl, reference_data.pkl
```

### Step 2: Docker Image Build

```bash
# Copy models to app directory
cp -r models app/

# Build image
docker build -t your-registry/aiops-quality:latest -f app/Dockerfile .

# Push to registry
docker push your-registry/aiops-quality:latest
```

### Step 3: Update Helm Values

Edit `helm/values.yaml`:

```yaml
image:
  repository: your-registry/aiops-quality
  tag: "latest"
```

### Step 4: Deploy via Helm

```bash
# Deploy
helm install aiops-quality ./helm --namespace default --create-namespace

# Or update
helm upgrade aiops-quality ./helm --namespace default
```

### Step 5: Configure ArgoCD

```bash
# Update argocd/application.yaml with your Git repository
# Apply application
kubectl apply -f argocd/application.yaml

# Check status
kubectl get applications -n argocd
```

### Step 6: Configure Prometheus

If using Prometheus Operator, ServiceMonitor will be automatically picked up.

For manual configuration, add configuration from `prometheus/additionalScrapeConfigs.yaml` to your Prometheus.

### Step 7: Import Grafana Dashboard

```bash
# Import dashboards.json into Grafana via UI or API
# Or use ConfigMap for automatic import
kubectl create configmap grafana-dashboard-aiops \
  --from-file=dashboards.json=grafana/dashboards.json \
  -n monitoring
```

## How to Test Requests

### Local Testing (if service is running locally)

```bash
# Health check
curl http://localhost:8000/health

# Prediction request
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
    "request_id": "test-123"
  }'
```

### Testing in Kubernetes

```bash
# Port-forward to service
kubectl port-forward svc/aiops-quality 8000:80 -n default

# In another terminal
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
    "request_id": "test-123"
  }'
```

**Expected Response:**
```json
{
  "prediction": 0.55,
  "request_id": "test-123",
  "drift_detected": false,
  "drift_score": 0.02
}
```

## How to Check Logging

### Check Pod Logs

```bash
# List pods
kubectl get pods -l app.kubernetes.io/name=aiops-quality

# Logs of specific pod
kubectl logs <pod-name> -n default

# Logs with follow
kubectl logs -f <pod-name> -n default

# Logs of all pods
kubectl logs -l app.kubernetes.io/name=aiops-quality -n default
```

### Check in Loki

1. Open Grafana
2. Go to Explore
3. Select Loki as data source
4. Use query:
   ```
   {app="aiops-quality"}
   ```

### What Should Be in Logs

- `Input data: [0.1, 0.2, ...]` - input data
- `Prediction: 0.55` - model prediction
- `Drift detected! Score: 0.15` - if drift detected

## How to Verify Detector Triggering

### Testing Drift Detection

Send request with data that differs from reference:

```bash
# Normal data (should not trigger drift)
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  }'

# Data with drift (should trigger drift)
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": [10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0, 10.0]
  }'
```

### Check Metrics

```bash
# Port-forward to metrics
kubectl port-forward svc/aiops-quality 8000:80 -n default

# Check metrics
curl http://localhost:8000/metrics | grep drift_detections_total
```

### Check in Grafana

1. Open dashboard "MLOps Quality - Inference Service Dashboard"
2. Check "Drift Detections" panel
3. After sending requests with drift, counter should increase

## How to Verify Retrain Pipeline Works

### Manual Execution via GitLab UI

1. Open GitLab project
2. Go to CI/CD > Pipelines
3. Click "Run pipeline"
4. Select `retrain-model` job and run

### Execution via API

```bash
# Run pipeline via GitLab API
curl -X POST \
  -H "PRIVATE-TOKEN: <your-token>" \
  "https://gitlab.com/api/v4/projects/<project-id>/pipeline?ref=main"
```

### Check Results

```bash
# Check artifacts in GitLab CI
# After retrain-model job completion, should be available:
# - models/model.pkl
# - models/drift_detector.pkl
# - models/reference_data.pkl
```

### Automatic Trigger via Webhook

On drift detection, webhook can be called:

```bash
# Call webhook (if configured)
curl -X POST http://localhost:8000/webhook/drift
```

For automatic retrain trigger, add GitLab CI API call in `app/main.py` on drift detection.

## How to Update Model

### Option 1: Via GitLab CI (Recommended)

1. Run `retrain-model` pipeline manually or via webhook
2. After successful training, run `build-image`
3. After image build, run `update-helm-chart`
4. ArgoCD will automatically sync changes

### Option 2: Manual Update

```bash
# 1. Train model
python model/train.py

# 2. Copy models
cp -r models app/

# 3. Build new image
docker build -t your-registry/aiops-quality:v2.0 -f app/Dockerfile .
docker push your-registry/aiops-quality:v2.0

# 4. Update Helm values
# Edit helm/values.yaml:
# image:
#   tag: "v2.0"

# 5. Update deployment
helm upgrade aiops-quality ./helm --namespace default

# Or if using ArgoCD, just commit changes to Git
```

### Option 3: Via ArgoCD (GitOps)

1. Update `helm/values.yaml` with new image version
2. Commit changes to Git
3. ArgoCD will automatically sync changes

```bash
git add helm/values.yaml
git commit -m "Update model to v2.0"
git push
```

## Monitoring and Metrics

### Available Prometheus Metrics

- `inference_requests_total{status="success|error"}` - total request count
- `inference_request_duration_seconds` - latency histogram
- `drift_detections_total` - number of detected drifts
- `model_loaded` - model status (1 = loaded, 0 = not loaded)

### Grafana Dashboard

Dashboard includes:
- **Request Rate** - request rate
- **Request Latency** - p50 and p95 latency
- **Drift Detections** - drift count and rate
- **Model Status** - model loading status
- **Error Rate** - error percentage

### Alerts (Recommended to Add)

Recommended to configure alerts for:
- High error rate (> 5%)
- High latency (p95 > 2s)
- Frequent drifts (> 10 per minute)
- Model not loaded

## Troubleshooting

### Issue: Model Not Loading

```bash
# Check logs
kubectl logs <pod-name> | grep -i "model"

# Check files exist in pod
kubectl exec <pod-name> -- ls -la /app/models/

# Check environment variables
kubectl exec <pod-name> -- env | grep MODEL
```

### Issue: Metrics Not Collected

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n default

# Check annotations on pods
kubectl get pods -o yaml | grep prometheus.io

# Check Prometheus scrapes service
# In Prometheus UI check Targets
```

### Issue: ArgoCD Not Syncing

```bash
# Check application status
kubectl get application aiops-quality -n argocd -o yaml

# Check sync status
argocd app get aiops-quality

# Force sync
argocd app sync aiops-quality
```

### Issue: Drift Detector Not Working

```bash
# Check logs
kubectl logs <pod-name> | grep -i drift

# Check detector is loaded
kubectl exec <pod-name> -- python -c "import pickle; f=open('/app/models/drift_detector.pkl','rb'); print('OK')"
```

## Additional Configuration

### Resource Configuration

Edit `helm/values.yaml`:

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

### Autoscaling Configuration

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Ingress Configuration

```yaml
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: aiops-quality.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Contact and Support

For questions and issues, create issues in Git repository.

## License

MIT License

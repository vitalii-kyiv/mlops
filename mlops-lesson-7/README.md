## 1. How to run Terraform

Go to the directory with the Terraform configuration:

```sh
cd terraform/argocd
```

Initialize Terraform:

```sh
terraform init
```

Show the planned changes:

```sh
terraform plan
```

Apply the changes:

```sh
terraform apply
```

Confirm with `yes` when prompted.

---

## 2. How to verify that ArgoCD is running

Check Kubernetes namespaces:

```sh
kubectl get ns
```

You should see the namespace used for ArgoCD, for example:

- `infra-tools`

Check ArgoCD pods:

```sh
kubectl get pods -n infra-tools
```

You should see several pods with the `argocd-` prefix, for example:

- `argocd-application-controller-*`
- `argocd-applicationset-controller-*`
- `argocd-dex-server-*`
- `argocd-notifications-controller-*`
- `argocd-redis-*`
- `argocd-repo-server-*`
- `argocd-server-*`

---

## 3. How to open the ArgoCD UI

### Get the admin password

```sh
kubectl -n infra-tools get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode
```

### Port-forward the ArgoCD server

```sh
kubectl port-forward svc/argocd-server -n infra-tools 8080:443
```

Then open the browser and go to:

👉 [https://localhost:8080](https://localhost:8080)

You may need to accept the insecure HTTPS warning in your browser.

### Login credentials

- **Username:** `admin`
- **Password:** the value you decoded above

---

## 4. How to verify that the deployment is working

List ArgoCD Applications:

```sh
kubectl get applications -n infra-tools
```

Describe a specific Application:

```sh
kubectl describe application nginx -n infra-tools
```

Check pods created by the Helm chart:

```sh
kubectl get pods -n application
```

Check all resources in the application namespace:

```sh
kubectl get all -n application
```

---

## 5. Configure ArgoCD to watch a Git repository

After ArgoCD is deployed, configure a connection to the Git repository using the UI or CLI.

### Using the UI

1. Open the ArgoCD UI (see section 3).
2. Go to **Settings → Repositories**.
3. Add a new repository:
   - **Type:** `git`
   - **Repository URL:** `https://github.com/vitalii-kyiv/mlops/tree/lesson-8-9`
   - For a public repository no additional authentication settings are required.

### Using the CLI

```sh
argocd repo add https://github.com/vitalii-kyiv/mlops/tree/lesson-8-9 --type git
```

### Creating an Application in ArgoCD

After adding the repository, create an Application via the UI or apply the manifest:

```sh
kubectl apply -f https://raw.githubusercontent.com/vitalii-kyiv/mlops/lesson-8-9/mlops-lesson-9/namespaces/application/nginx.yaml
```

Or, if the repository is already cloned locally:

```sh
kubectl apply -f namespaces/application/nginx.yaml
```

---

## 6. How to expose the nginx service

After nginx is successfully deployed via ArgoCD, you can access the service in different ways.

### Option 1: Port-forward (for local testing)

```sh
kubectl port-forward svc/nginx -n application 8081:80
```

Then open in the browser: `http://localhost:8081`.

### Option 2: LoadBalancer (for production)

If you need external access, change the service type to `LoadBalancer` in `mlops-lesson-9/namespaces/application/nginx.yaml`:

```yaml
service:
  type: LoadBalancer
```

Commit and push the changes to the Git repository. ArgoCD will automatically synchronize them.

Check the external IP:

```sh
kubectl get svc nginx -n application
```

---

## 7. Git repository structure (mlops-lesson-9)

The ArgoCD example in this setup expects the following structure in the Git repository:

```
mlops-lesson-9
├── namespaces
│  ├── application
│  │  ├── nginx.yaml
│  │  └── ns.yaml
│  └── infra-tools
│    └── ns.yaml
└── README.md
```

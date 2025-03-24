
# CMS Application Deployment on Azure AKS (Proof of Concept)

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Implementation Phases](#implementation-phases)
  - [Phase 1: Infrastructure Provisioning](#phase-1-infrastructure-provisioning)
  - [Phase 2: Application Containerization](#phase-2-application-containerization)
  - [Phase 3: Helm Chart and Deployment](#phase-3-helm-chart-and-deployment)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)
- [Conclusion](#conclusion)

## Overview

This project demonstrates deploying a Customer Management System (CMS) application on Azure Kubernetes Service (AKS) using Terraform, Docker, and Helm. It serves as a proof-of-concept (PoC) for learning purposes, covering infrastructure provisioning, app containerization, Helm deployment, and basic troubleshooting.

## Architecture

### High-Level Architecture
- **Azure Kubernetes Service (AKS)**: Hosts the CMS application in a managed Kubernetes cluster
- **Azure Container Registry (ACR)**: Stores the Docker image (`cmsacr2025.azurecr.io/cms-app:1.0`) with anonymous pull enabled for simplicity
- **Azure SQL Database**: Stores customer data, accessed by the app via pyodbc
- **NGINX Ingress Controller**: Routes external traffic to the CMS app within AKS
- **Local Testing Environment**: Debug pod (`curlimages/curl`) used for internal validation

### Component Details
#### AKS Cluster
- Name: `cms-aks-cluster`
- Resource Group: `cms-rg-poc`
- Node Pool: 2 nodes (`Standard_DS2_v2`)
- Subnet: `aks-subnet` in `cms-vnet`

#### Azure Container Registry
- Name: `cmsacr2025`
- SKU: Standard
- Features: Anonymous pull enabled

#### Application
- Image: `cmsacr2025.azurecr.io/cms-app:1.0`
- Ports: 8000 (container), 80 (service)
- Endpoints: 
  - POST `/customers/`
  - GET `/customers/`

#### Database
- Server: `cms-sql-server2025.database.windows.net`
- Database: `cms-db`
- Credentials: `sqladmin` / `P@ssw0rd123!` (hardcoded for PoC)

## Prerequisites

- **Azure CLI**: For resource management
- **Terraform**: For infrastructure provisioning
- **Docker**: For building and pushing the app image
- **Helm**: For deploying to AKS
- **kubectl**: For cluster interaction

## Implementation Phases

### Phase 1: Infrastructure Provisioning

#### 1. Terraform Configuration

Example snippet from `main.tf`:

```hcl
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "cms-aks-cluster"
  location            = "East US"
  resource_group_name = "cms-rg-poc"
  dns_prefix          = "cmsaks"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}
```

#### 2. Deploy Infrastructure

```bash
# Initialize and apply Terraform
terraform init
terraform apply -auto-approve

# Get AKS credentials
az aks get-credentials --resource-group cms-rg-poc --name cms-aks-cluster
```

### Phase 2: Application Containerization

#### 1. Directory Structure

```
cms-app/
├── Dockerfile
├── main.py
├── requirements.txt
```

#### 2. Dockerfile

```dockerfile
FROM python:3.9-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg curl unixodbc unixodbc-dev \
    && curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl -sSL https://packages.microsoft.com/config/debian/11/prod.list -o /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### 3. main.py

```python
from fastapi import FastAPI
from pydantic import BaseModel
import pyodbc
import os

app = FastAPI()

class Customer(BaseModel):
    name: str
    email: str

def get_db_connection():
    server = os.getenv("SQL_SERVER", "cms-sql-server2025.database.windows.net")
    database = os.getenv("SQL_DB", "cms-db")
    username = os.getenv("SQL_USER", "sqladmin")
    password = os.getenv("SQL_PASSWORD", "P@ssw0rd123!")
    driver = "{ODBC Driver 18 for SQL Server}"
    conn_str = f"DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    return pyodbc.connect(conn_str)

@app.post("/customers/")
def create_customer(customer: Customer):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO customers (name, email) VALUES (?, ?)", (customer.name, customer.email))
    conn.commit()
    return {"message": "Customer created", "name": customer.name}

@app.get("/customers/")
def get_customers():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT name, email FROM customers")
    rows = cursor.fetchall()
    return [{"name": row[0], "email": row[1]} for row in rows]
```

#### 4. requirements.txt

```
fastapi==0.95.0
uvicorn==0.20.0
pyodbc==4.0.39
pydantic==1.10.7
```

#### 5. Build and Push

```bash
# Build Docker image
docker build --no-cache -t cms-app:1.0 .

# Tag and push to ACR
docker tag cms-app:1.0 cmsacr2025.azurecr.io/cms-app:1.0
az acr login --name cmsacr2025
docker push cmsacr2025.azurecr.io/cms-app:1.0
```

#### 6. Test Locally

```bash
# Run container locally
docker run -p 8000:8000 \
  --env SQL_SERVER=cms-sql-server2025.database.windows.net \
  --env SQL_DB=cms-db \
  --env SQL_USER=sqladmin \
  --env SQL_PASSWORD=P@ssw0rd123! \
  cms-app:1.0

# Test API
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"John Doe","email":"john@example.com"}' \
     http://localhost:8000/customers/
```

### Phase 3: Helm Chart and Deployment

#### 1. Create Helm Chart

```bash
helm create cms-chart
```

#### 2. Chart Structure

```
cms-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
```

#### 3. Chart.yaml

```yaml
apiVersion: v2
name: cms-chart
description: Helm chart for CMS app
type: application
version: 0.1.0
appVersion: "1.0"
```

#### 4. values.yaml

```yaml
replicaCount: 2

image:
  repository: cmsacr2025.azurecr.io/cms-app
  tag: "1.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

ingress:
  enabled: true
  hosts:
    - host: cms-app.local
      paths:
        - path: /
          pathType: Prefix

env:
  - name: SQL_SERVER
    value: "cms-sql-server2025.database.windows.net"
  - name: SQL_DB
    value: "cms-db"
  - name: SQL_USER
    value: "sqladmin"
  - name: SQL_PASSWORD
    value: "P@ssw0rd123!"
```

#### 5. templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: cms-app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          env:
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}
```

#### 6. templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-service
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
  selector:
    app: {{ .Release.Name }}
```

#### 7. templates/ingress.yaml (Final Version)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-ingress
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /customers
            pathType: Prefix
            backend:
              service:
                name: {{ .Release.Name }}-service
                port:
                  number: {{ .Values.service.port }}
```

#### 8. Install NGINX Ingress Controller

```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# Deploy application
helm install cms-app ./cms-chart
```

## Configuration

### Environment Variables
```yaml
env:
  - name: SQL_SERVER
    value: "cms-sql-server2025.database.windows.net"
  - name: SQL_DB
    value: "cms-db"
  - name: SQL_USER
    value: "sqladmin"
  - name: SQL_PASSWORD
    value: "P@ssw0rd123!"
```

## Troubleshooting

### Docker Build Issues

1. **DPKG Error**
   - **Problem**: Sub-process /usr/bin/dpkg returned an error code (1) due to package conflicts (libodbc1, odbcinst)
   - **Fix**: 
   ```dockerfile
   # Solution: Add non-interactive frontend
   ENV DEBIAN_FRONTEND=noninteractive
   RUN apt-get update && apt-get install -y gnupg curl unixodbc unixodbc-dev msodbcsql18
   ```
   - **Outcome**: Build succeeded after multiple iterations

2. **Missing ODBC Libraries**
   - **Problem**: libodbc.so.2 not found
   - **Fix**: Added unixodbc and msodbcsql18 to Dockerfile
   - **Solution**: Added ODBC packages to Dockerfile

### Deployment Issues

1. **Image Pull Errors**
   - **Problem**: AKS couldn't pull cmsacr2025.azurecr.io/cms-app:1.0 due to 401 Unauthorized
   - **Fix**:
   ```bash
   # Enable anonymous pull on ACR
   az acr update --name cmsacr2025 --sku Standard
   az acr update --name cmsacr2025 --anonymous-pull-enabled true
   ```
   - **Outcome**: Pods started running after deleting and recreating

2. **Ingress Timeout**
   - **Problem**: curl http://130.213.140.147/customers/ timed out despite pods running and NSG rule allowing port 80
   - **Troubleshooting**:
     - Verified pods (kubectl get pods): Running
     - Tested service internally (kubectl port-forward svc/cms-app-service 8000:80): Worked
     - Checked Ingress (kubectl get ingress): IP assigned (130.213.140.147)
   - **Fix**: Used debug pod for internal testing
   ```bash
   # Debug pod for testing
   kubectl run -it --rm debug-pod --image=curlimages/curl --restart=Never -- sh
   curl -X POST -H "Content-Type: application/json" \
        -d '{"name":"John Doe","email":"john@example.com"}' \
        http://cms-app-service/customers/
   ```
   - **Root Cause**: Local network issue ("Destination host unreachable" via ping 130.213.140.147)

## Testing

### Local Testing
```bash
# Run container locally
docker run -p 8000:8000 \
  --env SQL_SERVER=cms-sql-server2025.database.windows.net \
  --env SQL_DB=cms-db \
  --env SQL_USER=sqladmin \
  --env SQL_PASSWORD=P@ssw0rd123! \
  cms-app:1.0

# Test API
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"John Doe","email":"john@example.com"}' \
     http://localhost:8000/customers/
```

### Cluster Testing
```bash
# Check pod status
kubectl get pods

# Test service
kubectl port-forward svc/cms-app-service 8000:80

# Check ingress
kubectl get ingress

# Test internally via debug pod
kubectl run -it --rm debug-pod --image=curlimages/curl --restart=Never -- sh
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"John Doe","email":"john@example.com"}' \
     http://cms-app-service/customers/
curl http://cms-app-service/customers/
```

## Conclusion

- **Status**: PoC complete—app deployed on AKS, testable internally via debug pod
- **Limitations**: External access to 130.213.140.147 blocked by local network; workaround in place
- **Sign-Off**: "Phase 3 complete—app deployed and tested on AKS (internal access only due to network constraints)"

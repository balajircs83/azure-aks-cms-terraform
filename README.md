# CMS Application Deployment on Azure AKS (Proof of Concept)

This project demonstrates deploying a simple Customer Management System (CMS) application on Azure Kubernetes Service (AKS) using Terraform, Docker, and Helm. It serves as a proof-of-concept (PoC) for learning purposes, covering infrastructure provisioning, app containerization, Helm deployment, and basic troubleshooting.

## Table of Contents
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Infrastructure Components](#infrastructure-components)
- [Application Details](#application-details)
- [Deployment Steps](#deployment-steps)
- [Configuration](#configuration)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Known Limitations](#known-limitations)

## Architecture

### High-Level Components
- **Azure Kubernetes Service (AKS)**: Managed Kubernetes cluster hosting the CMS application
- **Azure Container Registry (ACR)**: Stores Docker images with anonymous pull enabled
- **Azure SQL Database**: Backend database for customer data
- **NGINX Ingress Controller**: External traffic routing
- **Azure Monitor**: Infrastructure monitoring and diagnostics

### Infrastructure Details
#### 1. AKS Cluster
- Name: `cms-aks-cluster`
- Resource Group: `cms-rg-poc`
- Location: East US 2
- Node Pool:
  - Count: 2 nodes
  - VM Size: Standard_D2s_v3
  - Subnet: `aks-subnet` in `cms-vnet`

#### 2. Azure Container Registry
- Name: `cmsacr2025`
- SKU: Standard (for anonymous pull support)
- Image: `cmsacr2025.azurecr.io/cms-app:1.0`

#### 3. Azure SQL Database
- Server: `cms-sql-server2025.database.windows.net`
- Database: `cms-db`
- Authentication: SQL Server authentication

#### 4. Networking
- VNet: `cms-vnet` (10.0.0.0/16)
- AKS Subnet: `aks-subnet` (10.0.1.0/24)
- Service CIDR: 10.1.0.0/16
- DNS Service IP: 10.1.0.10

## Prerequisites
- Azure CLI (latest version)
- Terraform (v1.0.0+)
- Docker Desktop
- Helm v3
- kubectl
- Python 3.9+

## Infrastructure Components

### Resource Tagging
All resources include standard tags:
- Owner Name
- Owner Contact
- PoC Name
- Approver
- Valid Till Date

### Monitoring
- Azure Monitor integration
- Log Analytics workspace
- Diagnostic settings for AKS

## Application Details

### API Endpoints
1. Create Customer (POST `/customers/`)
   ```json
   {
     "name": "string",
     "email": "string"
   }
   ```

2. List Customers (GET `/customers/`)
   ```json
   [
     {
       "name": "string",
       "email": "string"
     }
   ]
   ```

### Technology Stack
- **Backend**: FastAPI (Python 3.9)
- **Database Access**: pyodbc
- **API Documentation**: FastAPI Swagger UI
- **Dependencies**: See requirements.txt for full list

## Deployment Steps

### 1. Infrastructure Deployment
```bash
terraform init
terraform apply -auto-approve
az aks get-credentials --resource-group cms-rg-poc --name cms-aks-cluster
```

### 2. Application Deployment
1. Build and push Docker image
2. Install NGINX Ingress Controller
3. Deploy Helm chart:
   ```bash
   helm install cms-app ./cms-chart
   ```

### 3. Validate Deployment
- Check pod status
- Verify service endpoints
- Test API functionality

## Configuration

### Environment Variables
- SQL_SERVER
- SQL_DB
- SQL_USER
- SQL_PASSWORD

### Helm Values
Customizable via values.yaml:
- Replica count
- Image details
- Service configuration
- Ingress settings

## Troubleshooting Guide

### Common Issues

#### 1. Docker Build Failures
- **Issue**: DPKG errors with ODBC drivers
- **Solution**: Using DEBIAN_FRONTEND=noninteractive and proper package ordering

#### 2. Database Connectivity
- **Issue**: ODBC driver missing
- **Solution**: Included in Dockerfile with proper Microsoft repository setup

#### 3. Image Pull Errors
- **Issue**: ACR authentication
- **Solution**: Enable anonymous pull access for PoC environments

#### 4. Ingress Access
- **Issue**: External endpoint timeouts
- **Solution**: Use debug pod for internal testing

## Known Limitations

1. **Security Considerations**
   - Hardcoded database credentials (PoC only)
   - Anonymous pull enabled on ACR
   - Basic authentication methods

2. **Network Access**
   - Limited to internal cluster access in some network configurations
   - External access may require additional network rules

3. **Monitoring**
   - Basic Azure Monitor integration
   - Limited custom metrics

## Contact

For any queries or support:
- Owner: Sandeep
- Email: sandeepg@newtglobalcorp.com
- Valid Till: March 31, 2025

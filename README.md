
## Project Spring Boot Microservice Logging  - Datadog Specific

This Java Project is designed to expose business metrics and good amount of logs
- Step1: Build the Maven project
`mvn clean install`
- Step 2: Build Docker image or use existing one
  `docker build -t sumanth17121988/springbootmetrics:2`
- Step 3: Run it in Kubernetes
  `kubectl apply -f deployment.yml`
  `kubectl get pods`
  `kubectl get svc`
  
To test this API  : http://localhost:8881/api/json 

### Access Prometheus
- Endpoint: `/actuator/prometheus`
- Example URL: [http://localhost:8881/actuator/prometheus]
- Liveness Probe : http://<ipadress>:8881/actuator/health/liveness
- Readiness Probe : http://<ipadress>:8881/actuator/health/readiness

#### Metrics
- **`api_json_transaction_timer_count`**: Total requests (used for RPS calculation).
- **`api_json_transaction_timer_sum`**: Total duration of requests (in seconds).
- **`api_json_transaction_timer_max`**: Maximum transaction duration.
- **`api.product.views.count`**: Counts product views.


#### Datadog Specific 

# Canary Deployment Guide (Spring Boot + NGINX Ingress + Datadog)

This guide explains how to deploy a **Spring Boot application** with a **canary release strategy** using **NGINX Ingress**.  
We deploy two versions of the app (v1 = stable, v2 = canary) and send a small % of traffic to v2.  
Datadog is used to monitor latency, errors, and version tags.

---

## 1. Setup Ingress Controller

```bash
kubectl create namespace ingress-basic

# Add the official stable repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# View default values
helm show values ingress-nginx/ingress-nginx

# Install ingress-nginx with 2 replicas
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-basic \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.publishService.enabled=true
```

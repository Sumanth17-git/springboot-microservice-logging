
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

kubectl get pods,svc -n ingress-basic
You’ll see:
•	2 ingress-nginx-controller pods
•	A LoadBalancer service with an EXTERNAL-IP

# List Services with labels
kubectl get service -l app.kubernetes.io/name=ingress-nginx --namespace ingress-basic

# List Pods
kubectl get pods -n ingress-basic
kubectl get all -n ingress-basic
# Access Public IP
http://<Public-IP-created-for-Ingress>
# Output should be
404 Not Found from Nginx

```
Step1: Deploy the Application and use ClusterIP for your service
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app
  labels:
    app: springboot-app
    tags.datadoghq.com/env: dev
    tags.datadoghq.com/service: java-service
    tags.datadoghq.com/version: "0.0.1"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: springboot-app
      tags.datadoghq.com/service: java-service
      tags.datadoghq.com/env: dev
      tags.datadoghq.com/version: "0.0.1"
  template:
    metadata:
      labels:
        app: springboot-app
        tags.datadoghq.com/env: dev
        tags.datadoghq.com/service: java-service
        tags.datadoghq.com/version: "0.0.1"
        admission.datadoghq.com/enabled: "true"
      annotations:
        # Auto-inject the Datadog Java tracer
        admission.datadoghq.com/enabled: "true"
        admission.datadoghq.com/java-lib.version: "v1.50.0"
        # Point tracer at node's Agent
        admission.datadoghq.com/config.mode: "hostip"
        # Collect stdout/stderr as logs for THIS container
        ad.datadoghq.com/java-service.logs: >-
          [{"source":"java","service":"java-service","auto_multi_line_detection": true}]
    spec:
      containers:
        - name: springboot-app
          image: sumanth17121988/springbootmetric:1
          imagePullPolicy: IfNotPresent
          ports:
            - name: metrics-port
              containerPort: 8881
          env:
            # JVM Heap settings
            - name: JAVA_OPTS
              value: "-Xms256m -Xmx700m"

            # Unified service tags
            - name: DD_ENV
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/env']
            - name: DD_SERVICE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/service']
            - name: DD_VERSION
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/version']

            # Tracing, profiling, DI, JMX, AppSec
            - name: DD_TRACE_SAMPLE_RATE
              value: "1"
            - name: DD_TRACE_HEALTH_METRICS_ENABLED
              value: "true"
            - name: DD_LOGS_INJECTION
              value: "true"
            - name: DD_PROFILING_ENABLED
              value: "true"
            - name: DD_DYNAMIC_INSTRUMENTATION_ENABLED
              value: "true"
            - name: DD_JMXFETCH_ENABLED
              value: "true"
            - name: DD_APPSEC_ENABLED
              value: "true"
            - name: DD_IAST_ENABLED
              value: "true"
            - name: DD_APPSEC_SCA_ENABLED
              value: "true"
            - name: DD_PROFILING_DDPROF_LIVEHEAP_ENABLED
              value: "true"
            - name: DD_PROFILING_HEAP_ENABLED
              value: "true"
            - name: DD_PROFILING_DIRECTALLOCATION_ENABLED
              value: "true"
            # Optional: global tags (maps to dd.tags)
            - name: DD_TAGS
              value: "app-name:java-service,team:devops"
            # Tracer -> node Agent (DaemonSet) on 8126
            - name: DD_AGENT_HOST
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            - name: DD_TRACE_AGENT_URL
              value: "http://$(DD_AGENT_HOST):8126"
---
apiVersion: v1
kind: Service
metadata:
  name: springboot-app-service
  labels:
    app: springboot-app
spec:
  type: ClusterIP
  selector:
    app: springboot-app
    tags.datadoghq.com/service: java-service
  ports:
    - name: metrics-port
      protocol: TCP
      port: 80
      targetPort: 8881

```
After deploying the services , Now it is time to start the ingress by mapping the springboot-service using context path rule.
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-springboot
  annotations:
    #kubernetes.io/ingress.class: nginx
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: springboot-app-service
                port:
                  number: 80
```
```bash
root@ip-172-31-30-194:/home/ubuntu/springboot-microservice-logging# kubectl get ingress
NAME                    CLASS   HOSTS   ADDRESS                                                                   PORTS   AGE
ingress-springboot      nginx   *       a58b5dd9bbb2843fb81963ad250add5c-2049422652.us-east-1.elb.amazonaws.com   80      62m
```
<img width="940" height="208" alt="image" src="https://github.com/user-attachments/assets/8ef800f7-91b3-4c1c-9b80-f964b64633ec" />

You can see the ingress is successfully mapped the application service , test it using ingress LB URL .This is working fine.

Now it is time to implement the Canary based deployment.

Release new version to a small percentage of users first (e.g., 5% or 10%). If it works well, gradually roll out to more.  
Just like the canary in the coal mine—you check if the environment is safe before sending everyone in.  

✅ Example:  
• v1 is live to 100%.  
• Deploy v2 alongside it.  
• Send 10% traffic to v2 (canary), 90% to v1.  
• Monitor logs, metrics, errors, etc.  
• Gradually increase to 25%, 50%, 100% (full rollout).  
• If something breaks, just kill v2 and go back to 100% v1.  

<img width="657" height="464" alt="image" src="https://github.com/user-attachments/assets/a121c2b3-a26f-4354-96ed-3580da79108e" />

🔧 How Canary Works (in Kubernetes)

Here’s how it works behind the scenes:  

🧱 You have:  
• Two Deployments: v1 (stable), v2 (canary)  
• Two Services: routing traffic to each deployment  
• Ingress: decides how to split traffic  

🎯 Traffic splitting:  
Using NGINX ingress annotations like:  
```yaml
annotations:
  nginx.ingress.kubernetes.io/canary: "true"
  nginx.ingress.kubernetes.io/canary-weight: "10"
```
This tells NGINX:  
Route 90% of requests to the stable version, and 10% to the canary version.  

You can also split based on:  
• Weight (percentage)  
• Header (e.g., only users with X-User-Type: beta)  
• Cookie (target beta users)  

```bash
Now modify the Springboot code as below 
    @GetMapping("/json")
    public Map<String, Object> getJsonResponse() {
        // Measure transaction duration
        return transactionTimer.record(() -> {
            requestCounter.increment();

    **    // 🚨 add fixed delay for v2
        try {
            Thread.sleep(2000); // 2 seconds
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }**

            Map<String, Object> response = new HashMap<>();
            response.put("message", "Hello, World!");
            response.put("status", "success");
        **    response.put("version", "v2");  // <-- mark this as v2**
            response.put("data", getSampleUserData());
            response.put("products", getSampleProductData());

            try {
                String jsonResponse = objectMapper.writeValueAsString(response);
                logger.info("JSON Response (v2): {}", jsonResponse);
            } catch (Exception e) {
                logger.error("Error converting response to JSON", e);
            }
            return response;
        });
```
Rebuild the Java code using mvn clean install
Update the Dockerfile as below
```yaml
FROM eclipse-temurin:17.0.12_7-jdk-jammy
WORKDIR /usr/app
ADD target/*.jar app.jar
RUN apt-get update && apt-get install -y procps && rm -rf /var/lib/apt/lists/*
ENV DD_SERVICE="java-service" \
    DD_ENV="dev" \
    DD_VERSION="0.0.2" \
    DD_LOGS_INJECTION="true" \
    DD_DYNAMIC_INSTRUMENTATION_ENABLED="true"
# Optional: source-code integration (set from CI)
ARG COMMIT_SHA=""
ENV DD_GIT_COMMIT_SHA="${COMMIT_SHA}"
ENV DD_GIT_REPOSITORY_URL="https://github.com/Sumanth17-git/springboot-microservice-logging.git"
ENV JAVA_OPTS=""
EXPOSE 8881
ENTRYPOINT exec java ${JAVA_OPTS} -jar app.jar
```
Update the Kubernetes Deployment file  as per v0.0.2
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-app-v2
  labels:
    app: springboot-app-v2
    tags.datadoghq.com/env: dev
    tags.datadoghq.com/service: java-service
    tags.datadoghq.com/version: "0.0.2"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: springboot-app-v2
      tags.datadoghq.com/service: java-service
      tags.datadoghq.com/env: dev
      tags.datadoghq.com/version: "0.0.2"
  template:
    metadata:
      labels:
        app: springboot-app-v2
        tags.datadoghq.com/env: dev
        tags.datadoghq.com/service: java-service
        tags.datadoghq.com/version: "0.0.2"
        admission.datadoghq.com/enabled: "true"
      annotations:
        # Auto-inject the Datadog Java tracer
        admission.datadoghq.com/enabled: "true"
        admission.datadoghq.com/java-lib.version: "v1.50.0"
        # Point tracer at node's Agent
        admission.datadoghq.com/config.mode: "hostip"
        # Collect stdout/stderr as logs for THIS container
        ad.datadoghq.com/java-service.logs: >-
          [{"source":"java","service":"java-service","auto_multi_line_detection": true}]
    spec:
      containers:
        - name: springboot-app-v2
          image: sumanth17121988/springbootmetric:2
          imagePullPolicy: IfNotPresent
          ports:
            - name: metrics-port
              containerPort: 8881
          env:
            # JVM Heap settings
            - name: JAVA_OPTS
              value: "-Xms256m -Xmx700m"

            # Unified service tags
            - name: DD_ENV
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/env']
            - name: DD_SERVICE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/service']
            - name: DD_VERSION
              valueFrom:
                fieldRef:
                  fieldPath: metadata.labels['tags.datadoghq.com/version']

            # Tracing, profiling, DI, JMX, AppSec
            - name: DD_TRACE_SAMPLE_RATE
              value: "1"
            - name: DD_TRACE_HEALTH_METRICS_ENABLED
              value: "true"
            - name: DD_LOGS_INJECTION
              value: "true"
            - name: DD_PROFILING_ENABLED
              value: "true"
            - name: DD_DYNAMIC_INSTRUMENTATION_ENABLED
              value: "true"
            - name: DD_JMXFETCH_ENABLED
              value: "true"
            - name: DD_APPSEC_ENABLED
              value: "true"
            - name: DD_IAST_ENABLED
              value: "true"
            - name: DD_APPSEC_SCA_ENABLED
              value: "true"
            - name: DD_PROFILING_DDPROF_LIVEHEAP_ENABLED
              value: "true"
            - name: DD_PROFILING_HEAP_ENABLED
              value: "true"
            - name: DD_PROFILING_DIRECTALLOCATION_ENABLED
              value: "true"
            # Optional: global tags (maps to dd.tags)
            - name: DD_TAGS
              value: "app-name:java-service,team:devops"
            # Tracer -> node Agent (DaemonSet) on 8126
            - name: DD_AGENT_HOST
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
            - name: DD_TRACE_AGENT_URL
              value: "http://$(DD_AGENT_HOST):8126"
---
apiVersion: v1
kind: Service
metadata:
  name: springboot-app-service-v2
  labels:
    app: springboot-app-v2
spec:
  type: ClusterIP
  selector:
    app: springboot-app-v2
    tags.datadoghq.com/service: java-service
  ports:
    - name: metrics-port
      protocol: TCP
      port: 80
      targetPort: 8881
```

Once the v2 application is deployed , validate it internal without exposing to Public traffic , Once all verified. Lets switch the traffic gradually,we will start with 50%
Create ingress-canary.context.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: spring-ingress-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "50"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: springboot-app-service-v2
                port:
                  number: 80

```
<img width="940" height="51" alt="image" src="https://github.com/user-attachments/assets/c3ea3191-5907-4a27-8628-50bde1cd7156" />

Simulate the High Load Traffic 
**Monitor it from Datadog**

Mapping also working fine. Lets simulate the traffic to check whether the new version is working as expected without degrading performance.  
From Datadog Console – Go to **Services** → open **service** → Check **Deployments** screen to see the overall version performance, like which version is providing less performance.  
<img width="940" height="409" alt="image" src="https://github.com/user-attachments/assets/358b8085-bdcf-4e8c-85fd-69d7e37d5986" />

V0.0.2 is having high latency , something is not good there.
Let’s find what went wrong in version 2. Go to profile explorer  Comparison
<img width="940" height="471" alt="image" src="https://github.com/user-attachments/assets/d2a6f1a5-d57a-4bab-918b-78e7f586d8dc" />



<img width="940" height="409" alt="image" src="https://github.com/user-attachments/assets/418a7fb9-89d8-418d-861e-52d2f5e56257" />


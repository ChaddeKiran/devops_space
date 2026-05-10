# BookMyCar EKS Deployment (Simple LoadBalancer DNS)

This setup is simplified for a college project:
- no purchased domain
- no Route53
- no ACM certificate
- no Ingress
- no External Secrets

You will access the app using AWS LoadBalancer DNS.

## 1) Prerequisites

- EKS cluster is running
- `kubectl` is connected to the cluster
- EBS CSI driver is installed (required for MySQL PVC)

Check:

```bash
kubectl get nodes
kubectl get storageclass
```

## 2) Apply manifests

From `BookMyCar/k8s`, run:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f mysql-deploy.yaml
kubectl apply -f backend-configmap.yaml
kubectl apply -f backend-secret.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f backend-hpa.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-hpa.yaml
```

## 3) Wait for pods and services

```bash
kubectl get pods -n prod -w
kubectl get svc -n prod
```

## 4) Get frontend LoadBalancer DNS

`frontend-deployment.yaml` contains frontend service type `LoadBalancer`.

Run:

```bash
kubectl get svc -n prod bookmycar-frontend
```

Open the `EXTERNAL-IP` value in browser (this is AWS DNS name).

Example:
- `http://a1b2c3d4e5f6g7.elb.ap-south-1.amazonaws.com`

## 5) Optional: backend public DNS

By default backend service is internal (`ClusterIP`), which is best for this app.
Frontend calls backend internally via Nginx `/api` proxy.

If you want backend public URL also, change `backend-service.yaml` type to `LoadBalancer` and re-apply:

```bash
kubectl apply -f backend-service.yaml
kubectl get svc -n prod bookmycar-backend
```

## 6) Scaling pods (load increases and load-testing reports)

**Prerequisite:** CPU-based Horizontal Pod Autoscaler needs **metrics** in the cluster.

- On EKS, install **Metrics Server** if `kubectl top pods` fails (HPA needs pod CPU metrics).
  - Add it from the official Kubernetes Metrics Server manifests or follow the AWS EKS user guide for your cluster version.

Verify:

```bash
kubectl top nodes
kubectl top pods -n prod
```

### Automatic scaling (already configured)

| Workload | File | Behaviour |
|---------|------|-----------|
| Backend | `backend-hpa.yaml` | Scales **2–10** pods when average CPU crosses **70%** of requested CPU |
| Frontend | `frontend-hpa.yaml` | Scales **2–8** pods when average CPU crosses **70%** of requested CPU |

Watch autoscaling:

```bash
kubectl get hpa -n prod -w
kubectl get deploy -n prod
```

HPA adjusts replica counts. Do not hand-edit `replicas:` in YAML while HPA owns the Deployment (kubectl will show a note that HPA is managing replicas).

Tune for heavier tests (edit YAML and re-apply):

- Raise `maxReplicas` (for example backend `20`, frontend `15`).
- Lower `averageUtilization` (for example `50`) to scale out sooner under the same CPU request.

### Manual scaling (fixed pod count for a load-test report)

To force a fixed number of pods for repeatable tests, **temporarily delete** or **suspend** HPA:

```bash
kubectl delete hpa -n prod bookmycar-backend-hpa bookmycar-frontend-hpa
kubectl scale deployment/bookmycar-backend -n prod --replicas=5
kubectl scale deployment/bookmycar-frontend -n prod --replicas=4
```

After the test, re-apply autoscaler manifests:

```bash
kubectl apply -f backend-hpa.yaml
kubectl apply -f frontend-hpa.yaml
```

### Evidence for your report

- Before/after screenshots or terminal output of `kubectl get hpa -n prod` and `kubectl get pods -n prod` showing replica increases.
- `kubectl describe hpa bookmycar-backend-hpa -n prod` (events show scale-up reasons).
- Optional: Grafana/CloudWatch graphs if you add them later.

## 7) Troubleshooting

```bash
kubectl get all -n prod
kubectl logs -n prod deploy/bookmycar-backend
kubectl logs -n prod deploy/bookmycar-frontend
kubectl logs -n prod deploy/mysql
```

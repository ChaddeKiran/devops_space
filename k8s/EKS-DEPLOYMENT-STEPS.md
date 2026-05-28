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

## 2) Deployment order (important)

Follow this exact order:

1. Namespace
2. MySQL (Secret + Service + Deployment + PVC)
3. Wait for MySQL to be healthy
4. Create schema and load data in MySQL
5. Backend (ConfigMap + Secret + Deployment + Service + HPA)
6. Wait for backend to be healthy
7. Frontend (Deployment/Service + HPA)

This order ensures backend starts only after database is ready with schema/data.

## 3) Apply namespace and MySQL first

From `devops_space/k8s`, run:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f mysql-deploy.yaml
kubectl get pods -n prod -w
```

Wait until MySQL pod shows `Running` and `1/1`.

You can also verify rollout:

```bash
kubectl rollout status deployment/mysql -n prod
```

## 4) Initialize database schema and data (before backend)

Copy your SQL files into MySQL pod, then execute them in order:

```bash
# Set pod name
MYSQL_POD=$(kubectl get pod -n prod -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo "$MYSQL_POD"

# Copy SQL files from local machine to pod
kubectl cp ./init-schema.sql prod/${MYSQL_POD}:/tmp/init-schema.sql
kubectl cp ./data.sql prod/${MYSQL_POD}:/tmp/data.sql

# Run schema first, then data
kubectl exec -n prod -i ${MYSQL_POD} -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" bookmycar_db < /tmp/init-schema.sql'
kubectl exec -n prod -i ${MYSQL_POD} -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" bookmycar_db < /tmp/data.sql'
```

Quick validation:

```bash
kubectl exec -n prod -it ${MYSQL_POD} -- mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE bookmycar_db; SHOW TABLES;"
```

If `kubectl cp` fails with `one of src or dest must be a remote file specification`, it usually means `MYSQL_POD` is empty. Re-run `echo "$MYSQL_POD"` and confirm it prints a pod name.

Alternative (no `kubectl cp` needed):

```bash
kubectl exec -n prod -i ${MYSQL_POD} -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" bookmycar_db' < init-schema.sql
kubectl exec -n prod -i ${MYSQL_POD} -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" bookmycar_db' < data.sql
```

If your data file is named differently (for example `data.txt`), replace `data.sql` in the commands.

Verify app DB user (same as `backend-secret.yaml`):

```bash
kubectl exec -n prod -i ${MYSQL_POD} -- sh -c 'mysql -u db_user -pdb_password -e "USE bookmycar_db; SHOW TABLES;"'
```

## 5) Deploy backend only after DB init

```bash
kubectl apply -f backend-configmap.yaml
kubectl apply -f backend-secret.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f backend-hpa.yaml
kubectl rollout status deployment/bookmycar-backend -n prod
kubectl get pods -n prod -l app=bookmycar-backend
kubectl logs -n prod deploy/bookmycar-backend --tail=100
```

Proceed only if backend logs do not show SQL connection errors and pods are `1/1 Running`.

## 6) Deploy frontend after backend is healthy

```bash
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-hpa.yaml
kubectl rollout status deployment/bookmycar-frontend -n prod
kubectl get svc -n prod bookmycar-frontend
```

Open `bookmycar-frontend` `EXTERNAL-IP`/LoadBalancer DNS in browser.

Example:
- `http://a1b2c3d4e5f6g7.elb.ap-south-1.amazonaws.com`

## 7) Optional: backend public DNS

By default backend service is internal (`ClusterIP`), which is best for this app.
Frontend calls backend internally via Nginx `/api` proxy.

If you want backend public URL also, change `backend-service.yaml` type to `LoadBalancer` and re-apply:

```bash
kubectl apply -f backend-service.yaml
kubectl get svc -n prod bookmycar-backend
```

## 8) Scaling pods (load increases and load-testing reports)

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

## 9) Troubleshooting

### Backend pod keeps restarting (`CrashLoopBackOff` / not `1/1`)

Check why the container failed:

```bash
kubectl get pods -n prod -l app=bookmycar-backend
kubectl describe pod -n prod -l app=bookmycar-backend | tail -40
kubectl logs -n prod -l app=bookmycar-backend --tail=200
kubectl logs -n prod -l app=bookmycar-backend --previous --tail=200
```

Common causes and fixes:

| Symptom in logs / events | Fix |
|--------------------------|-----|
| `OOMKilled` | Increase backend memory in `backend-deployment.yaml` (use at least `512Mi` request, `768Mi` limit) |
| `Liveness probe failed` / app killed before startup | Use `startupProbe` and higher `livenessProbe.initialDelaySeconds` (already in updated manifest) |
| `Public Key Retrieval is not allowed` / auth errors | JDBC URL must include `allowPublicKeyRetrieval=true` (see `backend-configmap.yaml`) |
| `Access denied for user 'db_user'` | Re-run DB user check; credentials must match `mysql-credentials` and `backend-secret.yaml` |
| `Table doesn't exist` | Run `init-schema.sql` before `data.sql` |

After updating manifests on the server:

```bash
kubectl apply -f backend-configmap.yaml
kubectl apply -f backend-deployment.yaml
kubectl rollout restart deployment/bookmycar-backend -n prod
```

### General checks

```bash
kubectl get all -n prod
kubectl logs -n prod deploy/bookmycar-backend
kubectl logs -n prod deploy/bookmycar-frontend
kubectl logs -n prod deploy/mysql
```

Optional MySQL checks:

```bash
MYSQL_POD=$(kubectl get pod -n prod -l app=mysql -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n prod -it ${MYSQL_POD} -- sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "USE bookmycar_db; SHOW TABLES;"'
kubectl exec -n prod -it ${MYSQL_POD} -- sh -c 'mysql -u db_user -pdb_password -e "USE bookmycar_db; SELECT COUNT(*) FROM users;"'
```

# ORISO-Matrix Deployment Guide

## 🎯 Complete Deployment from Scratch

This guide will help you deploy the entire Matrix infrastructure on a new server.

## Prerequisites

### System Requirements
- **OS:** Ubuntu 20.04+ or similar Linux
- **RAM:** Minimum 4GB (8GB recommended for production)
- **CPU:** 2+ cores
- **Storage:** 50GB+ (grows with message history)
- **Kubernetes:** k3s or similar

### Network Requirements
- **Port 8008:** Matrix Client API (HTTP)
- **Port 8009:** Matrix Federation API (HTTP)
- **Port 5432:** PostgreSQL (internal only)
- **Firewall:** Open ports 8008, 8009 for external access

### Dependencies
- Kubernetes cluster running
- `kubectl` configured
- Persistent storage available

---

## 🚀 Step 1: Deploy PostgreSQL Database

### 1.1 Create Persistent Volume Claims
```bash
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix

# Apply PVCs
kubectl apply -f matrix-pvcs.yaml

# Verify
kubectl get pvc -n caritas | grep matrix
```

**Expected Output:**
```
matrix-postgres-data   Bound    pvc-xxxxx   10Gi       RWO
```

### 1.2 Deploy PostgreSQL StatefulSet
```bash
# Deploy PostgreSQL
kubectl apply -f matrix-postgres-statefulset.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/matrix-postgres-0 -n caritas --timeout=180s

# Check status
kubectl get pod matrix-postgres-0 -n caritas
```

**Expected Output:**
```
NAME                 READY   STATUS    RESTARTS   AGE
matrix-postgres-0    1/1     Running   0          2m
```

### 1.3 Initialize Database
```bash
# Test connection
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT 1;"

# Import schema
kubectl exec -i matrix-postgres-0 -n caritas -- psql -U synapse_user synapse < database/matrix-schema-current.sql

# Verify tables
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "\dt" | head -20
```

**Expected Output:**
Should list Matrix tables like: `users`, `rooms`, `events`, `devices`, etc.

---

## 🚀 Step 2: Deploy Matrix Synapse

### 2.1 Apply ConfigMaps
```bash
# Apply Synapse configuration
kubectl apply -f matrix-configmaps.yaml

# Verify
kubectl get configmap -n caritas | grep matrix
```

**Expected Output:**
```
matrix-homeserver-oidc    1      1m
matrix-log-config         1      1m
```

### 2.2 Apply Secrets
```bash
# Apply secrets (passwords, keys)
kubectl apply -f matrix-secrets.yaml

# Verify (don't display values)
kubectl get secrets -n caritas | grep matrix
```

### 2.3 Deploy Services
```bash
# Create Kubernetes services
kubectl apply -f matrix-services.yaml

# Verify
kubectl get svc -n caritas | grep matrix
```

**Expected Output:**
```
matrix-synapse           ClusterIP   10.43.x.x    <none>   8008/TCP,8009/TCP   1m
matrix-postgres-service  ClusterIP   10.43.x.x    <none>   5432/TCP            1m
```

### 2.4 Deploy Synapse
```bash
# Deploy Matrix Synapse
kubectl apply -f matrix-synapse-deployment.yaml

# Watch deployment
kubectl get pods -n caritas -l app=matrix-synapse -w

# Check logs
kubectl logs -n caritas -l app=matrix-synapse --tail=50
```

**Expected Output:**
```
Synapse now listening on port 8008
```

### 2.5 Test Synapse
```bash
# Test from inside cluster
kubectl run test-pod --rm -it --image=curlimages/curl --restart=Never -- curl http://matrix-synapse:8008/_matrix/client/versions

# Test from host
curl http://91.99.219.182:8008/_matrix/client/versions
```

**Expected Output:**
```json
{
  "versions": ["r0.0.1", "r0.1.0", "r0.2.0", ...]
}
```

---

## 🚀 Step 3: Deploy Discovery Service

```bash
# Deploy Matrix Discovery
kubectl apply -f matrix-discovery-deployment.yaml

# Verify
kubectl get pods -n caritas -l app=matrix-discovery

# Test
curl http://91.99.219.182/.well-known/matrix/server
```

**Expected Output:**
```json
{
  "m.server": "caritas.local:8448"
}
```

---

## 🚀 Step 4: Setup Automated Backups

```bash
# Deploy CronJobs
kubectl apply -f matrix-cronjobs.yaml

# Verify
kubectl get cronjobs -n caritas
```

**Expected Output:**
```
NAME                     SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
matrix-postgres-backup   0 2 * * *     False     0        <none>          1m
```

---

## 🔧 Step 5: Integration with ORISO Services

### 5.1 Backend Integration (ORISO-UserService)

**Location:** `ORISO-UserService/src/main/resources/application-local.properties`

**Required Configuration:**
```properties
# Matrix Synapse connection
matrix.synapse.url=http://matrix-synapse:8008
matrix.synapse.admin.token=caritas-registration-secret-2025
matrix.synapse.server.name=caritas.local

# Database (stores Matrix credentials)
spring.datasource.url=jdbc:mariadb://localhost:3306/userservice
```

**How it works:**
1. User registers → UserService creates Matrix account via admin API
2. Matrix credentials stored in `user` table:
   - `matrix_user_id` (e.g., `@user123:caritas.local`)
   - `matrix_password` (encrypted)
3. Credentials returned to frontend on login

### 5.2 Frontend Integration (ORISO-Frontend)

**Location:** `ORISO-Frontend/.env`

**Required Configuration:**
```bash
# Matrix homeserver
VITE_MATRIX_HOMESERVER_URL=http://91.99.219.182:8008
VITE_MATRIX_SERVER_NAME=caritas.local

# TURN server for calls (optional)
VITE_TURN_SERVER_URL=turn:91.99.219.182:3478
VITE_TURN_USERNAME=caritas
VITE_TURN_PASSWORD=your-turn-password
```

**Frontend Files:**
- `src/services/matrixClientService.ts` - Matrix SDK initialization
- `src/services/matrixCallService.ts` - Call handling
- `src/services/matrixLiveEventBridge.ts` - Real-time events
- `src/components/matrixCall/MatrixCallView.tsx` - Call UI

### 5.3 Element.io Client (ORISO-Element)

**Element is the web UI for Matrix.**

**Configuration:** `ORISO-Element/config.json`
```json
{
  "default_server_config": {
    "m.homeserver": {
      "base_url": "http://91.99.219.182:8008",
      "server_name": "caritas.local"
    }
  }
}
```

**Access:** http://91.99.219.182:8087

---

## 🔧 Step 6: Post-Deployment Verification

### 6.1 Check All Pods
```bash
kubectl get pods -n caritas | grep matrix
```

**Expected Output:**
```
matrix-synapse-xxxxxx       1/1     Running   0          5m
matrix-postgres-0           1/1     Running   0          10m
matrix-discovery-xxxxxx     1/1     Running   0          3m
```

### 6.2 Check All Services
```bash
kubectl get svc -n caritas | grep matrix
```

**Expected Output:**
```
matrix-synapse           ClusterIP   10.43.x.x    <none>   8008/TCP,8009/TCP   10m
matrix-postgres-service  ClusterIP   10.43.x.x    <none>   5432/TCP            10m
```

### 6.3 Test Matrix API
```bash
# Client API
curl http://91.99.219.182:8008/_matrix/client/versions

# Federation API
curl http://91.99.219.182:8009/_matrix/federation/v1/version

# Discovery
curl http://91.99.219.182/.well-known/matrix/server
```

### 6.4 Test Database
```bash
# Connect to database
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse

# Run queries
\dt                         # List tables
SELECT COUNT(*) FROM users; # Count users
SELECT COUNT(*) FROM rooms; # Count rooms
\q                          # Quit
```

### 6.5 Test User Creation
```bash
# Create test user via shared secret
curl -X POST "http://91.99.219.182:8008/_synapse/admin/v1/register" \
  -H "Content-Type: application/json" \
  -d '{
    "nonce": "unused",
    "username": "testuser",
    "displayname": "Test User",
    "password": "testpassword123",
    "admin": false,
    "mac": "not_required_with_shared_secret"
  }'
```

---

## 🔐 Security Hardening

### 1. Disable Open Registration
Edit `matrix-configmaps.yaml` → `homeserver.yaml`:
```yaml
enable_registration: false
```

### 2. Setup HTTPS
Use Nginx to proxy Matrix behind HTTPS:
```nginx
server {
    listen 443 ssl;
    server_name matrix.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://91.99.219.182:8008;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 3. Change Database Password
```bash
# Connect to PostgreSQL
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse

# Change password
ALTER USER synapse_user WITH PASSWORD 'new-secure-password';
\q

# Update secret
kubectl edit secret matrix-postgres-secret -n caritas
```

### 4. Rotate Registration Secret
```bash
# Edit ConfigMap
kubectl edit configmap matrix-homeserver-oidc -n caritas

# Change registration_shared_secret
# Save and restart Synapse
kubectl rollout restart deployment/matrix-synapse -n caritas
```

---

## 📊 Monitoring & Maintenance

### Daily Checks
```bash
# Check pod health
kubectl get pods -n caritas | grep matrix

# Check recent logs
kubectl logs -n caritas -l app=matrix-synapse --tail=50

# Check database size
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT pg_size_pretty(pg_database_size('synapse'));"
```

### Weekly Maintenance
```bash
# Vacuum database
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "VACUUM ANALYZE;"

# Check backup status
kubectl get cronjobs -n caritas

# Test restore backup (on test system)
kubectl exec -i matrix-postgres-0 -n caritas -- psql -U synapse_user synapse < backup-test.sql
```

### Monthly Audits
- Review user list for inactive accounts
- Check media storage size
- Audit federation connections
- Review and rotate secrets

---

## 🐛 Troubleshooting

### Problem: Synapse Won't Start

**Symptoms:**
```bash
kubectl logs -n caritas -l app=matrix-synapse
# Error: database connection failed
```

**Solution:**
```bash
# Check database is running
kubectl get pod matrix-postgres-0 -n caritas

# Test connection
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT 1;"

# Check ConfigMap
kubectl get configmap matrix-homeserver-oidc -n caritas -o yaml | grep database

# Restart Synapse
kubectl rollout restart deployment/matrix-synapse -n caritas
```

### Problem: Can't Register Users

**Symptoms:**
Registration API returns 403 Forbidden.

**Solution:**
```bash
# Check registration_shared_secret
kubectl get configmap matrix-homeserver-oidc -n caritas -o yaml | grep registration_shared_secret

# Verify it matches the value used in API calls
# Restart Synapse if changed
kubectl rollout restart deployment/matrix-synapse -n caritas
```

### Problem: Database Full

**Symptoms:**
```bash
kubectl logs -n caritas matrix-postgres-0
# Error: disk full
```

**Solution:**
```bash
# Check disk usage
kubectl exec matrix-postgres-0 -n caritas -- df -h

# Clean old events (risky!)
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "DELETE FROM events WHERE received_ts < extract(epoch from now() - interval '90 days') * 1000;"

# Or expand PVC (if supported by storage class)
kubectl edit pvc matrix-postgres-data -n caritas
```

### Problem: Federation Not Working

**Symptoms:**
Can't connect to other Matrix servers.

**Solution:**
```bash
# Check discovery service
kubectl logs -n caritas -l app=matrix-discovery

# Test well-known
curl http://91.99.219.182/.well-known/matrix/server

# Check federation API
curl http://91.99.219.182:8009/_matrix/federation/v1/version

# Verify DNS (if using domain)
dig _matrix._tcp.example.com SRV
```

---

## 📦 Migration from Old Setup

If migrating from an existing Matrix setup:

### 1. Export Data
```bash
# From old server
pg_dump -U synapse_user synapse > matrix-old-export.sql
tar -czf media_store-old.tar.gz /path/to/media_store/
```

### 2. Import to New Setup
```bash
# Database
kubectl exec -i matrix-postgres-0 -n caritas -- psql -U synapse_user synapse < matrix-old-export.sql

# Media files (copy to persistent volume)
kubectl cp media_store-old.tar.gz caritas/matrix-synapse-xxxxx:/data/
kubectl exec -n caritas matrix-synapse-xxxxx -- tar -xzf /data/media_store-old.tar.gz -C /data/
```

### 3. Update Configuration
- Change server_name if needed
- Update database connection strings
- Verify secrets are migrated

---

## ✅ Deployment Checklist

- [ ] PostgreSQL deployed and healthy
- [ ] Database schema imported
- [ ] ConfigMaps applied
- [ ] Secrets applied
- [ ] Synapse deployed and healthy
- [ ] Discovery service deployed
- [ ] Services accessible (8008, 8009)
- [ ] Test user creation works
- [ ] Backend integration configured
- [ ] Frontend integration configured
- [ ] Element.io client configured
- [ ] Backups configured (CronJobs)
- [ ] Monitoring setup
- [ ] HTTPS configured (production)
- [ ] Documentation updated

---

## 📚 Additional Resources

- **Matrix Synapse Admin API:** https://matrix-org.github.io/synapse/latest/usage/administration/admin_api/
- **Database Schema:** https://github.com/matrix-org/synapse/tree/develop/synapse/storage/schema
- **Troubleshooting:** https://matrix-org.github.io/synapse/latest/usage/administration/

---

**Status:** Production Ready ✅  
**Last Updated:** October 31, 2025  
**Maintainer:** ORISO Team


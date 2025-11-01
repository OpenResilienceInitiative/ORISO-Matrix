# ORISO-Matrix

## Overview
Complete Matrix Synapse chat and communication infrastructure for the ORISO platform. Provides real-time messaging, voice/video calls, and room-based communication using the Matrix protocol.

## 🎯 What is Matrix?
Matrix is an open standard for decentralized, real-time communication. It powers:
- **Real-time chat** between users and consultants
- **Voice/Video calls** via WebRTC
- **End-to-end encryption** for secure messaging
- **Federation** to connect with other Matrix servers

## 📦 Components

### 1. Matrix Synapse (Homeserver)
The core Matrix server handling all chat operations.

**Current Status:** ✅ Running  
**Deployment:** `matrix-synapse-deployment.yaml`  
**Image:** `matrixdotorg/synapse:latest`  
**Ports:**  
- 8008: Client API (HTTP)
- 8009: Federation API

**External Access:** http://91.99.219.182:8008

### 2. Matrix PostgreSQL Database
Persistent storage for all Matrix data (users, rooms, messages, events).

**Current Status:** ✅ Running  
**StatefulSet:** `matrix-postgres-statefulset.yaml`  
**Database:** `synapse`  
**User:** `synapse_user`  
**Port:** 5432

**Schema:** `database/matrix-schema-current.sql`

### 3. Matrix Discovery Service
Handles `.well-known` federation discovery for Matrix.

**Current Status:** ✅ Running  
**Deployment:** `matrix-discovery-deployment.yaml`  
**Purpose:** Enables other Matrix servers to find this homeserver

### 4. Matrix Backup CronJobs
Automated database backups.

**Current Status:** ✅ Running  
**Schedule:** Daily backups  
**CronJobs:** `matrix-cronjobs.yaml`

## 🔌 Integration

### Frontend Integration (ORISO-Frontend)
**Location:** `ORISO-Frontend/src/services/matrix*.ts`

**Services:**
- `matrixClientService.ts` - Matrix SDK client initialization
- `matrixCallService.ts` - Voice/Video call handling
- `matrixLiveEventBridge.ts` - Real-time event bridge
- `matrixRegistrationService.ts` - User registration

**Components:**
- `components/matrixCall/*` - Call UI
- `components/call/FloatingCallWidget.tsx` - Incoming call widget

**How it works:**
1. User logs in → Frontend retrieves Matrix credentials from localStorage
2. Matrix SDK initializes connection to homeserver (91.99.219.182:8008)
3. Real-time sync begins for messages and events
4. WebRTC calls initiated via Matrix SDK

### Backend Integration (ORISO-UserService)
**Location:** `ORISO-UserService/src/main/java/.../adapters/matrix/`

**Services:**
- `MatrixSynapseService.java` - Matrix API client
- User creation, room creation, invitations

**How it works:**
1. User registers in Caritas → UserService creates Matrix account
2. Consultant assigned → UserService creates Matrix room
3. Both users invited to room for secure chat
4. Matrix credentials stored in MariaDB `user` table:
   - `matrix_user_id`
   - `matrix_password`

## 🗄️ Database Schema

**Location:** `database/matrix-schema-current.sql`

**Key Tables:**
- `users` - Matrix user accounts
- `rooms` - Chat rooms
- `events` - All messages and room events
- `devices` - User devices for E2E encryption
- `room_memberships` - Room membership tracking
- `access_tokens` - User authentication tokens

**Total:** ~100+ tables for complete Matrix functionality

## 🚀 Deployment

### Prerequisites
- Kubernetes cluster (k3s)
- Persistent storage
- PostgreSQL 13+
- Network access to ports 8008, 8009

### Quick Deploy
```bash
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix

# 1. Deploy PostgreSQL
kubectl apply -f matrix-postgres-statefulset.yaml
kubectl apply -f matrix-pvcs.yaml

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=matrix-postgres -n caritas --timeout=120s

# 2. Apply ConfigMaps and Secrets
kubectl apply -f matrix-configmaps.yaml
kubectl apply -f matrix-secrets.yaml

# 3. Deploy Services
kubectl apply -f matrix-services.yaml

# 4. Deploy Matrix Synapse
kubectl apply -f matrix-synapse-deployment.yaml

# 5. Deploy Discovery Service
kubectl apply -f matrix-discovery-deployment.yaml

# 6. Setup CronJobs (backups)
kubectl apply -f matrix-cronjobs.yaml

# 7. Verify
kubectl get pods -n caritas | grep matrix
```

### Initialize Database (First Time Only)
```bash
# Import schema
kubectl exec -i matrix-postgres-0 -n caritas -- psql -U synapse_user synapse < database/matrix-schema-current.sql
```

## ⚙️ Configuration

### Homeserver Configuration
**File:** `homeserver-current.yaml`

**Key Settings:**
- **Server Name:** `caritas.local`
- **Registration:** Enabled (via shared secret)
- **Federation:** Enabled
- **OIDC:** Configured with Keycloak
- **Database:** PostgreSQL
- **Media Storage:** `/data/media_store`

### OIDC Integration (Keycloak)
Users can login with their Keycloak credentials.

**Provider:** Keycloak  
**Auto-discovery:** Yes  
**Client ID:** Configured in ConfigMap

### Admin Shared Secret
**Purpose:** Create users via admin API  
**Value:** `caritas-registration-secret-2025`  
**Location:** ConfigMap `matrix-homeserver-oidc`

## 🔧 Management Commands

### Check Status
```bash
# All Matrix pods
kubectl get pods -n caritas | grep matrix

# Synapse logs
kubectl logs -n caritas -l app=matrix-synapse --tail=50

# PostgreSQL logs
kubectl logs -n caritas matrix-postgres-0 --tail=50

# Database connection
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse
```

### Restart Services
```bash
# Restart Synapse
kubectl rollout restart deployment/matrix-synapse -n caritas

# Restart Discovery
kubectl rollout restart deployment/matrix-discovery -n caritas

# Restart PostgreSQL (careful!)
kubectl delete pod matrix-postgres-0 -n caritas
```

### Database Operations
```bash
# Backup database
kubectl exec matrix-postgres-0 -n caritas -- pg_dump -U synapse_user synapse > matrix-backup-$(date +%Y%m%d).sql

# Restore database
kubectl exec -i matrix-postgres-0 -n caritas -- psql -U synapse_user synapse < matrix-backup.sql

# Check database size
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT pg_size_pretty(pg_database_size('synapse'));"

# Count users
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT COUNT(*) FROM users;"

# Count rooms
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT COUNT(*) FROM rooms;"
```

### User Management
```bash
# List all Matrix users
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT name, admin, deactivated FROM users LIMIT 20;"

# Create admin user (via Synapse API)
curl -X POST "http://91.99.219.182:8008/_synapse/admin/v1/register" -H "Content-Type: application/json"
```

## 🔍 Troubleshooting

### Synapse Not Starting
```bash
# Check logs
kubectl logs -n caritas -l app=matrix-synapse --tail=100

# Check ConfigMap
kubectl get configmap matrix-homeserver-oidc -n caritas -o yaml

# Verify database connection
kubectl exec -it matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT 1;"
```

### Database Issues
```bash
# Check PostgreSQL status
kubectl exec matrix-postgres-0 -n caritas -- pg_isready

# Check disk space
kubectl exec matrix-postgres-0 -n caritas -- df -h

# Check connections
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT count(*) FROM pg_stat_activity;"
```

### Federation Not Working
```bash
# Check discovery service
kubectl logs -n caritas -l app=matrix-discovery

# Test .well-known
curl http://91.99.219.182/.well-known/matrix/server

# Check federation port
curl http://91.99.219.182:8009/_matrix/federation/v1/version
```

### Call Issues
1. Check TURN server configuration in homeserver.yaml
2. Verify WebRTC connectivity (firewall/NAT)
3. Check browser console for errors
4. Test with Element.io client

## 📊 Monitoring

### Health Checks
```bash
# Synapse health
curl http://91.99.219.182:8008/_matrix/client/versions

# Database health
kubectl exec matrix-postgres-0 -n caritas -- pg_isready

# Check active users
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT COUNT(DISTINCT user_id) FROM user_ips WHERE last_seen > NOW() - INTERVAL '1 hour';"
```

### Performance Metrics
```bash
# Synapse metrics endpoint
curl http://91.99.219.182:8008/_synapse/metrics

# Database size
kubectl exec matrix-postgres-0 -n caritas -- psql -U synapse_user synapse -c "SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;"
```

## 🔐 Security

### Encryption
- **End-to-End Encryption:** Supported by Matrix SDK
- **Device Verification:** Enabled
- **TLS:** Currently HTTP only (use Nginx for HTTPS)

### Access Control
- **Registration:** Requires shared secret or OIDC
- **Admin API:** Protected by admin token
- **Database:** Password protected

### Secrets Management
All secrets stored in Kubernetes secrets:
- Database passwords
- Registration shared secret
- Macaroon secret key
- OIDC client secrets

## 📈 Scaling

### Horizontal Scaling
Matrix Synapse can be scaled horizontally with:
1. Multiple Synapse workers
2. Redis for caching
3. Load balancer in front

### Database Scaling
- PostgreSQL replication for read scaling
- Connection pooling (pgBouncer)
- Regular vacuuming and maintenance

## 🔗 URLs

- **Client API:** http://91.99.219.182:8008
- **Federation API:** http://91.99.219.182:8009
- **Element Client:** http://91.99.219.182:8087
- **Well-Known:** http://91.99.219.182/.well-known/matrix/server

## 📝 Important Notes

1. **Database Backups:** Automated daily via CronJob
2. **Media Storage:** Stored in persistent volume `/data/media_store`
3. **OIDC Integration:** Users can login with Keycloak
4. **Open Registration:** Currently enabled (can be disabled in production)
5. **Federation:** Enabled (can connect to matrix.org and other servers)

## 🎯 Production Checklist

- [ ] Set up proper TLS/HTTPS (via Nginx)
- [ ] Disable open registration
- [ ] Configure TURN server for calls
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure rate limiting
- [ ] Set up log rotation
- [ ] Test database backups and restore
- [ ] Configure proper CORS headers
- [ ] Set up alerting for critical issues
- [ ] Document disaster recovery procedure

## 📚 Additional Resources

- **Matrix Spec:** https://spec.matrix.org/
- **Synapse Docs:** https://matrix-org.github.io/synapse/
- **Matrix SDK Docs:** https://matrix-org.github.io/matrix-js-sdk/
- **Federation Guide:** https://matrix.org/docs/guides/federation

---

**Status:** Production Ready ✅  
**Namespace:** caritas  
**Version:** Matrix Synapse Latest  
**Database:** PostgreSQL 13+  
**Last Exported:** October 31, 2025


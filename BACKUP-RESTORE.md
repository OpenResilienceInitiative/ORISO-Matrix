# ORISO-Matrix Backup & Restore Guide

## 🔒 Critical Data Protection

This guide ensures your Matrix data is **NEVER LOST**.

## 📦 What Needs to be Backed Up

### 1. SQLite Database
**Location:** `/data/homeserver.db` (inside Synapse pod)  
**Size:** ~8.8MB (current)  
**Contains:** All users, rooms, messages, events, encryption keys

### 2. Write-Ahead Log (WAL)
**Location:** `/data/homeserver.db-wal`  
**Size:** ~4.2MB (current)  
**Contains:** Recent uncommitted transactions

### 3. Media Files
**Location:** `/data/media_store/` (inside Synapse pod)  
**Size:** ~4.1MB (current)  
**Contains:** All uploaded images, files, avatars, attachments

### 4. Configuration
**Location:** `/data/homeserver.yaml`  
**Size:** ~2KB  
**Contains:** Server configuration, secrets, TURN settings

### 5. Signing Key
**Location:** `/data/91.99.219.182.signing.key`  
**Size:** ~59 bytes  
**Contains:** Server cryptographic signing key (CRITICAL!)

---

## 🚨 Emergency Backup (Do This NOW Before Any Changes)

```bash
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups

# 1. Backup SQLite database
kubectl cp caritas/matrix-synapse-b9d4c9647-99rkt:/data/homeserver.db ./homeserver-$(date +%Y%m%d-%H%M%S).db

# 2. Backup WAL file
kubectl cp caritas/matrix-synapse-b9d4c9647-99rkt:/data/homeserver.db-wal ./homeserver-wal-$(date +%Y%m%d-%H%M%S).db

# 3. Backup media files
kubectl exec -n caritas matrix-synapse-b9d4c9647-99rkt -- tar -czf /tmp/media.tar.gz /data/media_store
kubectl cp caritas/matrix-synapse-b9d4c9647-99rkt:/tmp/media.tar.gz ./media_store-$(date +%Y%m%d-%H%M%S).tar.gz

# 4. Backup signing key (CRITICAL!)
kubectl cp caritas/matrix-synapse-b9d4c9647-99rkt:/data/91.99.219.182.signing.key ./signing-key-$(date +%Y%m%d-%H%M%S).key

# 5. Backup config
kubectl cp caritas/matrix-synapse-b9d4c9647-99rkt:/data/homeserver.yaml ./homeserver-$(date +%Y%m%d-%H%M%S).yaml

# 6. Verify all backups
ls -lah
```

**Expected Output:**
```
-rw-rw-r-- 1 caritas caritas 8.8M ... homeserver-20251031-xxxxxx.db
-rw-rw-r-- 1 caritas caritas 4.2M ... homeserver-wal-20251031-xxxxxx.db
-rw-rw-r-- 1 caritas caritas 3.7M ... media_store-20251031-xxxxxx.tar.gz
-rw-rw-r-- 1 caritas caritas   59 ... signing-key-20251031-xxxxxx.key
-rw-rw-r-- 1 caritas caritas 2.2K ... homeserver-20251031-xxxxxx.yaml
```

---

## ✅ Automated Daily Backups

### Using Kubernetes CronJob (Already Setup)

```bash
# Check backup CronJob status
kubectl get cronjobs -n caritas | grep matrix-backup

# View recent backup logs
kubectl logs -n caritas $(kubectl get pods -n caritas | grep matrix-backup | head -1 | awk '{print $1}')

# Backup location
kubectl exec -n caritas matrix-postgres-0 -- ls -lah /backup/
```

### Manual Backup Script

**Location:** `ORISO-Matrix/backups/manual-backup.sh`

```bash
#!/bin/bash
# Manual Matrix Backup Script

BACKUP_DIR="/home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
POD_NAME=$(kubectl get pods -n caritas -l app=matrix-synapse -o jsonpath='{.items[0].metadata.name}')

echo "🔒 Starting Matrix backup: $TIMESTAMP"
echo "📦 Pod: $POD_NAME"

mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# Database
echo "💾 Backing up database..."
kubectl cp caritas/$POD_NAME:/data/homeserver.db "$BACKUP_DIR/$TIMESTAMP/homeserver.db"
kubectl cp caritas/$POD_NAME:/data/homeserver.db-wal "$BACKUP_DIR/$TIMESTAMP/homeserver-wal.db"

# Media
echo "📁 Backing up media files..."
kubectl exec -n caritas $POD_NAME -- tar -czf /tmp/media.tar.gz /data/media_store 2>/dev/null
kubectl cp caritas/$POD_NAME:/tmp/media.tar.gz "$BACKUP_DIR/$TIMESTAMP/media_store.tar.gz"

# Config & Keys
echo "🔑 Backing up config and keys..."
kubectl cp caritas/$POD_NAME:/data/homeserver.yaml "$BACKUP_DIR/$TIMESTAMP/homeserver.yaml"
kubectl cp caritas/$POD_NAME:/data/91.99.219.182.signing.key "$BACKUP_DIR/$TIMESTAMP/signing.key"

# Summary
echo ""
echo "✅ Backup Complete!"
echo "📂 Location: $BACKUP_DIR/$TIMESTAMP"
ls -lah "$BACKUP_DIR/$TIMESTAMP/"
du -sh "$BACKUP_DIR/$TIMESTAMP/"
```

**Make it executable:**
```bash
chmod +x /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups/manual-backup.sh
```

---

## 🔄 Restore Procedures

### Scenario 1: Restore from Latest Backup

```bash
BACKUP_DIR="/home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups"
POD_NAME=$(kubectl get pods -n caritas -l app=matrix-synapse -o jsonpath='{.items[0].metadata.name}')

# Find latest backup
LATEST=$(ls -t $BACKUP_DIR/homeserver-*.db | head -1)
LATEST_WAL=$(ls -t $BACKUP_DIR/homeserver-wal-*.db | head -1)
LATEST_MEDIA=$(ls -t $BACKUP_DIR/media_store-*.tar.gz | head -1)
LATEST_KEY=$(ls -t $BACKUP_DIR/signing-key-*.key | head -1)

echo "Restoring from: $LATEST"

# 1. Scale down Synapse (stop pod)
kubectl scale deployment matrix-synapse -n caritas --replicas=0

# 2. Wait for pod to terminate
kubectl wait --for=delete pod/$POD_NAME -n caritas --timeout=60s

# 3. Scale up (new pod will be created)
kubectl scale deployment matrix-synapse -n caritas --replicas=1

# 4. Wait for new pod
NEW_POD=$(kubectl get pods -n caritas -l app=matrix-synapse -o jsonpath='{.items[0].metadata.name}')
kubectl wait --for=condition=ready pod/$NEW_POD -n caritas --timeout=120s

# 5. Restore database
kubectl cp "$LATEST" caritas/$NEW_POD:/data/homeserver.db
kubectl cp "$LATEST_WAL" caritas/$NEW_POD:/data/homeserver.db-wal

# 6. Restore media
kubectl cp "$LATEST_MEDIA" caritas/$NEW_POD:/tmp/media.tar.gz
kubectl exec -n caritas $NEW_POD -- tar -xzf /tmp/media.tar.gz -C /

# 7. Restore signing key
kubectl cp "$LATEST_KEY" caritas/$NEW_POD:/data/91.99.219.182.signing.key

# 8. Restart Synapse
kubectl rollout restart deployment/matrix-synapse -n caritas

echo "✅ Restore complete!"
```

### Scenario 2: Disaster Recovery (Complete Rebuild)

```bash
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix

# 1. Deploy PVCs
kubectl apply -f 02-matrix-pvcs-clean.yaml

# 2. Deploy ConfigMaps
kubectl apply -f matrix-configmaps.yaml

# 3. Deploy Secrets
kubectl apply -f matrix-secrets.yaml

# 4. Deploy Synapse
kubectl apply -f 01-matrix-synapse-deployment-clean.yaml

# 5. Wait for pod
kubectl wait --for=condition=ready pod -l app=matrix-synapse -n caritas --timeout=180s

# 6. Restore data (using Scenario 1 steps 5-8)
```

### Scenario 3: Migrate to New Server

```bash
# On OLD server
cd /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups
./manual-backup.sh

# Copy entire backups directory to new server
scp -r backups/ user@new-server:/path/to/ORISO-Matrix/

# On NEW server
cd /path/to/ORISO-Matrix
# Follow Scenario 2 steps, then restore from backup
```

---

## 🔍 Verify Restore

```bash
POD_NAME=$(kubectl get pods -n caritas -l app=matrix-synapse -o jsonpath='{.items[0].metadata.name}')

# Check database exists
kubectl exec -n caritas $POD_NAME -- ls -lah /data/homeserver.db

# Check Synapse is running
curl http://91.99.219.182:8008/_matrix/client/versions

# Check logs
kubectl logs -n caritas $POD_NAME --tail=50

# Test login (via Element or frontend)
```

---

## 📊 Backup Status Check

```bash
# List all backups
ls -lah /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups/

# Check backup sizes
du -sh /home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups/*

# Check CronJob status
kubectl get cronjobs -n caritas | grep matrix

# Check latest backup time
kubectl get jobs -n caritas | grep matrix-backup | head -1
```

---

## ⚠️ CRITICAL WARNINGS

### 1. **NEVER** Delete These Files:
- `homeserver.db` (main database)
- `homeserver.db-wal` (write-ahead log)
- `91.99.219.182.signing.key` (server identity)

### 2. **ALWAYS** Backup Before:
- Upgrading Synapse version
- Changing database configuration
- Migrating to new server
- Testing new features

### 3. **TEST** Restores Regularly:
- Do a test restore monthly
- Verify data integrity
- Ensure backup scripts work

### 4. **OFFSITE** Backups:
- Store backups on a different server/location
- Consider GitHub private repo for encrypted backups
- Use cloud storage (encrypted)

---

## 🎯 Best Practices

1. **Daily automated backups** (via CronJob) ✅
2. **Manual backup before major changes** ✅
3. **Keep 30 days of backups** (rotate old ones)
4. **Test restore procedure monthly**
5. **Document any configuration changes**
6. **Monitor backup job status daily**
7. **Store signing key separately** (very important!)

---

## 📞 Emergency Contacts

If restore fails:
1. Check backup file sizes (should not be empty)
2. Check Synapse logs for errors
3. Try restore from previous backup
4. Contact: Matrix support or community

---

**Last Updated:** October 31, 2025  
**Backup Location:** `/home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups/`  
**Current Backup Size:** ~17MB  
**Backup Frequency:** Daily (automated) + Manual (as needed)


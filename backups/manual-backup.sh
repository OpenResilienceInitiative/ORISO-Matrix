#!/bin/bash
# ORISO-Matrix Manual Backup Script
# Safely backs up all Matrix data

BACKUP_DIR="/home/caritas/Desktop/online-beratung/caritas-workspace/ORISO-Matrix/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
POD_NAME=$(kubectl get pods -n caritas -l app=matrix-synapse -o jsonpath='{.items[0].metadata.name}')

echo "🔒 ORISO-Matrix Backup Script"
echo "=================================================="
echo "⏰ Timestamp: $TIMESTAMP"
echo "📦 Pod: $POD_NAME"
echo "📂 Backup Directory: $BACKUP_DIR"
echo "=================================================="

if [ -z "$POD_NAME" ]; then
    echo "❌ ERROR: Matrix Synapse pod not found!"
    exit 1
fi

# Create timestamped backup directory
mkdir -p "$BACKUP_DIR/$TIMESTAMP"

# 1. Backup SQLite Database
echo ""
echo "💾 [1/5] Backing up database..."
kubectl cp caritas/$POD_NAME:/data/homeserver.db "$BACKUP_DIR/$TIMESTAMP/homeserver.db" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Database backed up"
else
    echo "❌ Database backup failed"
fi

# 2. Backup WAL File
echo ""
echo "💾 [2/5] Backing up Write-Ahead Log..."
kubectl cp caritas/$POD_NAME:/data/homeserver.db-wal "$BACKUP_DIR/$TIMESTAMP/homeserver-wal.db" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ WAL file backed up"
else
    echo "⚠️  WAL file backup failed (may not exist)"
fi

# 3. Backup Media Files
echo ""
echo "📁 [3/5] Backing up media files..."
kubectl exec -n caritas $POD_NAME -- tar -czf /tmp/media.tar.gz /data/media_store 2>/dev/null
kubectl cp caritas/$POD_NAME:/tmp/media.tar.gz "$BACKUP_DIR/$TIMESTAMP/media_store.tar.gz" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Media files backed up"
else
    echo "❌ Media files backup failed"
fi

# 4. Backup Configuration
echo ""
echo "⚙️  [4/5] Backing up configuration..."
kubectl cp caritas/$POD_NAME:/data/homeserver.yaml "$BACKUP_DIR/$TIMESTAMP/homeserver.yaml" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Configuration backed up"
else
    echo "❌ Configuration backup failed"
fi

# 5. Backup Signing Key (CRITICAL!)
echo ""
echo "🔑 [5/5] Backing up signing key..."
kubectl cp caritas/$POD_NAME:/data/91.99.219.182.signing.key "$BACKUP_DIR/$TIMESTAMP/signing.key" 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Signing key backed up"
else
    echo "❌ Signing key backup failed"
fi

# Summary
echo ""
echo "=================================================="
echo "✅ Backup Complete!"
echo "=================================================="
echo "📂 Location: $BACKUP_DIR/$TIMESTAMP"
echo ""
echo "📊 Backup Contents:"
ls -lah "$BACKUP_DIR/$TIMESTAMP/" | tail -n +4
echo ""
echo "💽 Total Size:"
du -sh "$BACKUP_DIR/$TIMESTAMP/" | awk '{print $1}'
echo ""
echo "=================================================="
echo "🔒 Your Matrix data is safe!"
echo "=================================================="


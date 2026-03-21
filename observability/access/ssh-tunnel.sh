#!/bin/bash

# === CONFIG ===
BASTION_IP="163.227.186.130"
PORT="5726"
USER="admin"
KEY="admin.pem"

echo "🚀 Creating SSH tunnel for Grafana (3000) and Prometheus (9090)..."

ssh -i $KEY -p $PORT \
  -L 3000:127.0.0.1:3000 \
  -L 9090:127.0.0.1:9090 \
  $USER@$BASTION_IP

echo "✅ Tunnel closed"

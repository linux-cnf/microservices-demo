#!/bin/bash

echo "🚀 Port-forwarding Grafana..."

kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80

echo "👉 Open: http://127.0.0.1:3000"

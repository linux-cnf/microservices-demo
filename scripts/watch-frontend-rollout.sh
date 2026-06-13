#!/usr/bin/env bash
set -euo pipefail

echo "========================================================="
echo "Frontend Argo Rollout Watch"
echo "========================================================="
echo
echo "What to check:"
echo "- Rollout should move through canary steps"
echo "- AnalysisRun should be created"
echo "- If metrics fail, rollout should abort/rollback"
echo
echo "Useful parallel command:"
echo "kubectl get analysisrun -n boutique -w"
echo
echo "Starting rollout watch..."
echo

kubectl argo rollouts get rollout frontend -n boutique --watch

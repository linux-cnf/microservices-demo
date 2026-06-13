#!/usr/bin/env bash

# Purpose:
# This script safely triggers a new Argo Rollouts revision for the frontend service using GitOps.
# Since the main branch is protected, it creates a unique PR branch on every run instead of pushing directly to main.
# It updates a harmless frontend environment variable so the pod template changes and Argo Rollouts creates an AnalysisRun.
# After the PR is merged, Argo CD syncs the change and Prometheus-based rollout analysis metrics are executed.

set -euo pipefail

FILE="kustomize/base/frontend.yaml"
VAR_NAME="PHASE4_METRIC_TEST"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
VALUE="run-${TIMESTAMP}"
BRANCH="phase4-rollout-analysis-test-${TIMESTAMP}"

echo "Creating unique branch: ${BRANCH}"

git checkout main
git pull --ff-only origin main
git checkout -b "${BRANCH}"

echo "Updating ${VAR_NAME} to ${VALUE} in ${FILE}"

if grep -q "name: ${VAR_NAME}" "${FILE}"; then
  sed -i "/name: ${VAR_NAME}/{n;s/value: .*/value: \"${VALUE}\"/;}" "${FILE}"
else
  sed -i "/- name: ENABLE_PROFILER/i\\
          - name: ${VAR_NAME}\\
            value: \"${VALUE}\"" "${FILE}"
fi

echo "Validating kustomize build..."
kubectl kustomize kustomize >/tmp/frontend-rollout-analysis-test.yaml

echo "Git diff:"
git diff "${FILE}"

git add "${FILE}"

git commit -m "Trigger frontend rollout analysis test ${VALUE}"

git push -u origin "${BRANCH}"
echo
echo "========================================================="
echo "Frontend Rollout Analysis Test Created"
echo "========================================================="
echo
echo "Branch:"
echo "  ${BRANCH}"
echo
echo "Modified file:"
echo "  ${FILE}"
echo
echo "Trigger value:"
echo "  ${VAR_NAME}=${VALUE}"
echo
echo "GitOps workflow:"
echo "  1. Open PR from ${BRANCH} -> main"
echo "  2. Review and merge the PR"
echo "  3. Argo CD will detect the Git change"
echo "  4. Argo Rollouts will create a new rollout revision"
echo "  5. AnalysisRun will execute Prometheus metric checks"
echo "  6. Rollout will continue or abort based on analysis results"
echo
echo "Optional: force immediate Argo CD refresh"
echo "  kubectl annotate application boutique -n argocd \\"
echo "    argocd.argoproj.io/refresh=hard --overwrite"
echo
echo "Watch rollout progress:"
echo "  kubectl argo rollouts get rollout frontend -n boutique --watch"
echo
echo "Watch AnalysisRun execution:"
echo "  kubectl get analysisrun -n boutique -w"
echo
echo "Describe AnalysisRun details:"
echo "  kubectl describe analysisrun -n boutique"
echo
echo "View rollout history:"
echo "  kubectl argo rollouts history frontend -n boutique"
echo
echo "View rollout status:"
echo "  kubectl argo rollouts get rollout frontend -n boutique"
echo
echo "Expected outcome:"
echo "  - New frontend ReplicaSet created"
echo "  - Canary steps executed (10% -> 25% -> 50% -> 100%)"
echo "  - Prometheus analysis passes"
echo "  - Rollout becomes Healthy"
echo
echo "If analysis fails:"
echo "  - Rollout will stop at the failing canary step"
echo "  - AnalysisRun status becomes Failed"
echo "  - Investigate Prometheus metrics and rollout events"
echo
echo "Done."

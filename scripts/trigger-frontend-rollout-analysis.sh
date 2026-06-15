#!/usr/bin/env bash

# Purpose:
# Safely trigger a new frontend rollout through GitOps.
#
# Since main is protected, a unique branch is created for every run.
# The script updates a harmless frontend environment variable so the
# Rollout pod template changes and Argo Rollouts creates a new revision.
#
# After the PR is merged:
# - Argo CD syncs the change
# - Argo Rollouts starts a new canary rollout
# - AnalysisRuns execute
# - Istio traffic weights are updated automatically

set -euo pipefail

FILE="kustomize/base/frontend.yaml"
VAR_NAME="ROLLOUT_TRIGGER"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
VALUE="run-${TIMESTAMP}"
BRANCH="frontend-rollout-test-${TIMESTAMP}"

echo "========================================================="
echo "Creating rollout test branch"
echo "========================================================="
echo

echo "Branch: ${BRANCH}"

git checkout main
git pull --ff-only origin main
git checkout -b "${BRANCH}"

echo
echo "Updating ${VAR_NAME}=${VALUE}"

if grep -q "name: ${VAR_NAME}" "${FILE}"; then
  sed -i "/name: ${VAR_NAME}/{n;s/value: .*/value: \"${VALUE}\"/;}" "${FILE}"
else
  sed -i "/- name: ENABLE_PROFILER/i\\
          - name: ${VAR_NAME}\\
            value: \"${VALUE}\"" "${FILE}"
fi

echo
echo "Validating Kustomize build..."

kubectl kustomize kustomize >/tmp/frontend-rollout-test.yaml

echo
echo "Git diff:"
git diff "${FILE}"

git add "${FILE}"

git commit -m "Trigger frontend rollout ${VALUE}"

git push -u origin "${BRANCH}"

echo
echo "========================================================="
echo "Frontend rollout test created"
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
echo "Next steps:"
echo "  1. Open PR"
echo "  2. Merge PR"
echo "  3. Argo CD syncs automatically"
echo "  4. Argo Rollouts creates a new revision"
echo "  5. AnalysisRuns execute"
echo "  6. Istio traffic weights change during rollout"
echo
echo "Watch rollout:"
echo "  kubectl argo rollouts get rollout frontend -n boutique --watch"
echo
echo "Watch AnalysisRuns:"
echo "  kubectl get analysisrun -n boutique -w"
echo
echo "Watch Istio traffic weights:"
echo "  watch -n 5 'kubectl get virtualservice frontend -n boutique -o jsonpath=\"{.spec.http[0].route[*].weight}{\\\"\\\\n\\\"}\"'"
echo
echo "View rollout history:"
echo "  kubectl argo rollouts history frontend -n boutique"
echo
echo "View rollout status:"
echo "  kubectl argo rollouts get rollout frontend -n boutique"
echo
echo "Expected traffic progression:"
echo "  90/10 -> 75/25 -> 50/50 -> 0/100"
echo
echo "Done."

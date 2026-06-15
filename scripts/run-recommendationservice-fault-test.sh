#!/usr/bin/env bash
# =========================================================
# Recommendation Service Fault Injection Test Script
# =========================================================
#
# PURPOSE:
# Run temporary Istio fault-injection tests against
# recommendationservice.
#
# WHY THIS SCRIPT?
# Fault injection is mainly used for resilience testing.
# We do not keep delay/abort faults permanently enabled in
# GitOps because they intentionally slow down or break
# application traffic.
#
# USE CASES:
#
# 1. Delay Test
#    Simulates slow backend responses.
#
#    Example:
#    recommendationservice becomes slow due to:
#      - Database latency
#      - Network congestion
#      - External API delays
#
#    Validation:
#    Measure request latency from frontend.
#
# 2. Abort Test
#    Simulates backend HTTP 500 failures.
#
#    Example:
#    recommendationservice crashes or returns errors.
#
#    Validation:
#    Observe frontend behavior when dependency fails.
#
# 3. Clean
#    Removes active fault-injection VirtualServices and
#    restores normal behavior.
#
# HOW TO USE:
#
# Enable latency injection:
#   ./scripts/run-recommendationservice-fault-test.sh delay
#
# Enable HTTP 500 injection:
#   ./scripts/run-recommendationservice-fault-test.sh abort
#
# Remove all fault injection:
#   ./scripts/run-recommendationservice-fault-test.sh clean
#
# =========================================================

set -euo pipefail

NAMESPACE="boutique"
MODE="${1:-}"

DELAY_FILE="kustomize/components/service-mesh-istio/recommendationservice-fault-injection.yaml"
ABORT_FILE="kustomize/components/service-mesh-istio/recommendationservice-abort-fault.yaml"

case "$MODE" in

  delay)
    echo "Applying delay fault injection..."

    kubectl delete -n "$NAMESPACE" \
      -f "$ABORT_FILE" \
      --ignore-not-found

    kubectl apply -n "$NAMESPACE" \
      -f "$DELAY_FILE"

    echo
    echo "========================================================="
    echo "DELAY TEST ENABLED"
    echo "========================================================="
    echo
    echo "Validate delay injection using:"
    echo
    echo "for i in {1..30}; do"
    echo "  curl -s -o /dev/null -w \"%{time_total}\\n\" http://34.45.27.5"
    echo "done"
    echo
    echo "Expected:"
    echo "  - Most requests around normal latency (~0.7s)"
    echo "  - Some requests delayed (~2-4s)"
    echo "  - Delay is injected into 20% of traffic"
    echo
    ;;

  abort)
    echo "Applying abort fault injection..."

    kubectl delete -n "$NAMESPACE" \
      -f "$DELAY_FILE" \
      --ignore-not-found

    kubectl apply -n "$NAMESPACE" \
      -f "$ABORT_FILE"

    echo
    echo "========================================================="
    echo "ABORT TEST ENABLED"
    echo "========================================================="
    echo
    echo "Validate abort injection using:"
    echo
    echo "for i in {1..50}; do"
    echo "  curl -s -o /dev/null -w \"%{http_code}\\n\" http://34.45.27.5"
    echo "done | sort | uniq -c"
    echo
    echo "Expected:"
    echo "  - Mostly HTTP 200 responses"
    echo "  - Some HTTP 500 responses"
    echo "  - Or graceful frontend fallback behavior"
    echo "  - Abort is injected into 10% of traffic"
    echo
    ;;

  clean)
    echo "Removing all recommendationservice fault injection..."

    kubectl delete -n "$NAMESPACE" \
      -f "$DELAY_FILE" \
      --ignore-not-found

    kubectl delete -n "$NAMESPACE" \
      -f "$ABORT_FILE" \
      --ignore-not-found

    echo
    echo "========================================================="
    echo "FAULT INJECTION REMOVED"
    echo "========================================================="
    echo
    echo "Validate normal application behavior:"
    echo
    echo "curl -I http://34.45.27.5"
    echo
    echo "Expected:"
    echo "  - HTTP/1.1 200 OK"
    echo "  - No injected latency"
    echo "  - No injected HTTP 500 errors"
    echo
    ;;

  *)
    echo "Usage: $0 {delay|abort|clean}"
    exit 1
    ;;
esac

echo
echo "Current recommendationservice VirtualServices:"
kubectl get virtualservice -n "$NAMESPACE" | grep -E 'NAME|recommendationservice' || true

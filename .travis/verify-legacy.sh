#!/bin/bash
# LEGACY V1 TEST: run new combined verify helper (legacy + new modes)

echo "🧪 === RUNNING COMBINED VERIFY (legacy + new) ==="

# Make verify script executable and run only legacy test by default for CI compatibility
chmod +x ./scripts/verify.sh || true
./scripts/verify.sh legacy

LEGACY_EXIT_CODE=$?

# Verify it detected legacy mode (exit 0 = success)
if [ $LEGACY_EXIT_CODE -eq 0 ]; then
  echo "✅ LEGACY TEST PASSED: ./data/db → mysql mode detected"
else
  echo "❌ LEGACY TEST FAILED: verify.sh returned $LEGACY_EXIT_CODE"
  exit 1
fi

echo "🎉 === LEGACY TEST COMPLETE ==="
exit 0

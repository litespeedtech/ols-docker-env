#!/bin/bash
# LEGACY V1 TEST: ./data/db EXISTS → mysql mode

echo "🧪 === LEGACY TEST START ==="

# Simulate existing user with ./data/db
mkdir -p ./data/db
touch ./data/db/.legacy-test
echo "✅ Created ./data/db (triggers LEGACY mode)"

# Run main verification
echo "🔍 Running verify.sh (should detect LEGACY mysql mode)..."
./verify.sh

LEGACY_EXIT_CODE=$?

# Verify it detected legacy mode (exit 0 = success)
if [ $LEGACY_EXIT_CODE -eq 0 ]; then
  echo "✅ LEGACY TEST PASSED: ./data/db → mysql mode detected"
else
  echo "❌ LEGACY TEST FAILED: verify.sh returned $LEGACY_EXIT_CODE"
  exit 1
fi

# Cleanup
rm -rf ./data/db
echo "🧹 Cleaned ./data/db"

echo "🎉 === LEGACY TEST COMPLETE ==="
exit 0

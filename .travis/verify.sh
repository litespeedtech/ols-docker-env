cat > .travis/verify.sh << 'EOF'
#!/bin/bash
set -o errexit

echo "🚀 ols-docker-env v2.0 PRODUCTION Travis CI Tests"

# v2.0 Only: Test production stack
docker-compose config || exit 1
echo "✅ docker-compose.yml v2.0 validated"

# Verify WebAdmin (7080)
curl -sIk http://localhost:7080/ | grep -i LiteSpeed && echo "✅ WebAdmin OK"

# Verify phpMyAdmin PATH-ONLY (v2.0)
curl -sIk http://localhost/phpmyadmin/ | grep -i phpMyAdmin && echo "✅ phpMyAdmin v2.0 OK"

# Test v2.0 Production Scripts ONLY
for script in bin/backup.sh bin/restore.sh bin/copy.sh bin/appinstall.sh; do
  if [[ -f "$script" ]]; then
    bash "$script" --help >/dev/null && echo "✅ $script OK"
  fi
done

# Test domain workflow
bash bin/domain.sh --add example.com
bash bin/appinstall.sh wordpress example.com
echo "✅ v2.0 Production workflow OK"

echo "🎉 v2.0 TRAVIS PASSED ✅"
EOF

chmod +x .travis/verify.sh

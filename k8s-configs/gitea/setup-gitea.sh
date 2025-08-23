#!/bin/bash

# Gitea Setup Script
echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

echo "🔐 Checking for required secrets..."
if ! kubectl get secret gitea-postgresql-secret -n gitea >/dev/null 2>&1; then
    echo "❌ Error: gitea-postgresql-secret not found in gitea namespace"
    echo "Please create the secret first with the password from 1Password:"
    exit 1
fi
echo "✅ Required secrets found"

echo "🗄️  Setting up database..."pt sets up Gitea with external PostgreSQL (no Redis dependency)
# Uses file-based sessions and memory caching for simplicity

set -e

echo "🚀 Setting up Gitea..."

# Check if we're in the right directory
if [[ ! -f "values.yaml" ]]; then
    echo "❌ Error: Please run this script from the gitea directory"
    echo "Expected to find values.yaml in current directory"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
echo "🔍 Checking required tools..."
for tool in kubectl helm; do
    if ! command_exists $tool; then
        echo "❌ Error: $tool is not installed"
        exit 1
    fi
done
echo "✅ Required tools found"

echo "🔍 Checking PostgreSQL..."
if ! kubectl get statefulset -n postgresql postgresql >/dev/null 2>&1; then
    echo "❌ Error: PostgreSQL statefulset not found in postgresql namespace"
    echo "Please ensure PostgreSQL is running first"
    exit 1
fi
echo "✅ PostgreSQL found"

echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

echo "️  Setting up database..."
# Extract password from secret
DB_PASSWORD=$(kubectl get secret gitea-postgresql-secret -n gitea -o jsonpath='{.data.password}' | base64 -d)

# Create database user with password from secret
kubectl exec -n postgresql statefulset/postgresql -- psql -U postgres -v password="$DB_PASSWORD" << 'EOF'
-- Create user if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'gitea') THEN
        EXECUTE format('CREATE USER gitea WITH PASSWORD %L', :'password');
    END IF;
END
$$;

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE gitea OWNER gitea'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'gitea')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;

-- Show result
SELECT 'Database setup completed' as status;
EOF

echo "✅ Database setup completed"

echo "📚 Adding Gitea Helm repository..."
helm repo add gitea-charts https://dl.gitea.com/charts/ 2>/dev/null || true
helm repo update

echo "🏗️  Installing Gitea..."
echo "📝 Using external PostgreSQL with memory caching (no Redis dependency)"
helm upgrade --install gitea gitea-charts/gitea -n gitea -f values.yaml

echo ""
echo "🎉 Gitea installation completed!"
echo ""
echo "📋 Access Information:"
echo "   Web Interface: https://gitea.home.jasongodson.com"
echo "   Admin Username: admin"
echo "   Admin Password: changeme123!"
echo ""
echo "⏳ Waiting for Gitea to be ready..."

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=300s deployment/gitea -n gitea

echo ""
echo "✅ Gitea is ready!"
echo ""
echo "🔗 Next steps:"
echo "   1. Visit https://gitea.home.jasongodson.com"
echo "   2. Login with admin/changeme123!"
echo "   3. ⚠️  IMPORTANT: Change the admin password immediately"
echo "   4. Create organizations and repositories"
echo "   5. Set up Gitea Actions for CI/CD automation"

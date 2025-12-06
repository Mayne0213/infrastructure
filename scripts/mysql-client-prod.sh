#!/bin/bash
# Open MySQL client for production database
# Usage: ./mysql-client-prod.sh [database_name]
# Example: ./mysql-client-prod.sh TodoListDB

set -e

DATABASE=${1:-TodoListDB}

echo "🔍 Opening MySQL client for prod database: $DATABASE"
echo "⚠️  WARNING: This is PRODUCTION database. Be careful!"
echo ""

# Connect via kubectl exec to primary
ssh oracle-master "sudo kubectl exec -n mysql mysql-primary-0 -it -- mysql -uroot -pchangeme-root-password $DATABASE"

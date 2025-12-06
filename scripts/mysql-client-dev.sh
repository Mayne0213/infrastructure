#!/bin/bash
# Open MySQL client for development database
# Usage: ./mysql-client-dev.sh [database_name]
# Example: ./mysql-client-dev.sh TodoListDB

set -e

DATABASE=${1:-TodoListDB}

echo "🔍 Opening MySQL client for dev database: $DATABASE"
echo ""

# Connect via kubectl exec
ssh oracle-master "sudo kubectl exec -n mysql mysql-dev-0 -it -- mysql -uroot -pdev-password $DATABASE"

#!/bin/bash
# Connect to development database via kubectl port-forward
# Usage: ./connect-dev-db.sh

set -e

echo "🔌 Connecting to development database..."
echo "📍 Host: 127.0.0.1"
echo "🔢 Port: 3307"
echo "🗄️  Database: TodoListDB (or JaejadleDB)"
echo ""
echo "💡 Use this connection string:"
echo "   mysql://root:dev-password@127.0.0.1:3307/TodoListDB"
echo ""
echo "Press Ctrl+C to stop port-forwarding"
echo ""

# Start port-forwarding
ssh oracle-master "sudo kubectl port-forward -n mysql svc/mysql-dev 3306:3306"

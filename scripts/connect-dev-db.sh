#!/bin/bash
# Connect to development database via SSH tunnel + kubectl port-forward
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

# Kill any existing port-forward on remote
ssh oracle-master "sudo pkill -f 'kubectl port-forward.*mysql-dev' || true"

# Start SSH tunnel: Local 3307 -> Remote 3307 -> mysql-dev:3306
ssh -L 3307:127.0.0.1:3307 oracle-master "sudo kubectl port-forward -n mysql svc/mysql-dev 3307:3306"

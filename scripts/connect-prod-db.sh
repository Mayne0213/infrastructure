#!/bin/bash
# Connect to production database via SSH tunnel + ProxySQL
# Usage: ./connect-prod-db.sh

set -e

echo "🔌 Connecting to production database (via ProxySQL)..."
echo "📍 Host: 127.0.0.1"
echo "🔢 Port: 6034"
echo "🗄️  Database: TodoListDB (or JaejadleDB)"
echo ""
echo "💡 Use this connection string:"
echo "   mysql://root:changeme-root-password@127.0.0.1:6034/TodoListDB"
echo ""
echo "⚠️  WARNING: This is PRODUCTION database. Be careful!"
echo ""
echo "Press Ctrl+C to stop port-forwarding"
echo ""

# Kill any existing port-forward on remote
ssh oracle-master "sudo pkill -f 'kubectl port-forward.*proxysql' || true"

# Start SSH tunnel: Local 6034 -> Remote 6034 -> proxysql:6033
ssh -L 6034:127.0.0.1:6034 oracle-master "sudo kubectl port-forward -n mysql svc/proxysql 6034:6033"

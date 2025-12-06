#!/bin/bash

# Sealed Secret 생성 헬퍼 스크립트
# 사용법: ./create-sealed-secret.sh <secret-name> <namespace> [scope]

set -e

# 인자 검증
if [ $# -lt 2 ]; then
  echo "사용법: $0 <secret-name> <namespace> [scope]"
  echo "scope: strict(기본값), namespace-wide, cluster-wide"
  exit 1
fi

SECRET_NAME=$1
NAMESPACE=$2
SCOPE=${3:-strict}

# Public key 가져오기
echo "📥 Public key 가져오는 중..."
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > /tmp/pub-cert.pem

# 기존 Secret 확인
echo "🔍 Secret '$SECRET_NAME' in namespace '$NAMESPACE' 확인 중..."
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "❌ Secret을 찾을 수 없습니다"
  exit 1
fi

# Secret을 YAML로 export
echo "📤 Secret export 중..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o yaml > /tmp/secret.yaml

# SealedSecret으로 변환
echo "🔐 SealedSecret으로 변환 중... (scope: $SCOPE)"
kubeseal --format=yaml \
  --cert=/tmp/pub-cert.pem \
  --scope="$SCOPE" \
  < /tmp/secret.yaml > "sealed-$SECRET_NAME.yaml"

# 정리
rm -f /tmp/secret.yaml /tmp/pub-cert.pem

echo "✅ 완료! sealed-$SECRET_NAME.yaml 파일이 생성되었습니다"
echo ""
echo "다음 명령으로 Git에 커밋하세요:"
echo "  git add sealed-$SECRET_NAME.yaml"
echo "  git commit -m 'Add sealed secret for $SECRET_NAME'"
echo "  git push"

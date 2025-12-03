#!/bin/bash

###############################################################################
# K3s 마스터 노드 자동 설치 스크립트
# 용도: k3s 마스터 설치 + iptables 설정 + ArgoCD, Ingress, cert-manager 설치
# 실행 방법: bash setup-master.sh
###############################################################################

set -e  # 에러 발생 시 즉시 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 시작 메시지
echo "========================================"
echo "  K3s 마스터 노드 자동 설치"
echo "========================================"
echo ""

###############################################################################
# 1. 시스템 업데이트
###############################################################################
log_info "1/7 시스템 패키지 업데이트 중..."
sudo apt-get update -y
sudo apt-get upgrade -y

###############################################################################
# 2. K3s 마스터 설치
###############################################################################
log_info "2/7 K3s 마스터 설치 중..."
if command -v k3s &> /dev/null; then
    log_warn "K3s가 이미 설치되어 있습니다. 건너뜁니다."
else
    curl -sfL https://get.k3s.io | sh -s - --disable traefik

    log_info "K3s 시작 대기 중..."
    sleep 10

    log_info "K3s 마스터 설치 완료!"
fi

# K3s 상태 확인
log_info "K3s 노드 상태:"
sudo kubectl get nodes

###############################################################################
# 3. iptables 방화벽 규칙 설정
###############################################################################
log_info "3/7 iptables 방화벽 규칙 설정 중..."

# Kubernetes API 서버 포트
sudo iptables -I INPUT 1 -p tcp --dport 6443 -j ACCEPT

# Kubelet API
sudo iptables -I INPUT 1 -p tcp --dport 10250 -j ACCEPT

# etcd
sudo iptables -I INPUT 1 -p tcp --dport 2379:2380 -j ACCEPT

# Pod 네트워크 (Flannel)
sudo iptables -I INPUT 1 -s 10.42.0.0/16 -j ACCEPT
sudo iptables -I INPUT 1 -s 10.43.0.0/16 -j ACCEPT
sudo iptables -I OUTPUT 1 -d 10.43.0.0/16 -j ACCEPT
sudo iptables -I FORWARD 1 -s 10.42.0.0/16 -j ACCEPT
sudo iptables -I FORWARD 1 -d 10.42.0.0/16 -j ACCEPT

# iptables 규칙 저장 (재부팅 후에도 유지)
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save

log_info "iptables 규칙 설정 완료!"

###############################################################################
# 4. 워커 노드 조인 토큰 표시
###############################################################################
log_info "4/7 워커 노드 조인 정보 가져오기..."

MASTER_IP=$(hostname -I | awk '{print $1}')
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

echo ""
echo "========================================"
echo "  워커 노드 조인 정보"
echo "========================================"
echo "워커 노드에서 다음 명령어를 실행하세요:"
echo ""
echo "bash setup-worker.sh $MASTER_IP $NODE_TOKEN"
echo ""
echo "또는 환경 변수로:"
echo "K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$NODE_TOKEN bash setup-worker.sh"
echo "========================================"
echo ""

log_warn "위 명령어를 복사해서 워커 노드에서 실행하세요!"
echo ""
read -p "워커 노드 설치를 완료했으면 Enter를 눌러 계속하세요..."

###############################################################################
# 5. ArgoCD 설치
###############################################################################
log_info "5/7 ArgoCD 설치 중..."
if sudo kubectl get namespace argocd &> /dev/null; then
    log_warn "ArgoCD 네임스페이스가 이미 존재합니다. 건너뜁니다."
else
    sudo kubectl create namespace argocd
    sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log_info "ArgoCD 파드 시작 대기 중... (1-2분 소요)"
    sleep 30

    # 실패한 Pod 재시작
    log_info "ArgoCD Pod 상태 확인 및 재시작 중..."
    sleep 30
    sudo kubectl delete pod -n argocd --field-selector=status.phase=Failed 2>/dev/null || true
    sudo kubectl rollout restart statefulset -n argocd argocd-application-controller 2>/dev/null || true

    log_info "ArgoCD 준비 대기 중..."
    sleep 30

    log_info "ArgoCD 설치 완료!"
fi

###############################################################################
# 6. Ingress Nginx Controller 설치
###############################################################################
log_info "6/7 Ingress Nginx Controller 설치 중..."
if sudo kubectl get namespace ingress-nginx &> /dev/null; then
    log_warn "Ingress Nginx가 이미 설치되어 있습니다. 건너뜁니다."
else
    sudo kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

    log_info "Ingress Controller 파드 시작 대기 중..."
    sleep 20

    log_info "Ingress Nginx Controller 설치 완료!"
fi

###############################################################################
# 7. cert-manager 설치
###############################################################################
log_info "7/7 cert-manager 설치 중..."
if sudo kubectl get namespace cert-manager &> /dev/null; then
    log_warn "cert-manager 네임스페이스가 이미 존재합니다. 건너뜁니다."
else
    log_info "cert-manager v1.14.0 설치 중..."
    sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

    log_info "cert-manager 파드 시작 대기 중..."
    sleep 20

    log_info "cert-manager 설치 완료!"
fi

###############################################################################
# 8. Infrastructure App of Apps 배포 (선택사항)
###############################################################################
log_info "Infrastructure App of Apps 배포 중..."
if sudo kubectl get application infrastructure -n argocd &> /dev/null 2>&1; then
    log_warn "Infrastructure Application이 이미 존재합니다."
else
    curl -sfL https://raw.githubusercontent.com/Mayne0213/infrastructure/main/application.yaml | sudo kubectl apply -f - || log_warn "application.yaml 배포 실패. 나중에 수동으로 배포하세요."
fi

###############################################################################
# 완료 및 정보 표시
###############################################################################
echo ""
echo "========================================"
echo "  설치 완료!"
echo "========================================"
echo ""

# ArgoCD 초기 비밀번호
log_info "ArgoCD 초기 admin 비밀번호:"
ARGOCD_PASSWORD=$(sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "아직 준비 안 됨")
if [ -n "$ARGOCD_PASSWORD" ] && [ "$ARGOCD_PASSWORD" != "아직 준비 안 됨" ]; then
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    log_warn "위 비밀번호를 안전한 곳에 저장하세요!"
else
    log_warn "ArgoCD 비밀번호를 가져올 수 없습니다. 잠시 후 다음 명령어로 확인하세요:"
    echo "  sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi

echo ""
log_info "설치된 구성 요소:"
echo "  ✅ K3s 마스터 노드"
echo "  ✅ ArgoCD"
echo "  ✅ Ingress Nginx Controller"
echo "  ✅ cert-manager"
echo "  ✅ Infrastructure App of Apps"
echo ""

log_info "클러스터 상태:"
sudo kubectl get nodes
echo ""

log_info "모든 파드 상태:"
sudo kubectl get pods -A
echo ""

log_info "다음 단계:"
echo "  1. ArgoCD 애플리케이션 상태 확인:"
echo "     sudo kubectl get applications -n argocd"
echo ""
echo "  2. Ingress NodePort 확인:"
echo "     sudo kubectl get svc -n ingress-nginx"
echo ""
echo "  3. DNS를 이 서버 IP로 설정하세요"
echo ""

echo "========================================"
log_info "마스터 노드 설정 완료! 🎉"
echo "========================================"

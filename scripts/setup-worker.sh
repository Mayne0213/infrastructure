#!/bin/bash

###############################################################################
# K3s 워커 노드 자동 설치 스크립트
# 용도: k3s 워커 설치 + iptables 설정 + 마스터에 조인
# 실행 방법: bash setup-worker.sh <MASTER_IP> <NODE_TOKEN>
#          또는: K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> bash setup-worker.sh
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
echo "  K3s 워커 노드 자동 설치"
echo "========================================"
echo ""

###############################################################################
# 0. 파라미터 확인
###############################################################################
# 명령줄 인자로 받기
if [ $# -eq 2 ]; then
    MASTER_IP=$1
    NODE_TOKEN=$2
    K3S_URL="https://$MASTER_IP:6443"
elif [ -n "$K3S_URL" ] && [ -n "$K3S_TOKEN" ]; then
    # 환경 변수로 받기
    log_info "환경 변수에서 K3S_URL과 K3S_TOKEN을 가져왔습니다."
else
    log_error "사용법: bash setup-worker.sh <MASTER_IP> <NODE_TOKEN>"
    log_error "   또는: K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> bash setup-worker.sh"
    exit 1
fi

log_info "마스터 URL: $K3S_URL"
echo ""

###############################################################################
# 1. 시스템 업데이트
###############################################################################
log_info "1/4 시스템 패키지 업데이트 중..."
sudo apt-get update -y
sudo apt-get upgrade -y

###############################################################################
# 2. iptables 방화벽 규칙 설정 (k3s 설치 전에)
###############################################################################
log_info "2/4 iptables 방화벽 규칙 설정 중..."

# Kubelet API
sudo iptables -I INPUT 1 -p tcp --dport 10250 -j ACCEPT

# HTTPS (443)
sudo iptables -I INPUT 1 -p tcp --dport 443 -j ACCEPT

# Pod 네트워크 (Flannel)
sudo iptables -I INPUT 1 -s 10.42.0.0/16 -j ACCEPT
sudo iptables -I INPUT 1 -s 10.43.0.0/16 -j ACCEPT
sudo iptables -I OUTPUT 1 -d 10.43.0.0/16 -j ACCEPT
sudo iptables -I FORWARD 1 -s 10.42.0.0/16 -j ACCEPT
sudo iptables -I FORWARD 1 -d 10.42.0.0/16 -j ACCEPT

# iptables 규칙 저장 (재부팅 후에도 유지)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
sudo netfilter-persistent save

log_info "iptables 규칙 설정 완료!"

###############################################################################
# 3. 마스터 노드 연결 테스트
###############################################################################
log_info "3/4 마스터 노드 연결 테스트 중..."

MASTER_HOST=$(echo $K3S_URL | sed 's|https://||' | sed 's|:.*||')
MASTER_PORT=$(echo $K3S_URL | sed 's|.*:||')

if nc -zv $MASTER_HOST $MASTER_PORT 2>&1 | grep -q succeeded; then
    log_info "마스터 노드($MASTER_HOST:$MASTER_PORT) 연결 성공!"
else
    log_error "마스터 노드($MASTER_HOST:$MASTER_PORT)에 연결할 수 없습니다."
    log_error "마스터 노드가 실행 중인지, 방화벽이 올바르게 설정되었는지 확인하세요."
    exit 1
fi

###############################################################################
# 4. K3s 워커 설치 및 마스터 조인
###############################################################################
log_info "4/4 K3s 워커 설치 및 마스터 조인 중..."

if command -v k3s &> /dev/null; then
    log_warn "K3s가 이미 설치되어 있습니다."

    # 기존 설치가 워커 모드인지 확인
    if systemctl is-active --quiet k3s-agent; then
        log_warn "K3s agent가 이미 실행 중입니다. 재시작합니다."
        sudo systemctl restart k3s-agent
    else
        log_error "K3s가 설치되어 있지만 agent 모드가 아닙니다."
        log_error "k3s를 제거하고 다시 시도하세요: /usr/local/bin/k3s-uninstall.sh"
        exit 1
    fi
else
    # K3s 워커 설치
    curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=${NODE_TOKEN:-$K3S_TOKEN} sh -

    log_info "K3s 워커 시작 대기 중..."
    sleep 10

    log_info "K3s 워커 설치 완료!"
fi

# 워커 상태 확인
log_info "K3s agent 상태:"
sudo systemctl status k3s-agent --no-pager | head -15

###############################################################################
# 완료
###############################################################################
echo ""
echo "========================================"
echo "  워커 노드 설치 완료!"
echo "========================================"
echo ""

log_info "워커 노드가 마스터에 조인되었습니다."
log_info "마스터 노드에서 다음 명령어로 확인하세요:"
echo "  sudo kubectl get nodes"
echo ""

log_warn "마스터 노드에서 이 워커가 'Ready' 상태가 될 때까지 약 30초 정도 기다려주세요."
echo ""

echo "========================================"
log_info "워커 노드 설정 완료! 🎉"
echo "========================================"

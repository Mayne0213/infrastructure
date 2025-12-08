#!/bin/bash

###############################################################################
# MariaDB 테이블 생성 스크립트
# Primary DB와 Dev DB에 기본 테이블을 생성합니다.
# 사용법: bash create-mariadb-tables.sh
###############################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Primary DB에 테이블 생성
create_primary_tables() {
    log_info "Primary DB에 테이블 생성 중..."
    
    PRIMARY_POD=$(kubectl get pod -n mariadb -l app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$PRIMARY_POD" ]; then
        log_error "Primary DB Pod를 찾을 수 없습니다. DB가 실행 중인지 확인하세요."
        return 1
    fi
    
    log_info "Primary DB Pod: $PRIMARY_POD"
    
    # Primary DB에 테이블 생성 SQL
    kubectl exec -n mariadb "$PRIMARY_POD" -- mysql -u bluemayne -p'Ma87345364@' -e "
        -- Primary DB 테이블 생성 예시
        CREATE DATABASE IF NOT EXISTS primarydb;
        USE primarydb;
        
        -- 예시 테이블 (필요에 따라 수정)
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL UNIQUE,
            email VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        
        CREATE TABLE IF NOT EXISTS sessions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            session_token VARCHAR(255) NOT NULL UNIQUE,
            expires_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        
        SHOW TABLES;
    " 2>/dev/null || {
        log_error "Primary DB에 테이블 생성 실패"
        return 1
    }
    
    log_info "Primary DB 테이블 생성 완료!"
}

# Dev DB에 테이블 생성
create_dev_tables() {
    log_info "Dev DB에 테이블 생성 중..."
    
    DEV_POD=$(kubectl get pod -n mariadb-dev -l app.kubernetes.io/component=primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$DEV_POD" ]; then
        log_error "Dev DB Pod를 찾을 수 없습니다. DB가 실행 중인지 확인하세요."
        return 1
    fi
    
    log_info "Dev DB Pod: $DEV_POD"
    
    # Dev DB에 테이블 생성 SQL (devdb 데이터베이스 사용)
    kubectl exec -n mariadb-dev "$DEV_POD" -- mysql -u bluemayne -p'Ma87345364@' devdb -e "
        -- Dev DB 테이블 생성 예시
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL UNIQUE,
            email VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        
        CREATE TABLE IF NOT EXISTS sessions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            session_token VARCHAR(255) NOT NULL UNIQUE,
            expires_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        
        SHOW TABLES;
    " 2>/dev/null || {
        log_error "Dev DB에 테이블 생성 실패"
        return 1
    }
    
    log_info "Dev DB 테이블 생성 완료!"
}

# 메인 실행
main() {
    echo "========================================"
    echo "  MariaDB 테이블 생성 스크립트"
    echo "========================================"
    echo ""
    
    # Primary DB 테이블 생성
    if create_primary_tables; then
        log_info "✅ Primary DB 테이블 생성 성공"
    else
        log_warn "⚠️  Primary DB 테이블 생성 실패 (나중에 수동으로 생성하세요)"
    fi
    
    echo ""
    
    # Dev DB 테이블 생성
    if create_dev_tables; then
        log_info "✅ Dev DB 테이블 생성 성공"
    else
        log_warn "⚠️  Dev DB 테이블 생성 실패 (나중에 수동으로 생성하세요)"
    fi
    
    echo ""
    echo "========================================"
    log_info "테이블 생성 작업 완료!"
    echo "========================================"
}

main "$@"

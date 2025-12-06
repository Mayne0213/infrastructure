# Sealed Secrets 사용 가이드

Sealed Secrets를 사용하여 Kubernetes Secret을 Git에 안전하게 저장하는 방법입니다.

## 설치 확인

```bash
# Controller 상태 확인
kubectl get pods -n sealed-secrets

# Public key 가져오기
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=sealed-secrets \
  > pub-cert.pem
```

## Secret을 SealedSecret으로 변환

### 방법 1: 기존 Secret에서 변환

```bash
# 기존 Secret 가져오기
kubectl get secret <secret-name> -n <namespace> -o yaml > secret.yaml

# SealedSecret으로 변환
kubeseal --format=yaml \
  --cert=pub-cert.pem \
  < secret.yaml > sealed-secret.yaml

# Git에 커밋
git add sealed-secret.yaml
git commit -m "Add sealed secret for <secret-name>"
git push
```

### 방법 2: 직접 생성

```bash
# 일반 Secret manifest 생성
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  --dry-run=client -o yaml > secret.yaml

# SealedSecret으로 변환
kubeseal --format=yaml \
  --cert=pub-cert.pem \
  < secret.yaml > sealed-secret.yaml
```

## Scope 옵션

SealedSecret은 3가지 scope를 지원합니다:

1. **strict** (기본값): 동일한 namespace와 이름에서만 복호화 가능
2. **namespace-wide**: 동일한 namespace 내 어떤 이름으로든 복호화 가능
3. **cluster-wide**: 모든 namespace에서 복호화 가능

```bash
# namespace-wide scope 사용
kubeseal --format=yaml \
  --cert=pub-cert.pem \
  --scope=namespace-wide \
  < secret.yaml > sealed-secret.yaml
```

## GitHub Actions에서 사용

```yaml
- name: Install kubeseal
  run: |
    wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.2/kubeseal-0.26.2-linux-amd64.tar.gz
    tar xfz kubeseal-0.26.2-linux-amd64.tar.gz
    sudo mv kubeseal /usr/local/bin/

- name: Create sealed secret
  run: |
    kubectl create secret generic app-secret \
      --from-literal=API_KEY=${{ secrets.API_KEY }} \
      --dry-run=client -o yaml | \
    kubeseal --format=yaml \
      --cert=pub-cert.pem \
      > deploy/k8s/sealed-secret.yaml
```

## 주의사항

1. **Public Key 백업**: `pub-cert.pem`을 안전하게 보관하세요
2. **Private Key 백업**: Controller의 private key를 백업하세요
   ```bash
   kubectl get secret -n sealed-secrets \
     -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
     -o yaml > sealed-secrets-key.yaml
   ```
3. **Key Rotation**: Controller는 30일마다 자동으로 key를 갱신합니다
4. **Git에 저장 금지**:
   - 원본 `secret.yaml` 파일
   - Private key
   - `pub-cert.pem`은 public이지만 `.gitignore`에 추가 권장

## 트러블슈팅

### SealedSecret이 복호화되지 않는 경우

```bash
# SealedSecret 상태 확인
kubectl get sealedsecret <name> -n <namespace> -o yaml

# Controller 로그 확인
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller
```

### Public key 가져오기 실패

```bash
# Port-forward로 직접 접근
kubectl port-forward -n sealed-secrets svc/sealed-secrets-controller 8080:8080
kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=sealed-secrets > pub-cert.pem
```

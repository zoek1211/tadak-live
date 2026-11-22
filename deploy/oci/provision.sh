#!/usr/bin/env bash
# OCI 자원 생성(있으면 재사용): SSH 키 -> VCN -> 인터넷 게이트웨이·라우트 -> 보안 목록 -> 서브넷 -> 인스턴스 -> 예약 공인 IP
# -> 배포 사용자 deploy(CI 전용 키) -> deploy/vm/ 설정을 /opt/tadak 에 올리고 docker compose up -d.
# 결과는 deploy/oci/.state.env 에 쓴다(커밋 금지). 다시 실행해도 새 자원이 생기지 않는다.
# 필요 도구: oci, jq, ssh, ssh-keygen, scp. 인증: oci session authenticate --profile-name tadak
# 선택 환경변수: TADAK_A1_RETRIES(기본 6), TADAK_A1_RETRY_SECONDS(기본 300),
#   TADAK_ACME_STAGING=1(Let's Encrypt 스테이징 CA로 발급. 발급 경로 확인용, 브라우저는 신뢰하지 않음)
#   TADAK_SSH_KEY(기본 ~/.ssh/tadak_oci, 관리용), TADAK_DEPLOY_KEY(기본 ~/.ssh/tadak_deploy, CI 배포용)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/lib.sh
source "$DIR/lib.sh"

STATE_FILE="$DIR/.state.env"
CLOUD_INIT="$DIR/cloud-init.yaml"
VM_CONFIG_DIR="$(cd "$DIR/../vm" && pwd)"
ACME_PROD="https://acme-v02.api.letsencrypt.org/directory"
ACME_STAGING="https://acme-staging-v02.api.letsencrypt.org/directory"
SSH_KEY="${TADAK_SSH_KEY:-$HOME/.ssh/tadak_oci}"
DEPLOY_KEY="${TADAK_DEPLOY_KEY:-$HOME/.ssh/tadak_deploy}"
KNOWN_HOSTS="$HOME/.ssh/tadak_oci_known_hosts"
A1_RETRIES="${TADAK_A1_RETRIES:-6}"
A1_RETRY_SECONDS="${TADAK_A1_RETRY_SECONDS:-300}"

VCN_NAME="tadak-vcn"
IGW_NAME="tadak-igw"
SL_NAME="tadak-sl"
SUBNET_NAME="tadak-subnet"
VM_NAME="tadak-vm"
IP_NAME="tadak-ip"

# 인터넷에서 들어오는 것은 22/80/443(TCP)과 경로 MTU 탐색용 ICMP(3,4)뿐
INGRESS='[
  {"protocol":"6","source":"0.0.0.0/0","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
  {"protocol":"6","source":"0.0.0.0/0","tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
  {"protocol":"6","source":"0.0.0.0/0","tcpOptions":{"destinationPortRange":{"min":443,"max":443}}},
  {"protocol":"1","source":"0.0.0.0/0","icmpOptions":{"type":3,"code":4}}
]'
EGRESS='[{"protocol":"all","destination":"0.0.0.0/0"}]'

require_tools oci jq ssh ssh-keygen scp
oci_init

SSH_OPTS=(-o UserKnownHostsFile="$KNOWN_HOSTS" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes)

# 관리용(ubuntu, sudo 가능): 사용자·방화벽 같은 VM 설정
ssh_vm() {
  ssh -i "$SSH_KEY" "${SSH_OPTS[@]}" "ubuntu@$PUBLIC_IP" "$@"
}

# 배포용(deploy, docker 그룹·sudo 없음): /opt/tadak 파일과 docker compose. CI도 같은 사용자로 들어온다
ssh_deploy() {
  ssh -i "$DEPLOY_KEY" "${SSH_OPTS[@]}" "deploy@$PUBLIC_IP" "$@"
}
scp_deploy() {
  scp -q -i "$DEPLOY_KEY" "${SSH_OPTS[@]}" "$@"
}

ensure_key() {
  local key="$1" comment="$2"
  echo "==> SSH 키 $key 확인"
  if [[ -f "$key" ]]; then
    echo "    이미 있어 재사용합니다."
  else
    ssh-keygen -t ed25519 -N "" -C "$comment" -f "$key" >/dev/null
    echo "    만들었습니다(비밀 키는 이 컴퓨터에만 있음)."
  fi
}
ensure_key "$SSH_KEY" "tadak-oci"
# CI 배포 전용 키. 비밀 키는 사용자가 GitHub Secret VM_SSH_KEY 로 직접 넣는다
ensure_key "$DEPLOY_KEY" "tadak-deploy"

echo "==> VCN '$VCN_NAME' 확인"
VCN_ID="$("${OCI[@]}" network vcn list -c "$TENANCY" --display-name "$VCN_NAME" --lifecycle-state AVAILABLE --all \
  | jq -r '.data[0].id // empty')"
if [[ -z "$VCN_ID" ]]; then
  VCN_ID="$("${OCI[@]}" network vcn create -c "$TENANCY" --display-name "$VCN_NAME" --dns-label tadak \
    --cidr-blocks '["10.0.0.0/16"]' --freeform-tags "$TAGS" --wait-for-state AVAILABLE | jq -r '.data.id')"
  echo "    만들었습니다."
else
  echo "    이미 있어 재사용합니다."
fi
RT_ID="$("${OCI[@]}" network vcn get --vcn-id "$VCN_ID" | jq -r '.data."default-route-table-id"')"

echo "==> 인터넷 게이트웨이 '$IGW_NAME' 확인"
IGW_ID="$("${OCI[@]}" network internet-gateway list -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$IGW_NAME" \
  --lifecycle-state AVAILABLE --all | jq -r '.data[0].id // empty')"
if [[ -z "$IGW_ID" ]]; then
  IGW_ID="$("${OCI[@]}" network internet-gateway create -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$IGW_NAME" \
    --is-enabled true --freeform-tags "$TAGS" --wait-for-state AVAILABLE | jq -r '.data.id')"
  echo "    만들었습니다."
else
  echo "    이미 있어 재사용합니다."
fi

echo "==> 기본 라우트 테이블에 0.0.0.0/0 -> 인터넷 게이트웨이"
"${OCI[@]}" network route-table update --rt-id "$RT_ID" --force \
  --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"$IGW_ID\"}]" >/dev/null

echo "==> 보안 목록 '$SL_NAME' 확인(수신 22/80/443만)"
SL_ID="$("${OCI[@]}" network security-list list -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$SL_NAME" \
  --lifecycle-state AVAILABLE --all | jq -r '.data[0].id // empty')"
if [[ -z "$SL_ID" ]]; then
  SL_ID="$("${OCI[@]}" network security-list create -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$SL_NAME" \
    --ingress-security-rules "$INGRESS" --egress-security-rules "$EGRESS" --freeform-tags "$TAGS" \
    --wait-for-state AVAILABLE | jq -r '.data.id')"
  echo "    만들었습니다."
else
  # 손으로 바뀌었을 수 있으니 규칙을 스크립트 기준으로 되돌린다
  "${OCI[@]}" network security-list update --security-list-id "$SL_ID" --force \
    --ingress-security-rules "$INGRESS" --egress-security-rules "$EGRESS" >/dev/null
  echo "    이미 있어 재사용합니다(규칙 재적용)."
fi

echo "==> 서브넷 '$SUBNET_NAME' 확인"
SUBNET_ID="$("${OCI[@]}" network subnet list -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$SUBNET_NAME" \
  --lifecycle-state AVAILABLE --all | jq -r '.data[0].id // empty')"
if [[ -z "$SUBNET_ID" ]]; then
  SUBNET_ID="$("${OCI[@]}" network subnet create -c "$TENANCY" --vcn-id "$VCN_ID" --display-name "$SUBNET_NAME" \
    --cidr-block 10.0.0.0/24 --dns-label pub --route-table-id "$RT_ID" --security-list-ids "[\"$SL_ID\"]" \
    --prohibit-public-ip-on-vnic false --freeform-tags "$TAGS" --wait-for-state AVAILABLE | jq -r '.data.id')"
  echo "    만들었습니다."
else
  # VCN 기본 보안 목록이 붙지 않게 우리 보안 목록 하나만 둔다
  "${OCI[@]}" network subnet update --subnet-id "$SUBNET_ID" --security-list-ids "[\"$SL_ID\"]" --force >/dev/null
  echo "    이미 있어 재사용합니다."
fi

AD="$("${OCI[@]}" iam availability-domain list -c "$TENANCY" | jq -r '.data[0].name')"

image_for() {
  "${OCI[@]}" compute image list -c "$TENANCY" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
    --shape "$1" --sort-by TIMECREATED --sort-order DESC --all | jq -r '.data[0].id // empty'
}

# 성공하면 INSTANCE_ID 를 정하고 0, 재고 부족이면 2, 그 밖의 실패는 1
launch() {
  local shape="$1" image err out
  local extra=()
  image="$(image_for "$shape")"
  [[ -n "$image" ]] || { echo "    $shape 용 Ubuntu 24.04 이미지가 없습니다." >&2; return 1; }
  [[ "$shape" == "VM.Standard.A1.Flex" ]] && extra=(--shape-config '{"ocpus":2,"memoryInGBs":12}')
  err="$(mktemp)"
  if out="$("${OCI[@]}" compute instance launch -c "$TENANCY" --availability-domain "$AD" --shape "$shape" \
      ${extra[@]+"${extra[@]}"} --image-id "$image" --subnet-id "$SUBNET_ID" --assign-public-ip false \
      --display-name "$VM_NAME" --hostname-label tadak --ssh-authorized-keys-file "$SSH_KEY.pub" \
      --user-data-file "$CLOUD_INIT" --freeform-tags "$TAGS" --wait-for-state RUNNING 2>"$err")"; then
    INSTANCE_ID="$(jq -r '.data.id' <<<"$out")"
    rm -f "$err"
    return 0
  fi
  LAST_ERROR="$(tr '\n' ' ' <"$err" | cut -c1-300)"
  rm -f "$err"
  grep -qi "out of host capacity\|out of capacity" <<<"$LAST_ERROR" && return 2
  return 1
}

echo "==> 인스턴스 '$VM_NAME' 확인"
FALLBACK_REASON=""
NEW_INSTANCE=0
INSTANCE_JSON="$("${OCI[@]}" compute instance list -c "$TENANCY" --display-name "$VM_NAME" --all \
  | jq -c '[.data[] | select(."lifecycle-state" != "TERMINATED" and ."lifecycle-state" != "TERMINATING")][0] // empty')"
if [[ -n "$INSTANCE_JSON" ]]; then
  INSTANCE_ID="$(jq -r '.id' <<<"$INSTANCE_JSON")"
  SHAPE="$(jq -r '.shape' <<<"$INSTANCE_JSON")"
  STATE="$(jq -r '."lifecycle-state"' <<<"$INSTANCE_JSON")"
  echo "    이미 있어 재사용합니다($SHAPE, $STATE)."
  if [[ "$STATE" == "STOPPED" ]]; then
    "${OCI[@]}" compute instance action --instance-id "$INSTANCE_ID" --action START --wait-for-state RUNNING >/dev/null
    echo "    중지돼 있어 시작했습니다."
  fi
  if [[ -f "$STATE_FILE" ]]; then
    FALLBACK_REASON="$(sed -n 's/^FALLBACK_REASON=//p' "$STATE_FILE" | sed 's/^"//;s/"$//')"
  fi
else
  SHAPE="VM.Standard.A1.Flex"
  attempt=1
  while :; do
    ensure_session
    echo "    $SHAPE 2 OCPU·12GB 생성 시도 $attempt/$((A1_RETRIES + 1))"
    rc=0; launch "$SHAPE" || rc=$?
    [[ $rc -eq 0 ]] && break
    if [[ $rc -eq 1 ]]; then
      echo "    생성 실패: $LAST_ERROR" >&2
      exit 1
    fi
    if (( attempt > A1_RETRIES )); then
      FALLBACK_REASON="A1 재고 부족($((A1_RETRIES + 1))회 시도): $LAST_ERROR"
      echo "    A1 재고가 없어 VM.Standard.E2.1.Micro 로 넘어갑니다."
      SHAPE="VM.Standard.E2.1.Micro"
      ensure_session
      rc=0; launch "$SHAPE" || rc=$?
      [[ $rc -eq 0 ]] || { echo "    E2.1.Micro 생성도 실패: $LAST_ERROR" >&2; exit 1; }
      break
    fi
    echo "    재고 부족. ${A1_RETRY_SECONDS}초 뒤 다시 시도합니다."
    sleep "$A1_RETRY_SECONDS"
    attempt=$((attempt + 1))
  done
  NEW_INSTANCE=1
  echo "    만들었습니다($SHAPE)."
fi

echo "==> 예약 공인 IP '$IP_NAME' 확인"
VNIC_ID="$("${OCI[@]}" compute instance list-vnics --instance-id "$INSTANCE_ID" | jq -r '.data[0].id')"
PRIVATE_IP_ID="$("${OCI[@]}" network private-ip list --vnic-id "$VNIC_ID" | jq -r '.data[] | select(."is-primary") | .id')"
IP_JSON="$("${OCI[@]}" network public-ip list -c "$TENANCY" --scope REGION --lifetime RESERVED --all \
  | jq -c --arg n "$IP_NAME" '[.data[] | select(."display-name" == $n and ."lifecycle-state" != "TERMINATED")][0] // empty')"
if [[ -z "$IP_JSON" ]]; then
  IP_JSON="$("${OCI[@]}" network public-ip create -c "$TENANCY" --lifetime RESERVED --display-name "$IP_NAME" \
    --private-ip-id "$PRIVATE_IP_ID" --freeform-tags "$TAGS" --wait-for-state ASSIGNED | jq -c '.data')"
  echo "    만들어 인스턴스에 붙였습니다."
elif [[ "$(jq -r '."private-ip-id" // empty' <<<"$IP_JSON")" != "$PRIVATE_IP_ID" ]]; then
  IP_JSON="$("${OCI[@]}" network public-ip update --public-ip-id "$(jq -r '.id' <<<"$IP_JSON")" \
    --private-ip-id "$PRIVATE_IP_ID" --wait-for-state ASSIGNED | jq -c '.data')"
  echo "    이미 있어 인스턴스에 다시 붙였습니다."
else
  echo "    이미 붙어 있어 재사용합니다."
fi
PUBLIC_IP="$(jq -r '."ip-address"' <<<"$IP_JSON")"
TADAK_HOST="${PUBLIC_IP//./-}.sslip.io"

cat >"$STATE_FILE" <<EOF
# provision.sh 가 쓴다. 커밋 금지.
REGION=$HOME_REGION
VCN_ID=$VCN_ID
SUBNET_ID=$SUBNET_ID
SECURITY_LIST_ID=$SL_ID
INSTANCE_ID=$INSTANCE_ID
SHAPE=$SHAPE
PUBLIC_IP=$PUBLIC_IP
TADAK_HOST=$TADAK_HOST
FALLBACK_REASON="$FALLBACK_REASON"
EOF
chmod 600 "$STATE_FILE"
echo "==> 상태 기록: $STATE_FILE"

# 새 인스턴스면 같은 예약 IP에 이전 호스트 키가 남아 있을 수 있다
if [[ $NEW_INSTANCE -eq 1 && -f "$KNOWN_HOSTS" ]]; then
  ssh-keygen -R "$PUBLIC_IP" -f "$KNOWN_HOSTS" >/dev/null 2>&1 || true
fi

echo "==> SSH 접속 대기(ubuntu@$PUBLIC_IP)"
for _ in $(seq 1 60); do
  ssh_vm true 2>/dev/null && break
  sleep 5
done
ssh_vm true || { echo "    SSH 접속이 안 됩니다. 보안 목록과 인스턴스 상태를 확인하세요." >&2; exit 1; }

echo "==> cloud-init 완료 대기(Docker 설치)"
ssh_vm 'cloud-init status --wait >/dev/null; cloud-init status'
ssh_vm 'docker compose version'

echo "==> 배포 사용자 deploy 확인(docker 그룹, 키 $DEPLOY_KEY.pub, /opt/tadak 소유)"
# authorized_keys 는 매번 이 공개 키 하나로 덮는다(키를 바꾸면 재실행으로 교체됨)
ssh_vm "sudo DEPLOY_PUB='$(cat "$DEPLOY_KEY.pub")' bash -s" <<'EOF'
set -euo pipefail
id deploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash deploy
usermod -aG docker deploy
install -d -o deploy -g deploy -m 700 /home/deploy/.ssh
printf '%s\n' "$DEPLOY_PUB" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
install -d -o deploy -g deploy -m 755 /opt/tadak /opt/tadak/caddy
chown -R deploy:deploy /opt/tadak
EOF
ssh_deploy 'id -nG' | grep -qw docker || { echo "    deploy 사용자가 docker 그룹에 없습니다." >&2; exit 1; }
echo "    준비됐습니다."

ACME_CA="$ACME_PROD"
[[ "${TADAK_ACME_STAGING:-}" == "1" ]] && ACME_CA="$ACME_STAGING"
echo "==> 설정 배포: deploy/vm -> /opt/tadak (인증서 발급처: $ACME_CA)"
scp_deploy "$VM_CONFIG_DIR/compose.yaml" "deploy@$PUBLIC_IP:/opt/tadak/compose.yaml"
scp_deploy "$VM_CONFIG_DIR/Caddyfile" "deploy@$PUBLIC_IP:/opt/tadak/caddy/Caddyfile"
scp_deploy "$VM_CONFIG_DIR/deploy.sh" "deploy@$PUBLIC_IP:/opt/tadak/deploy.sh"
ssh_deploy 'chmod 755 /opt/tadak/deploy.sh'
# .env 는 VM에서만 만든다(권한 600). 앱 설정·비밀 값은 배포(deploy.sh)가 같은 파일에 더한다.
ssh_deploy "umask 077; touch /opt/tadak/.env; grep -vE '^(TADAK_HOST|TADAK_ACME_CA)=' /opt/tadak/.env > /opt/tadak/.env.new || true; \
  printf 'TADAK_HOST=%s\nTADAK_ACME_CA=%s\n' '$TADAK_HOST' '$ACME_CA' >> /opt/tadak/.env.new; mv /opt/tadak/.env.new /opt/tadak/.env"
# Caddy만 띄우거나 갱신한다. 앱은 deploy.sh 가 이미지와 함께 다룬다(첫 배포 전에는 앱이 없어 502)
ssh_deploy 'cd /opt/tadak && docker compose up -d --quiet-pull caddy && docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile'

echo
echo "완료: $SHAPE, 공인 IP $PUBLIC_IP, 주소 https://$TADAK_HOST"
echo "확인: deploy/oci/verify.sh"
[[ -z "$FALLBACK_REASON" ]] || echo "A1 대신 E2.1.Micro 를 쓴 이유: $FALLBACK_REASON"

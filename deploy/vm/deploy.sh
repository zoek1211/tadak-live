#!/usr/bin/env bash
# VM(/opt/tadak)에서 deploy 사용자로 실행: 앱 이미지를 바꾸고 헬스를 확인한다. 실패하면 이전 이미지로 되돌리고 종료 코드 1.
# 사용: deploy.sh <이미지> [--secrets-from-stdin]
#   --secrets-from-stdin: 표준 입력의 KEY=VALUE 줄(TOSS_*, CHZZK_TURN_*)로 .env 의 비밀 값을 통째로 바꾼다(없는 키는 지움).
# 레지스트리 로그인은 부르는 쪽이 미리 한다. 이미지가 로컬에 있으면 받지 않는다(커밋 SHA 태그라 내용이 바뀌지 않음).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
ENV_FILE=.env
SECRET_KEYS_RE='^(TOSS_CLIENT_KEY|TOSS_SECRET_KEY|CHZZK_TURN_URL|CHZZK_TURN_USERNAME|CHZZK_TURN_CREDENTIAL)='
HEALTH_TRIES="${TADAK_HEALTH_TRIES:-24}"   # 5초 간격, 기본 2분
umask 077

IMAGE="${1:-}"
[[ -n "$IMAGE" ]] || { echo "사용: $0 <이미지> [--secrets-from-stdin]" >&2; exit 2; }
[[ -f "$ENV_FILE" ]] || { echo "$PWD/$ENV_FILE 이 없습니다. 먼저 provision.sh 를 실행하세요." >&2; exit 1; }

get_env() { sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1; }
# 한 키를 바꾸거나 더한다(값은 그대로 한 줄)
set_env() {
  grep -v "^$1=" "$ENV_FILE" > "$ENV_FILE.new" || true
  printf '%s=%s\n' "$1" "$2" >> "$ENV_FILE.new"
  mv "$ENV_FILE.new" "$ENV_FILE"
}

TADAK_HOST="$(get_env TADAK_HOST)"
[[ -n "$TADAK_HOST" ]] || { echo "$ENV_FILE 에 TADAK_HOST 가 없습니다." >&2; exit 1; }

if [[ "${2:-}" == "--secrets-from-stdin" ]]; then
  echo "==> 비밀 값 갱신(표준 입력)"
  secrets="$(grep -E "$SECRET_KEYS_RE" || true)"
  grep -Ev "$SECRET_KEYS_RE" "$ENV_FILE" > "$ENV_FILE.new" || true
  [[ -z "$secrets" ]] || printf '%s\n' "$secrets" >> "$ENV_FILE.new"
  mv "$ENV_FILE.new" "$ENV_FILE"
  echo "    키 $(printf '%s' "$secrets" | grep -c . || true)개(값은 출력하지 않음)"
fi

# 배포 환경 고정값: Caddy 뒤 HTTPS라 세션 쿠키에 Secure, 데이터는 볼륨(/data)
set_env CHZZK_COOKIE_SECURE true
set_env CHZZK_DATA_DIR /data

healthy() {
  local i
  for ((i = 1; i <= HEALTH_TRIES; i++)); do
    # 외부와 같은 경로(Caddy·인증서)로 확인하되 VM 자신에게 보낸다
    if curl -fsS --max-time 5 --resolve "$TADAK_HOST:443:127.0.0.1" "https://$TADAK_HOST/actuator/health" 2>/dev/null \
        | grep -q '"status":"UP"'; then
      return 0
    fi
    sleep 5
  done
  return 1
}

switch_to() {
  set_env TADAK_IMAGE "$1"
  docker compose up -d --remove-orphans --quiet-pull
  docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 || true
}

PREV="$(get_env TADAK_IMAGE)"
echo "==> 이미지 준비: $IMAGE (이전: ${PREV:-없음})"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  if ! docker pull --quiet "$IMAGE" >/dev/null; then
    echo "    이미지를 받지 못했습니다. 바꾸지 않고 끝냅니다(서비스는 이전 이미지 그대로)." >&2
    exit 1
  fi
fi

echo "==> 앱 교체"
switch_to "$IMAGE"

echo "==> 헬스 확인(최대 $((HEALTH_TRIES * 5))초)"
if healthy; then
  echo "    UP. 배포 완료: $IMAGE"
  docker image prune -f >/dev/null 2>&1 || true
  exit 0
fi

echo "    헬스 확인 실패. 최근 앱 로그:" >&2
docker compose logs --tail 30 app >&2 || true
if [[ -z "$PREV" || "$PREV" == "$IMAGE" ]]; then
  echo "    되돌릴 이전 이미지가 없습니다." >&2
  exit 1
fi
echo "==> 이전 이미지로 되돌림: $PREV" >&2
switch_to "$PREV"
if healthy; then
  echo "    되돌림 완료(UP). 배포는 실패로 끝냅니다." >&2
else
  echo "    되돌린 뒤에도 헬스가 UP이 아닙니다. 확인이 필요합니다." >&2
fi
exit 1

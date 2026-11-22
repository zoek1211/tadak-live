#!/usr/bin/env bash
# 외부(이 컴퓨터)에서 VM의 HTTPS를 확인한다. 하나라도 실패하면 종료 코드 1.
# 사용: verify.sh [--app]
#  1) https://<host>/ 에 인증서 검증을 통과해 접속된다(시스템 신뢰 저장소)
#  2) 인증서 발급자가 Let's Encrypt 운영 CA, SAN에 <host> 포함
#  3) http://<host>/ 가 https://<host>/ 로 리다이렉트
#  4) 외부에서 8080 연결 실패
#  --app(앱 배포 뒤): 5) / 가 https 의 /broadcasts 로 가고 200, "타닥 라이브" 화면  6) /actuator/health UP  7) /actuator/env 404
#                     8) 로그인 세션 쿠키(JSESSIONID)에 Secure
#                     9) /api/broadcasts 200, live·recorded 배열, 서버 주소가 모두 https://<host>/, 다른 출처 CORS 허용
#                     10) /download 200, Windows·macOS 설치 파일 링크가 실제로 내려받아짐(Release 고정 주소)
# 필요 도구: curl, openssl(--app 은 jq 도). 주소는 deploy/oci/.state.env 의 TADAK_HOST, PUBLIC_IP.
# 선택 환경변수: TADAK_ALLOW_STAGING=1(스테이징 인증서 허용, 1번은 -k)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$DIR/.state.env"
ALLOW_STAGING="${TADAK_ALLOW_STAGING:-}"
APP=0
[[ "${1:-}" == "--app" ]] && APP=1

tools=(curl openssl)
[[ $APP -eq 1 ]] && tools+=(jq)
for tool in "${tools[@]}"; do
  command -v "$tool" >/dev/null || { echo "필요한 도구가 없습니다: $tool" >&2; exit 1; }
done
[[ -f "$STATE_FILE" ]] || { echo "$STATE_FILE 이 없습니다. 먼저 deploy/oci/provision.sh 를 실행하세요." >&2; exit 1; }
TADAK_HOST="$(sed -n 's/^TADAK_HOST=//p' "$STATE_FILE")"
PUBLIC_IP="$(sed -n 's/^PUBLIC_IP=//p' "$STATE_FILE")"
[[ -n "$TADAK_HOST" && -n "$PUBLIC_IP" ]] || { echo "$STATE_FILE 에 TADAK_HOST·PUBLIC_IP 가 없습니다." >&2; exit 1; }

FAILED=0
pass() { echo "  통과: $1"; }
fail() { echo "  실패: $1"; FAILED=1; }

echo "==> 대상: https://$TADAK_HOST ($PUBLIC_IP)"

# 1) HTTPS 접속(인증서 검증). 앱이 아직 없으면 Caddy가 502를 내도 접속 자체는 통과
insecure=()
[[ "$ALLOW_STAGING" == "1" ]] && insecure=(-k)
code="$(curl -sS --max-time 15 ${insecure[@]+"${insecure[@]}"} -o /dev/null -w '%{http_code}' "https://$TADAK_HOST/" 2>&1)"
if [[ "$code" =~ ^[0-9]{3}$ && "$code" != "000" ]]; then
  pass "HTTPS 접속(응답 코드 $code)"
else
  fail "HTTPS 접속 실패: $code"
fi

# 2) 인증서 발급자·SAN
cert="$(openssl s_client -connect "$PUBLIC_IP:443" -servername "$TADAK_HOST" </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -ext subjectAltName 2>/dev/null)"
issuer="$(grep -i '^issuer' <<<"$cert")"
if ! grep -q "Let's Encrypt" <<<"$issuer"; then
  fail "발급자가 Let's Encrypt가 아닙니다: ${issuer:-인증서를 읽지 못함}"
elif grep -qi "staging\|(STAGING)" <<<"$issuer"; then
  if [[ "$ALLOW_STAGING" == "1" ]]; then pass "스테이징 발급자(허용됨): $issuer"; else fail "스테이징 인증서입니다: $issuer"; fi
else
  pass "운영 CA 발급자: $issuer"
fi
if grep -q "DNS:$TADAK_HOST" <<<"$cert"; then pass "SAN에 $TADAK_HOST 포함"; else fail "SAN에 $TADAK_HOST 가 없습니다"; fi

# 3) HTTP -> HTTPS
redirect="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code} %{redirect_url}' "http://$TADAK_HOST/" 2>&1)"
if [[ "$redirect" =~ ^30[178]\ https://$TADAK_HOST/ ]]; then
  pass "HTTP → HTTPS 리다이렉트($redirect)"
else
  fail "HTTP 리다이렉트가 다릅니다: $redirect"
fi

# 4) 8080 차단
if curl -s --max-time 6 --connect-timeout 5 -o /dev/null "http://$PUBLIC_IP:8080/"; then
  fail "외부에서 8080 에 연결됩니다"
else
  pass "외부에서 8080 연결 안 됨"
fi

if [[ $APP -eq 1 ]]; then
  # 5) 방송 목록 화면
  page="$(curl -sS -L --proto-redir =https --max-time 15 -w '\n%{http_code}' "https://$TADAK_HOST/" 2>&1)"
  if [[ "${page##*$'\n'}" == "200" ]] && grep -q "타닥 라이브" <<<"$page"; then
    pass "/ → https /broadcasts 200, 타닥 라이브 화면"
  else
    fail "/ 응답이 다릅니다(코드 ${page##*$'\n'})"
  fi
  # 6) 헬스
  health="$(curl -sS --max-time 10 "https://$TADAK_HOST/actuator/health" 2>&1)"
  if grep -q '"status":"UP"' <<<"$health"; then pass "/actuator/health UP"; else fail "/actuator/health: $health"; fi
  # 7) 다른 actuator 비공개
  env_code="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "https://$TADAK_HOST/actuator/env")"
  if [[ "$env_code" == "404" ]]; then pass "/actuator/env 404"; else fail "/actuator/env 코드 $env_code"; fi
  # 8) 로그인이 필요한 화면에 비로그인으로 가면 세션이 생긴다(돌아갈 주소 저장). 데이터는 만들지 않는다
  cookie="$(curl -sS --max-time 10 -o /dev/null -D - "https://$TADAK_HOST/broadcasts/new" | tr -d '\r' \
    | grep -i '^set-cookie: JSESSIONID=' | head -n 1)"
  if grep -qi '; *Secure' <<<"$cookie"; then
    pass "세션 쿠키 Secure"
  else
    fail "세션 쿠키에 Secure가 없습니다: ${cookie:-JSESSIONID 없음}"
  fi
  # 9) 목록 API(데스크톱 앱용): 계약 모양, 이 서버가 만든 주소는 https 공개 주소, 다른 출처 허용
  api_headers="$(mktemp)"
  api="$(curl -sS --max-time 10 -D "$api_headers" -H 'Origin: tauri://localhost' "https://$TADAK_HOST/api/broadcasts" 2>&1)"
  if ! jq -e '(.live | type == "array") and (.recorded | type == "array")' >/dev/null 2>&1 <<<"$api"; then
    fail "/api/broadcasts 응답이 계약과 다릅니다: $(head -c 120 <<<"$api")"
  else
    counts="$(jq -r '"라이브 \(.live | length), 녹화 \(.recorded | length)"' <<<"$api")"
    bad="$(jq -r --arg base "https://$TADAK_HOST/" \
      '[.live[].watchUrl, .recorded[].watchUrl, (.recorded[] | select(.videoSource == "UPLOADED") | .playbackUrl)]
       | map(select(startswith($base) | not)) | .[]' <<<"$api")"
    if [[ -z "$bad" ]]; then pass "/api/broadcasts 계약·https 주소($counts)"; else fail "https 공개 주소가 아닌 주소: $bad"; fi
  fi
  if tr -d '\r' <"$api_headers" | grep -qi '^access-control-allow-origin: \*$'; then
    pass "/api/broadcasts CORS 허용(*)"
  else
    fail "/api/broadcasts 에 CORS 허용 헤더가 없습니다"
  fi
  rm -f "$api_headers"
  # 10) 앱 받기 페이지: 링크 두 개를 페이지에서 꺼내 실제로 내려받아지는지(리다이렉트 따라가 200) 확인
  download="$(curl -sS --max-time 10 -w '\n%{http_code}' "https://$TADAK_HOST/download" 2>&1)"
  if [[ "${download##*$'\n'}" != "200" ]]; then
    fail "/download 응답 코드 ${download##*$'\n'}"
  else
    links="$(grep -oE 'href="[^"]+/Tadak-Live-(windows-x64-setup\.exe|macos-universal\.dmg)"' <<<"$download" | sed 's/^href="//; s/"$//' | sort -u)"
    if [[ "$(grep -c . <<<"$links")" -ne 2 ]]; then
      fail "/download 에 설치 파일 링크 두 개가 없습니다"
    else
      bad_links=""
      while IFS= read -r link; do
        code="$(curl -s -o /dev/null -I -L --max-time 20 -w '%{http_code}' "$link")"
        [[ "$code" == "200" ]] || bad_links+=" $link($code)"
      done <<<"$links"
      if [[ -z "$bad_links" ]]; then pass "/download 200, 설치 파일 링크 2개 내려받기 가능"; else fail "내려받을 수 없는 링크:$bad_links"; fi
    fi
  fi
fi

if [[ $FAILED -eq 0 ]]; then
  echo "결과: 모두 통과"
else
  echo "결과: 실패 항목 있음" >&2
fi
exit "$FAILED"

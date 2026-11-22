#!/usr/bin/env bash
# 외부(이 컴퓨터)에서 VM의 HTTPS를 확인한다. 하나라도 실패하면 종료 코드 1.
#  1) https://<host>/ 가 200이고 본문이 기대 문구(시스템 신뢰 저장소로 인증서 검증)
#  2) 인증서 발급자가 Let's Encrypt 운영 CA, SAN에 <host> 포함
#  3) http://<host>/ 가 https://<host>/ 로 리다이렉트
#  4) 외부에서 8080 연결 실패
# 필요 도구: curl, openssl. 주소는 deploy/oci/.state.env 의 TADAK_HOST, PUBLIC_IP.
# 선택 환경변수: TADAK_EXPECT_BODY(기본 "tadak vm ok"), TADAK_ALLOW_STAGING=1(스테이징 인증서 허용, 1번은 -k)
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$DIR/.state.env"
EXPECT="${TADAK_EXPECT_BODY:-tadak vm ok}"
ALLOW_STAGING="${TADAK_ALLOW_STAGING:-}"

for tool in curl openssl; do
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

# 1) HTTPS 응답
insecure=()
[[ "$ALLOW_STAGING" == "1" ]] && insecure=(-k)
body="$(curl -sS --max-time 15 ${insecure[@]+"${insecure[@]}"} -o - -w '\n%{http_code}' "https://$TADAK_HOST/" 2>&1)"
code="${body##*$'\n'}"
text="${body%$'\n'*}"
if [[ "$code" == "200" && "$text" == "$EXPECT" ]]; then
  pass "HTTPS 200, 본문 '$EXPECT'"
else
  fail "HTTPS 응답이 다릅니다(코드 $code, 본문 '$(head -c 120 <<<"$text")')"
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

if [[ $FAILED -eq 0 ]]; then
  echo "결과: 모두 통과"
else
  echo "결과: 실패 항목 있음" >&2
fi
exit "$FAILED"

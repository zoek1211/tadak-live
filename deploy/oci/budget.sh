#!/usr/bin/env bash
# 과금 감시: 테넌시 전체에 월 1 USD 예산과 "실제 사용액 0.01 USD 초과" 메일 알림을 만든다(있으면 재사용).
# Always Free 범위만 쓰면 사용액은 0이므로, 알림이 오면 무료 한도를 벗어난 자원이 생긴 것이다.
# 필요 도구: oci, jq. 인증: oci session authenticate --profile-name tadak
# 필수 환경변수: TADAK_BUDGET_EMAIL (알림 받을 주소, 저장소에 적지 않는다)
set -euo pipefail

# shellcheck source=SCRIPTDIR/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
BUDGET_NAME="tadak-budget"
RULE_NAME="tadak-any-charge"
AMOUNT=1
THRESHOLD=0.01

require_tools oci jq

EMAIL="${TADAK_BUDGET_EMAIL:-}"
if [[ -z "$EMAIL" ]]; then
  echo "TADAK_BUDGET_EMAIL 이 비어 있습니다. 예: TADAK_BUDGET_EMAIL=you@example.com $0" >&2
  exit 1
fi

# 예산은 홈 리전에서만 만들 수 있다(oci_init 이 OCI 명령을 홈 리전으로 고정)
oci_init

echo "==> 예산 '$BUDGET_NAME' 확인"
BUDGET_ID="$("${OCI[@]}" budgets budget budget list -c "$TENANCY" --all --lifecycle-state ACTIVE \
  | jq -r --arg n "$BUDGET_NAME" '[.data[]? | select(."display-name" == $n)][0].id // empty')"
if [[ -n "$BUDGET_ID" ]]; then
  echo "    이미 있어 재사용합니다."
else
  BUDGET_ID="$("${OCI[@]}" budgets budget budget create -c "$TENANCY" \
    --display-name "$BUDGET_NAME" --description "타닥 라이브: Always Free 밖 과금 감시" \
    --amount "$AMOUNT" --reset-period MONTHLY --processing-period-type MONTH \
    --target-type COMPARTMENT --targets "[\"$TENANCY\"]" --freeform-tags "$TAGS" \
    --wait-for-state ACTIVE | jq -r '.data.id')"
  echo "    만들었습니다(월 $AMOUNT USD, 대상: 테넌시 전체)."
fi

echo "==> 알림 규칙 '$RULE_NAME' 확인"
RULE_ID="$("${OCI[@]}" budgets budget alert-rule list --budget-id "$BUDGET_ID" --all \
  | jq -r --arg n "$RULE_NAME" '[.data[]? | select(."display-name" == $n)][0].id // empty')"
if [[ -n "$RULE_ID" ]]; then
  # 주소가 바뀌었을 수 있으니 받는 사람만 맞춘다
  "${OCI[@]}" budgets budget alert-rule update --budget-id "$BUDGET_ID" --alert-rule-id "$RULE_ID" \
    --recipients "$EMAIL" >/dev/null
  echo "    이미 있어 재사용합니다(받는 주소 갱신)."
else
  "${OCI[@]}" budgets budget alert-rule create --budget-id "$BUDGET_ID" \
    --display-name "$RULE_NAME" --type ACTUAL --threshold-type ABSOLUTE --threshold "$THRESHOLD" \
    --recipients "$EMAIL" --freeform-tags "$TAGS" \
    --message "타닥 라이브 OCI 계정에 실제 과금이 생겼습니다. Always Free 밖 자원이 있는지 확인하세요." >/dev/null
  echo "    만들었습니다(실제 사용액 $THRESHOLD USD 초과 시 메일)."
fi

echo "==> 결과"
"${OCI[@]}" budgets budget alert-rule list --budget-id "$BUDGET_ID" --all \
  | jq -r '.data[] | "    규칙 \(."display-name"): \(.type) \(."threshold-type") \(.threshold), 상태 \(."lifecycle-state")"'
echo "    예산 수: $("${OCI[@]}" budgets budget budget list -c "$TENANCY" --all --lifecycle-state ACTIVE \
  | jq --arg n "$BUDGET_NAME" '[.data[]? | select(."display-name" == $n)] | length')"

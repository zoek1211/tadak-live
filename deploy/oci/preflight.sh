#!/usr/bin/env bash
# 읽기 전용 점검: 홈 리전, 계정 등급, Always Free 남은 한도(A1·E2.1.Micro), 예약 공인 IP, Ubuntu 24.04 이미지.
# 아무 자원도 만들지 않는다. 필요 도구: oci, jq, curl. 인증: oci session authenticate --profile-name tadak
set -euo pipefail

# shellcheck source=SCRIPTDIR/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Always Free 한도(테넌시 전체). 계정 한도(PAYG면 훨씬 큼)와 다르니 사용량을 이 값에서 뺀다.
FREE_A1_OCPU=4
FREE_A1_MEM_GB=24
FREE_E2_MICRO=2
PRICE_API="https://apexapps.oracle.com/pls/apex/cetools/api/v1/products/?currencyCode=USD"

require_tools oci jq curl
oci_init

echo "==> 홈 리전: $HOME_REGION"
echo "==> 구독 리전: $(jq -r '[.data[]."region-name"] | join(", ")' <<<"$REGIONS_JSON")"

PLAN="$("${OCI[@]}" osp-gateway subscription-service subscription list --osp-home-region "$HOME_REGION" -c "$TENANCY" 2>/dev/null \
  | jq -r '[.data.items[]?."plan-type"] | unique | join(",")' || true)"
echo "==> 계정 등급: ${PLAN:-확인 실패}"
[[ "$PLAN" == *PAYG* ]] || echo "    경고: Pay As You Go가 아닙니다. 유휴 인스턴스 회수 대상이 될 수 있습니다(SPEC-vm-host.md 가정 8)."

ADS="$("${OCI[@]}" iam availability-domain list -c "$TENANCY" | jq -r '.data[].name')"
echo "==> 가용성 도메인: $(paste -sd ',' - <<<"$ADS")"

# 한도 사용량: AD 단위 한도를 모든 AD에 대해 더한다(구독 리전이 하나뿐이라는 전제는 위 출력으로 확인).
used_sum() {
  local limit="$1" total=0 ad used
  while IFS= read -r ad; do
    used="$("${OCI[@]}" limits resource-availability get -c "$TENANCY" --service-name compute \
      --limit-name "$limit" --availability-domain "$ad" | jq -r '.data."fractional-usage" // .data.used // 0')"
    total="$(jq -n "$total + $used")"
  done <<<"$ADS"
  echo "$total"
}

A1_CPU_USED="$(used_sum standard-a1-core-count)"
A1_MEM_USED="$(used_sum standard-a1-memory-count)"
E2_USED="$(used_sum vm-standard-e2-1-micro-count)"
A1_CPU_LEFT="$(jq -n "$FREE_A1_OCPU - $A1_CPU_USED")"
A1_MEM_LEFT="$(jq -n "$FREE_A1_MEM_GB - $A1_MEM_USED")"
E2_LEFT="$(jq -n "$FREE_E2_MICRO - $E2_USED")"
echo "==> A1 무료 남은 양: OCPU $A1_CPU_LEFT/$FREE_A1_OCPU, 메모리 ${A1_MEM_LEFT}GB/${FREE_A1_MEM_GB}GB"
echo "==> E2.1.Micro 무료 남은 수: $E2_LEFT/$FREE_E2_MICRO"

RIP="$("${OCI[@]}" limits resource-availability get -c "$TENANCY" --service-name vcn --limit-name reserved-public-ip-count \
  | jq -r '"\(.data.used // 0) 사용 / \(.data.available // 0) 남음"')"
echo "==> 예약 공인 IP 한도: $RIP"
# 공개 가격표에 공인 IP 품목이 있으면 유료로 본다. 없으면 과금 품목이 아니다.
if IP_ITEMS="$(curl -fsS --max-time 20 "$PRICE_API" | jq -r '[.items[] | select(.displayName | test("public ip|reserved ip|ipv4"; "i")) | .displayName] | join("; ")')"; then
  if [[ -z "$IP_ITEMS" ]]; then
    echo "==> 예약 공인 IP 가격: 공개 가격표에 공인 IP 품목 없음(과금 대상 아님)"
  else
    echo "==> 예약 공인 IP 가격: 가격표에 품목 있음 → $IP_ITEMS (임시 IP 사용 권장)"
  fi
else
  echo "==> 예약 공인 IP 가격: 가격표 조회 실패(임시 IP 사용 권장)"
fi

for pair in "VM.Standard.A1.Flex:aarch64" "VM.Standard.E2.1.Micro:x86_64"; do
  shape="${pair%%:*}" arch="${pair##*:}"
  img="$("${OCI[@]}" compute image list -c "$TENANCY" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
    --shape "$shape" --sort-by TIMECREATED --sort-order DESC --all 2>/dev/null | jq -r '.data[0]."display-name" // "없음"')"
  echo "==> Ubuntu 24.04 이미지($shape, $arch): $img"
done

EXISTING="$("${OCI[@]}" search resource structured-search \
  --query-text "query instance, vcn resources where lifecycleState != 'TERMINATED'" | jq -r '.data.items | length')"
echo "==> 기존 인스턴스·VCN 수: $EXISTING"

echo
if jq -ne "$A1_CPU_LEFT >= 2 and $A1_MEM_LEFT >= 12" >/dev/null; then
  echo "판단: VM.Standard.A1.Flex 2 OCPU·12GB 로 만들 수 있는 무료 한도가 있습니다(재고는 만들 때 확인)."
elif jq -ne "$E2_LEFT >= 1" >/dev/null; then
  echo "판단: A1 무료 한도가 부족합니다. VM.Standard.E2.1.Micro 로 만듭니다."
else
  echo "판단: 무료로 만들 수 있는 인스턴스 한도가 없습니다. 기존 인스턴스를 확인하세요." >&2
  exit 1
fi

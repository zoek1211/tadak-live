# shellcheck shell=bash
# deploy/oci/*.sh 공통: 도구 확인, 프로필·테넌시·홈 리전 읽기, 세션 확인.
# 사용: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"; require_tools oci jq; oci_init
# oci_init 이 정하는 값: PROFILE, TENANCY, HOME_REGION, REGIONS_JSON, OCI(배열, 홈 리전 고정)

PROFILE="${OCI_PROFILE:-tadak}"
OCI_CONFIG="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
# Homebrew oci-cli(Python 3.15)가 명령마다 내는 SyntaxWarning 을 숨긴다
export PYTHONWARNINGS="${PYTHONWARNINGS:-ignore::SyntaxWarning}"
# shellcheck disable=SC2034 # 이 파일을 source 하는 스크립트가 쓴다
TAGS='{"project":"tadak-live"}'

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || { echo "필요한 도구가 없습니다: $tool (brew install $tool)" >&2; exit 1; }
  done
}

session_hint() {
  echo "OCI 세션이 없거나 만료됐습니다. oci session refresh --profile $PROFILE 또는 oci session authenticate --profile-name $PROFILE 를 실행하세요." >&2
}

oci_init() {
  TENANCY="$(awk -v p="[$PROFILE]" '$0==p{f=1;next} /^\[/{f=0} f&&/^tenancy=/{sub(/^tenancy=/,"");print}' "$OCI_CONFIG" 2>/dev/null || true)"
  if [[ -z "$TENANCY" ]]; then
    echo "$OCI_CONFIG 에 프로필 [$PROFILE] 이 없습니다. oci session authenticate --profile-name $PROFILE 로 로그인하세요." >&2
    exit 1
  fi
  OCI=(oci --profile "$PROFILE" --auth security_token)
  # 세션 토큰은 1시간짜리라 실행 도중 끊기지 않게 시작할 때 연장해 둔다(만료된 뒤에는 연장이 안 되고 다시 로그인해야 함)
  if ! oci session refresh --profile "$PROFILE" >/dev/null 2>&1; then
    session_hint
    exit 1
  fi
  if ! REGIONS_JSON="$("${OCI[@]}" iam region-subscription list 2>/dev/null)"; then
    session_hint
    exit 1
  fi
  HOME_REGION="$(jq -r '.data[] | select(."is-home-region") | ."region-name"' <<<"$REGIONS_JSON")"
  OCI+=(--region "$HOME_REGION")
}

# 오래 걸리는 작업 중 세션(1시간)이 끝나 가면 연장한다. 연장이 안 되면 안내 후 종료(스크립트는 재실행 안전).
ensure_session() {
  if ! oci session validate --profile "$PROFILE" >/dev/null 2>&1; then
    oci session refresh --profile "$PROFILE" >/dev/null 2>&1 || { session_hint; exit 1; }
  fi
}

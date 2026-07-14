#!/usr/bin/env bash
# gen-ssh-key —— 按团队规则生成 SSH 密钥(Ed25519 默认 / RSA 4096 兜底;puttygen 优先,ssh-keygen 降级)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # 技能根目录(.env 所在)

die()  { echo "错误: $*" >&2; exit 1; }
warn() { echo "警告: $*" >&2; }

usage() {
  cat <<'EOF'
用法: gen-ssh-key.sh <name> [选项]

  <name>                  服务名/用途,作文件名前缀 + 默认备注
  --rsa                   用 RSA 4096(默认 Ed25519;永不产 RSA 2048)
  --comment "..."         覆盖 -C 备注(默认 = <name>)
  --passphrase-file <f>   从文件读口令加密私钥(默认无口令)
  --out-dir <dir>         输出目录(默认 .env 的 SSH_KEY_OUTPUT_DIR,再默认 ~/.ssh/generated-keys)
  --tool puttygen|ssh-keygen  强制工具(默认 auto)
  --force                 覆盖同名密钥(默认拒绝)
  --json                  机器可读输出(纯 JSON 走 stdout)
  --dry-run               仅打印计划,不生成
  -v, --verbose           打印诊断过程到 stderr(不污染 stdout)
  --                      结束选项解析(其后一律当作 <name>)
  -h, --help              帮助
EOF
}

KEY_TYPE="ed25519"; COMMENT=""; PASSPHRASE_FILE=""; OUT_DIR=""
TOOL="auto"; FORCE=0; JSON=0; DRY_RUN=0; VERBOSE=0; NAME=""

set_name() { if [ -z "$NAME" ]; then NAME="$1"; else die "多余参数: $1"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --rsa) KEY_TYPE="rsa"; shift ;;
    --comment) COMMENT="${2:-}"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --tool) TOOL="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --json) JSON=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -v|--verbose) VERBOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do set_name "$1"; shift; done ;;
    -*) usage >&2; die "未知选项: $1" ;;
    *) set_name "$1"; shift ;;
  esac
done

# 诊断信息只走 stderr,不污染 stdout(公钥 / JSON)
vlog() { [ "$VERBOSE" -eq 1 ] && echo "verbose: $*" >&2 || true; }

[ -n "$NAME" ] || { usage >&2; die "缺少必填参数 <name>"; }
case "$NAME" in */*|*' '*) die "name 不能含 / 或空格: $NAME" ;; esac
[ -n "$COMMENT" ] || COMMENT="$NAME"

# 加载技能根目录 .env(仅取 SSH_KEY_OUTPUT_DIR)
if [ -f "$SKILL_DIR/.env" ]; then
  # shellcheck disable=SC1091
  set -a; . "$SKILL_DIR/.env"; set +a
fi
# 输出目录优先级:--out-dir > .env 的 SSH_KEY_OUTPUT_DIR > 默认 ~/.ssh/generated-keys
# 两者都未提供时不落当前目录(否则易落到技能目录或用户仓库),而是集中到默认目录
if [ -z "$OUT_DIR" ]; then
  if [ -n "${SSH_KEY_OUTPUT_DIR:-}" ]; then
    OUT_DIR="$SSH_KEY_OUTPUT_DIR"
  else
    OUT_DIR="$HOME/.ssh/generated-keys"
    warn "未配置输出目录,使用默认 $OUT_DIR"
    echo "提示: 如需改默认,可在技能根目录执行 cp .env.example .env($SKILL_DIR),并设置 SSH_KEY_OUTPUT_DIR;或用 --out-dir . 显式落当前目录。" >&2
  fi
fi
OUT_DIR="${OUT_DIR/#\~/$HOME}"

PPK="$OUT_DIR/$NAME.ppk"
PEM="$OUT_DIR/$NAME.pem"
PUB="$OUT_DIR/$NAME.pub"

resolve_tool() {
  case "$TOOL" in
    puttygen)   command -v puttygen  >/dev/null 2>&1 || die "指定 puttygen 但未安装"; echo puttygen ;;
    ssh-keygen) command -v ssh-keygen >/dev/null 2>&1 || die "指定 ssh-keygen 但未安装"; echo ssh-keygen ;;
    auto)
      if   command -v puttygen  >/dev/null 2>&1; then echo puttygen
      elif command -v ssh-keygen >/dev/null 2>&1; then echo ssh-keygen
      else echo ""; fi ;;
    *) die "未知工具: $TOOL(可选 puttygen|ssh-keygen)" ;;
  esac
}
RESOLVED_TOOL="$(resolve_tool)"
if [ -z "$RESOLVED_TOOL" ]; then
  echo "错误: 未找到 puttygen 或 ssh-keygen。" >&2
  echo "安装: brew install putty  (或使用系统自带 ssh-keygen)" >&2
  exit 2
fi

vlog "工具=$RESOLVED_TOOL 类型=$KEY_TYPE 备注=$COMMENT"
vlog "输出目录=$OUT_DIR"
[ -f "$SKILL_DIR/.env" ] && vlog "已加载配置: $SKILL_DIR/.env" || true

if [ "$DRY_RUN" -eq 1 ]; then
  echo "tool=$RESOLVED_TOOL"
  echo "type=$KEY_TYPE"
  echo "comment=$COMMENT"
  echo "outdir=$OUT_DIR"
  echo "pem=$PEM"
  echo "pub=$PUB"
  [ "$RESOLVED_TOOL" = "puttygen" ] && echo "ppk=$PPK"
  exit 0
fi

prepare_outdir() {
  local pre=1
  [ -d "$OUT_DIR" ] || pre=0
  mkdir -p "$OUT_DIR"
  [ "$pre" -eq 0 ] && chmod 700 "$OUT_DIR" || true
}

guard_overwrite() {
  local targets=("$PEM" "$PUB")
  [ "$RESOLVED_TOOL" = "puttygen" ] && targets=("$PPK" "${targets[@]}")
  for f in "${targets[@]}"; do
    if [ -e "$f" ]; then
      [ "$FORCE" -eq 1 ] || die "目标已存在: $f(用 --force 覆盖)"
    fi
  done
  [ "$FORCE" -eq 1 ] && rm -f "${targets[@]}" || true
}

read_passphrase() { # 回显口令内容(可能为空)
  if [ -n "$PASSPHRASE_FILE" ]; then
    [ -f "$PASSPHRASE_FILE" ] || die "口令文件不存在: $PASSPHRASE_FILE"
    cat "$PASSPHRASE_FILE"
  fi
}

gen_sshkeygen() {
  local pass; pass="$(read_passphrase)"
  local args=(-t "$KEY_TYPE" -C "$COMMENT" -f "$PEM" -N "$pass" -q)
  [ "$KEY_TYPE" = "rsa" ] && args=(-t rsa -b 4096 -C "$COMMENT" -f "$PEM" -N "$pass" -q)
  vlog "执行: ssh-keygen ${args[*]}"
  ssh-keygen "${args[@]}"
  mv -f "$PEM.pub" "$PUB"
}

gen_puttygen() {
  local ppf="$PASSPHRASE_FILE" cleanup=""
  if [ -z "$ppf" ]; then
    ppf="$(mktemp)"; : > "$ppf"; cleanup="$ppf"   # 空口令文件 = 无口令,避免交互提示
  else
    [ -f "$ppf" ] || die "口令文件不存在: $PASSPHRASE_FILE"
  fi

  local genargs=(-t "$KEY_TYPE")
  [ "$KEY_TYPE" = "rsa" ] && genargs+=(-b 4096)
  genargs+=(-C "$COMMENT" -o "$PPK" --new-passphrase "$ppf")
  vlog "执行: puttygen ${genargs[*]}"
  puttygen "${genargs[@]}"

  # 从 ppk 导出 openssh 私钥:源用 ppf 解密,新私钥用 ppf 加密(空文件即不加密)
  puttygen "$PPK" -O private-openssh -o "$PEM" --old-passphrase "$ppf" --new-passphrase "$ppf"

  # 公钥部分未加密,-L 无需口令
  puttygen "$PPK" -L -o "$PUB"

  [ -n "$cleanup" ] && rm -f "$cleanup" || true
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | awk 'BEGIN{ORS=""} {if(NR>1)printf "\\n"; gsub(/\r/,"\\r"); gsub(/\t/,"\\t"); printf "%s",$0}'
}

emit_output() {
  chmod 600 "$PEM"
  [ "$RESOLVED_TOOL" = "puttygen" ] && chmod 600 "$PPK" || true
  local fpr pubkey protected="false"
  [ -n "$PASSPHRASE_FILE" ] && protected="true"
  fpr="$(ssh-keygen -lf "$PUB" 2>/dev/null || echo 'n/a')"
  pubkey="$(cat "$PUB")"

  if [ "$protected" = "false" ]; then
    warn "私钥未设口令。请妥善保管 $PEM(已 chmod 600),勿提交到仓库。"
  fi

  if [ "$JSON" -eq 1 ]; then
    local files="\"$(json_escape "$PEM")\",\"$(json_escape "$PUB")\""
    [ "$RESOLVED_TOOL" = "puttygen" ] && files="\"$(json_escape "$PPK")\",$files"
    printf '{"tool":"%s","type":"%s","passphrase_protected":%s,"files":[%s],"fingerprint":"%s","pubkey":"%s"}\n' \
      "$RESOLVED_TOOL" "$KEY_TYPE" "$protected" "$files" "$(json_escape "$fpr")" "$(json_escape "$pubkey")"
  else
    echo "已生成 $KEY_TYPE 密钥($RESOLVED_TOOL):"
    [ "$RESOLVED_TOOL" = "puttygen" ] && echo "  PPK : $PPK"
    echo "  私钥: $PEM (chmod 600)"
    echo "  公钥: $PUB"
    echo "  指纹: $fpr"
    echo ""
    echo "公钥:"
    echo "$pubkey"
    echo ""
    echo "提示: 后续用途(导入平台 / 追加 authorized_keys)由使用者决定。"
  fi
}

prepare_outdir
guard_overwrite
case "$RESOLVED_TOOL" in
  ssh-keygen) gen_sshkeygen ;;
  puttygen)   gen_puttygen ;;
esac
emit_output

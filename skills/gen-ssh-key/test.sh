#!/usr/bin/env bash
# gen-ssh-key skill 自测。所有产物写入临时目录,跑完清理。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/scripts/gen-ssh-key.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
assert_contains() { # <haystack> <needle> <msg>
  case "$1" in *"$2"*) ok "$3";; *) bad "$3 (期望包含: $2)";; esac; }
assert_file() { [ -f "$1" ] && ok "$2" || bad "$2 (文件不存在: $1)"; }
assert_no_file() { [ ! -e "$1" ] && ok "$2" || bad "$2 (文件不应存在: $1)"; }
assert_code() { # <actual> <expected> <msg>
  [ "$1" = "$2" ] && ok "$3" || bad "$3 (退出码 $1,期望 $2)"; }

echo "== CLI 骨架 =="

# 1. --version
out="$("$SCRIPT" --version)"; assert_contains "$out" "1.1.0" "--version 打印版本号"

# 2. --help
out="$("$SCRIPT" --help)"; assert_contains "$out" "用法" "--help 打印用法"

# 3. 缺 name 报错
set +e; "$SCRIPT" >/dev/null 2>"$TMP/err"; code=$?; set -e
assert_code "$code" "1" "缺 name 退出码 1"
assert_contains "$(cat "$TMP/err")" "缺少必填参数" "缺 name 提示"

# 4. dry-run 打印计划不生成文件
out="$("$SCRIPT" demo --out-dir "$TMP/d1" --dry-run)"
assert_contains "$out" "type=ed25519" "dry-run 显示默认 ed25519"
assert_contains "$out" "$TMP/d1/demo.pem" "dry-run 显示 pem 路径"
assert_no_file "$TMP/d1/demo.pem" "dry-run 不生成文件"

# 5. name 含 / 或空格应拒绝
set +e; "$SCRIPT" "a/b" >/dev/null 2>"$TMP/en1"; c1=$?; set -e
assert_code "$c1" "1" "name 含 / 退出码 1"
set +e; "$SCRIPT" "a b" >/dev/null 2>"$TMP/en2"; c2=$?; set -e
assert_code "$c2" "1" "name 含空格退出码 1"

# 6. 未知工具名报错
set +e; "$SCRIPT" demo --tool nope >/dev/null 2>"$TMP/et"; ct=$?; set -e
assert_code "$ct" "1" "未知 --tool 退出码 1"

# 7. -- 结束选项解析,其后当作 name
out="$("$SCRIPT" --tool ssh-keygen --out-dir "$TMP/dd" --dry-run -- demo)"
assert_contains "$out" "$TMP/dd/demo.pem" "-- 之后的 token 作 name"

# 8. --verbose 诊断走 stderr,不进 stdout
D_V="$TMP/dv"
outv="$("$SCRIPT" svc-v --tool ssh-keygen --out-dir "$D_V" -v 2>"$TMP/ev")"
assert_contains "$(cat "$TMP/ev")" "verbose:" "verbose 诊断打到 stderr"
assert_contains "$(cat "$TMP/ev")" "执行: ssh-keygen" "verbose 打印底层命令"
case "$outv" in *verbose:*) bad "verbose 不应出现在 stdout";; *) ok "stdout 不含 verbose 噪音";; esac

# 9. -v 与 --json 并用,stdout 仍是纯合法 JSON
outj="$("$SCRIPT" svc-vj --tool ssh-keygen --out-dir "$D_V" -v --json 2>/dev/null)"
if command -v python3 >/dev/null 2>&1; then
  set +e; printf '%s' "$outj" | python3 -c 'import sys,json;json.load(sys.stdin)' >/dev/null 2>&1; vjc=$?; set -e
  assert_code "$vjc" "0" "-v --json 时 stdout 仍是合法 JSON"
else
  ok "python3 未安装,跳过 -v --json 合法性校验"
fi

# 10. 输出目录未配置(无 --out-dir 且无 SSH_KEY_OUTPUT_DIR):提示落当前目录
#     用 dry-run 不落盘,并在 $TMP 内运行避免污染仓库目录
( cd "$TMP" && env -u SSH_KEY_OUTPUT_DIR "$SCRIPT" demo-noenv --dry-run ) >/dev/null 2>"$TMP/enoenv"
assert_contains "$(cat "$TMP/enoenv")" "未配置输出目录" "未配置输出目录时有 stderr 提示"

# 11. 传了 --out-dir 时不应出现该提示
( cd "$TMP" && env -u SSH_KEY_OUTPUT_DIR "$SCRIPT" demo-od --out-dir "$TMP/od" --dry-run ) >/dev/null 2>"$TMP/eod"
case "$(cat "$TMP/eod")" in *未配置输出目录*) bad "传了 --out-dir 不应提示未配置";; *) ok "传了 --out-dir 时不提示未配置";; esac

# 12. 设了 SSH_KEY_OUTPUT_DIR 时不应出现该提示
( cd "$TMP" && SSH_KEY_OUTPUT_DIR="$TMP/envdir" "$SCRIPT" demo-env --dry-run ) >/dev/null 2>"$TMP/eenv"
case "$(cat "$TMP/eenv")" in *未配置输出目录*) bad "设了 SSH_KEY_OUTPUT_DIR 不应提示未配置";; *) ok "设了 SSH_KEY_OUTPUT_DIR 时不提示未配置";; esac

# 13. 未配置提示走 stderr,不污染 stdout(dry-run 计划仍纯净)
outnc="$( ( cd "$TMP" && env -u SSH_KEY_OUTPUT_DIR "$SCRIPT" demo-clean --dry-run ) 2>/dev/null )"
case "$outnc" in *未配置输出目录*) bad "未配置提示不应进 stdout";; *) ok "未配置提示不污染 stdout";; esac

echo "== .env 从技能根目录读取 =="
# 复制一份技能目录(scripts/ + .env.example)到临时目录,避免污染仓库内真实 .env
SKILLCOPY="$TMP/skillcopy"
mkdir -p "$SKILLCOPY/scripts"
cp "$HERE/scripts/gen-ssh-key.sh" "$SKILLCOPY/scripts/gen-ssh-key.sh"
cp "$HERE/.env.example" "$SKILLCOPY/.env.example"
ENVDIR="$TMP/envcfg-outdir"
printf 'SSH_KEY_OUTPUT_DIR=%s\n' "$ENVDIR" > "$SKILLCOPY/.env"

out="$( env -u SSH_KEY_OUTPUT_DIR "$SKILLCOPY/scripts/gen-ssh-key.sh" demo-rootenv --dry-run )"
assert_contains "$out" "outdir=$ENVDIR" ".env 从技能根目录(scripts/ 上一级)被正确读取"

echo "== ssh-keygen 路径 =="
D2="$TMP/d2"

# ed25519 默认(强制 ssh-keygen)
out="$("$SCRIPT" svc-a --tool ssh-keygen --out-dir "$D2" 2>"$TMP/e2")"
assert_file "$D2/svc-a.pem" "ed25519 生成私钥 .pem"
assert_file "$D2/svc-a.pub" "ed25519 生成公钥 .pub"
assert_no_file "$D2/svc-a.ppk" "ssh-keygen 不产 .ppk"
perm="$(stat -f '%Lp' "$D2/svc-a.pem" 2>/dev/null || stat -c '%a' "$D2/svc-a.pem")"
assert_code "$perm" "600" "私钥权限 600"
assert_contains "$(ssh-keygen -lf "$D2/svc-a.pub")" "ED25519" "公钥指纹为 ED25519"
assert_contains "$(cat "$TMP/e2")" "警告:" "无口令时有警告"

# 覆盖守卫:同名再来一次应报错
set +e; "$SCRIPT" svc-a --tool ssh-keygen --out-dir "$D2" >/dev/null 2>"$TMP/e2b"; code=$?; set -e
assert_code "$code" "1" "同名已存在退出码 1"
assert_contains "$(cat "$TMP/e2b")" "已存在" "同名提示已存在"

# --force 覆盖成功
"$SCRIPT" svc-a --tool ssh-keygen --out-dir "$D2" --force >/dev/null 2>&1
ok "--force 覆盖不报错"

# --rsa 4096
"$SCRIPT" svc-r --tool ssh-keygen --out-dir "$D2" --rsa >/dev/null 2>&1
assert_contains "$(ssh-keygen -lf "$D2/svc-r.pub")" "RSA" "--rsa 公钥指纹为 RSA"
bits="$(ssh-keygen -lf "$D2/svc-r.pub" | awk '{print $1}')"
assert_code "$bits" "4096" "RSA 为 4096 位"

# --passphrase-file 加密私钥
echo "s3cret-pass" > "$TMP/pp"
"$SCRIPT" svc-p --tool ssh-keygen --out-dir "$D2" --passphrase-file "$TMP/pp" >/dev/null 2>&1
assert_contains "$(head -3 "$D2/svc-p.pem")" "OPENSSH" "加密私钥仍为 OpenSSH 格式"
set +e; ssh-keygen -y -P "" -f "$D2/svc-p.pem" >/dev/null 2>&1; nopass=$?; set -e
[ "$nopass" -ne 0 ] && ok "空口令无法读取(说明已加密)" || bad "私钥未被加密"
# 用正确口令(文件内容去尾换行)应能解开,证明口令即文件文本本身
set +e; ssh-keygen -y -P "s3cret-pass" -f "$D2/svc-p.pem" >/dev/null 2>&1; okpass=$?; set -e
assert_code "$okpass" "0" "ssh-keygen 路径:正确口令可解密"

# --json 输出
out="$("$SCRIPT" svc-j --tool ssh-keygen --out-dir "$D2" --json 2>/dev/null)"
assert_contains "$out" "\"type\":\"ed25519\"" "json 含 type"
assert_contains "$out" "\"passphrase_protected\":false" "json 含 passphrase_protected"
assert_contains "$out" "\"tool\":\"ssh-keygen\"" "json 含 tool"

# --json 输出含换行 comment 仍为合法 JSON
out="$("$SCRIPT" svc-nl --tool ssh-keygen --out-dir "$D2" --comment "$(printf 'x\ny')" --json 2>/dev/null)"
if command -v python3 >/dev/null 2>&1; then
  set +e; printf '%s' "$out" | python3 -c 'import sys,json;json.load(sys.stdin)' >/dev/null 2>&1; jcode=$?; set -e
  assert_code "$jcode" "0" "comment 含换行时 json 仍合法"
else
  ok "python3 未安装,跳过 json 合法性校验"
fi

echo "== puttygen 路径 =="
if command -v puttygen >/dev/null 2>&1; then
  D3="$TMP/d3"
  "$SCRIPT" svc-pg --tool puttygen --out-dir "$D3" >/dev/null 2>&1
  assert_file "$D3/svc-pg.ppk" "puttygen 产 .ppk"
  assert_file "$D3/svc-pg.pem" "puttygen 产 .pem"
  assert_file "$D3/svc-pg.pub" "puttygen 产 .pub"
  assert_contains "$(ssh-keygen -lf "$D3/svc-pg.pub")" "ED25519" "puttygen 公钥为 ED25519"
  perm="$(stat -f '%Lp' "$D3/svc-pg.pem" 2>/dev/null || stat -c '%a' "$D3/svc-pg.pem")"
  assert_code "$perm" "600" "puttygen 私钥权限 600"
  perm="$(stat -f '%Lp' "$D3/svc-pg.ppk" 2>/dev/null || stat -c '%a' "$D3/svc-pg.ppk")"
  assert_code "$perm" "600" "puttygen .ppk 权限 600"

  # auto 默认应选 puttygen
  out="$("$SCRIPT" svc-auto --out-dir "$D3" --dry-run)"
  assert_contains "$out" "tool=puttygen" "auto 默认选 puttygen"

  # --passphrase-file 加密私钥(puttygen 路径)
  echo "pg-pass" > "$TMP/ppg"
  "$SCRIPT" svc-pgp --tool puttygen --out-dir "$D3" --passphrase-file "$TMP/ppg" >/dev/null 2>&1
  set +e; ssh-keygen -y -P "" -f "$D3/svc-pgp.pem" >/dev/null 2>&1; enc=$?; set -e
  [ "$enc" -ne 0 ] && ok "puttygen --passphrase-file 私钥被加密" || bad "puttygen 私钥未加密"
  # 正确口令能解开 puttygen 导出的私钥(验证两条路径对口令文件的解读一致)
  set +e; ssh-keygen -y -P "pg-pass" -f "$D3/svc-pgp.pem" >/dev/null 2>&1; pgok=$?; set -e
  assert_code "$pgok" "0" "puttygen 路径:正确口令可解密"
else
  ok "puttygen 未安装,跳过 puttygen 路径(降级路径已由 ssh-keygen 路径覆盖)"
fi

echo ""; echo "结果: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]

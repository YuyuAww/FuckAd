#!/system/bin/sh

MODDIR=${0%/*}
TMPDIR="$MODDIR/tmp"
TMP_HOSTS="$TMPDIR/hosts"
OUT_HOSTS="$MODDIR/system/etc/hosts"

CURL="$MODDIR/bin/curl"
[ ! -x "$CURL" ] && CURL="curl"

mkdir -p "$TMPDIR"
mkdir -p "$(dirname "$OUT_HOSTS")"

: > "$TMP_HOSTS"

log() {
  echo "[FuckAd] $*"
}

syncdate=$(date "+%Y-%m-%d %H:%M")
log "开始同步 hosts..."

# 下载并合并订阅源
while read -r url || [ -n "$url" ]; do
  case "$url" in
    ""|\#*) continue ;;
  esac

  log "下载: $url"
  if ! $CURL -fsSL --connect-timeout 10 "$url" >> "$TMP_HOSTS"; then
    log "下载失败: $url"
  fi
done < "$MODDIR/source.ini"

# 域名获取与预处理
TMP_CLEAN="$TMPDIR/hosts.clean"
grep -E "^[0-9]|::1" "$TMP_HOSTS" \
  | grep -Ev 'localhost|#|!' \
  | sed 's/\t/ /g' \
  | awk 'NF' > "$TMP_CLEAN"

allhosts=$(wc -l < "$TMP_CLEAN")
log "源域名数: $allhosts"

# 白名单处理
log "应用白名单..."
while read -r whiteurl; do
  [ -z "$whiteurl" ] && continue
  case "$whiteurl" in \#*) continue ;; esac
  sed -i "/ $whiteurl\s*/d" "$TMP_CLEAN"
done < "$MODDIR/whitehosts.ini"

# 去重
log "去重域名..."
awk '!seen[$2]++' "$TMP_CLEAN" > "$TMPDIR/hosts.tmp"

# 黑名单处理
log "应用黑名单..."
while read -r blockurl; do
  [ -z "$blockurl" ] && continue
  case "$blockurl" in \#*) continue ;; esac
  echo "127.0.0.1  $blockurl" >> "$TMPDIR/hosts.tmp"
done < "$MODDIR/blackhosts.ini"

# 写入最终 hosts
cp "$TMPDIR/hosts.tmp" "$OUT_HOSTS"

log "最终 hosts 文件生成完成: $OUT_HOSTS"
log "总规则数: $(wc -l < "$OUT_HOSTS")"

# 更新 module.prop 描述
whitecount=$(grep -v '^[ \t]*#' "$MODDIR/whitehosts.ini" | awk 'NF>0' | wc -l)
blackcount=$(grep -v '^[ \t]*#' "$MODDIR/blackhosts.ini" | awk 'NF>0' | wc -l)
dupcount=$((allhosts - $(wc -l < "$TMPDIR/hosts.tmp")))

sed -i "s|^description=.*|description=[😋生效中] $(wc -l < "$OUT_HOSTS") 条规则有效; $dupcount 条规则去重; $whitecount 条白名单规则; $blackcount 条黑名单规则; 上次同步日期 $syncdate;|" \
  "$MODDIR/module.prop"

log "同步完成"

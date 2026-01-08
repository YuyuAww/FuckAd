#!/system/bin/sh

MODDIR=${0%/*}

TMPDIR="/tmp/fuckad"
TMP_HOSTS="$TMPDIR/hosts"
OUT_HOSTS="${MODDIR}/system/etc/hosts"

CURL="${MODDIR}/bin/curl"
WGET="${MODDIR}/bin/wget"

[ ! -x "$CURL" ] && CURL="curl"
[ ! -x "$WGET" ] && WGET="wget"

mkdir -p "$TMPDIR"
mkdir -p "$(dirname "$OUT_HOSTS")"

: > "$TMP_HOSTS"

log() {
  echo "[FuckAd] $*"
}

syncdate=$(date "+%Y-%m-%d %H:%M")

log "开始同步 hosts..."

# 1. 下载并合并订阅源

while read -r url; do
  case "$url" in
    ""|\#*) continue ;;
  esac

  log "下载: $url"

  if ! $CURL -fsSL --connect-timeout 10 "$url" >> "$TMP_HOSTS"; then
    log "curl 失败，尝试 wget"
    $WGET -qO- "$url" >> "$TMP_HOSTS" || log "下载失败: $url"
  fi
done < "$MODDIR/source.ini"

#提取域名

grep -Ev '^[ \t]*#|^[ \t]*$' "$TMP_HOSTS" \
  | sed 's/\r//' \
  | awk '{print $NF}' \
  | grep -E '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}' \
  > "$TMPDIR/all_domains"

allhosts=$(wc -l < "$TMPDIR/all_domains")

#处理白名单

grep -v '^[ \t]*[#]' "$MODDIR/whitehosts.ini" | awk 'NF>0' \
  > "$TMPDIR/white.list"

grep -v -F -f "$TMPDIR/white.list" \
  "$TMPDIR/all_domains" > "$TMPDIR/after_white"


#处理黑名单

grep -v '^[ \t]*[#]' "$MODDIR/blackhosts.ini" | awk 'NF>0' \
  > "$TMPDIR/black.list"

cat "$TMPDIR/after_white" "$TMPDIR/black.list" \
  > "$TMPDIR/after_black"

#排序去重

sort -u "$TMPDIR/after_black" > "$TMPDIR/final_domains"

sorthosts=$(wc -l < "$TMPDIR/final_domains")

#（Magisk 挂载到 /system/etc/hosts）

{
  echo "127.0.0.1 localhost"
  echo "::1 localhost"
  echo ""
  while read -r domain; do
    echo "0.0.0.0 $domain"
  done < "$TMPDIR/final_domains"
} > "$OUT_HOSTS"

#更新 module.prop 描述

whitecount=$(wc -l < "$TMPDIR/white.list")
blackcount=$(wc -l < "$TMPDIR/black.list")
dupcount=$((allhosts - sorthosts))

sed -i "s|^description=.*|description=[😋生效中] $sorthosts 条规则有效; $dupcount 条规则去重; $whitecount 条白名单规则; $blackcount 条黑名单规则; 上次同步日期 $syncdate;|" \
  "$MODDIR/module.prop"

log "同步完成：$sorthosts 条规则已生效"

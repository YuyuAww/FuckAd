#!/system/bin/sh

MODDIR=${0%/*}
// 最大并行下载任务数(3-6 之间)
MAX_JOBS=4

# GitHub raw 加速
source=$(grep -v '#' ${MODDIR}/source.ini | sed 's/raw.githubusercontent.com/raw.gitmirror.com/g')
syncdate=$(date '+%Y-%m-%d %H:%M:%S')

chmod 755 $MODDIR/bin/wget
chmod 755 $MODDIR/bin/curl

mkdir -p ${MODDIR}/tmp
mkdir -p ${MODDIR}/system/etc

rm -f ${MODDIR}/tmp/*

# 并行下载（安全写文件）

synchosts() {
	jobcount=0

	for sourceurl in $source; do
	(
		hash=$(printf "%s" "$sourceurl" | sed 's#[^a-zA-Z0-9]#_#g')
		part="${MODDIR}/tmp/hosts_${hash}.part"
		tmp="${MODDIR}/tmp/${hash}.tmp"
		: > "$tmp"

		echo "同步中: $sourceurl"

		$MODDIR/bin/wget -q --no-check-certificate -t 1 -T 10 \
			-O "$tmp" "$sourceurl"

		if [ $? -ne 0 ] || [ ! -s "$tmp" ]; then
			$MODDIR/bin/curl -L -k --retry 2 --connect-timeout 10 \
				-A "Mozilla/5.0" "$sourceurl" -o "$tmp"
		fi

		# 去 BOM
		sed -i '1s/^\xEF\xBB\xBF//' "$tmp"

		if [ -s "$tmp" ]; then
			cat "$tmp" >> "$part"
		else
			echo "失败: $sourceurl"
		fi

		rm -f "$tmp"
	) &

	jobcount=$((jobcount + 1))
	[ "$jobcount" -ge "$MAX_JOBS" ] && wait && jobcount=0
	done

	wait
}

# 执行同步（最多 3 次）

retry=1
while [ $retry -le 3 ]; do
	synchosts
	ls ${MODDIR}/tmp/hosts_*.part >/dev/null 2>&1 && break
	retry=$((retry + 1))
done

cat ${MODDIR}/tmp/hosts_*.part > ${MODDIR}/tmp/hosts.raw 2>/dev/null

# 标准化 hosts（拆分多域名）

awk '
/^[[:space:]]*#/ {next}
NF < 2 {next}
{
	ip=$1
	for (i=2;i<=NF;i++) {
		if ($i !~ /^#/) print ip, $i
	}
}
' ${MODDIR}/tmp/hosts.raw > ${MODDIR}/tmp/hosts.norm

allhosts=$(wc -l < ${MODDIR}/tmp/hosts.norm)

# 白名单（支持通配）

if [ -s "${MODDIR}/whitehosts.ini" ]; then
	awk '
	BEGIN {
	  while ((getline < "'"${MODDIR}/whitehosts.ini"'") > 0) {
	    if ($0 !~ /^[[:space:]]*#/ && NF) {
	      gsub(/\./,"\\.",$0)
	      gsub(/\*/,".*",$0)
	      wl[++n]="^" $0 "$"
	    }
	  }
	}
	{
	  for (i=1;i<=n;i++) {
	    if ($2 ~ wl[i]) next
	  }
	  print
	}
	' ${MODDIR}/tmp/hosts.norm > ${MODDIR}/tmp/hosts.white
else
	cp ${MODDIR}/tmp/hosts.norm ${MODDIR}/tmp/hosts.white
fi

# 去重（按域名）

awk '!seen[$2]++' ${MODDIR}/tmp/hosts.white > ${MODDIR}/tmp/hosts.uniq

# 黑名单（强制追加）

cp ${MODDIR}/tmp/hosts.uniq ${MODDIR}/tmp/hosts.final

if [ -s "${MODDIR}/blackhosts.ini" ]; then
	grep -v '^[[:space:]]*#' ${MODDIR}/blackhosts.ini | awk 'NF' \
	| awk '{print "127.0.0.1", $1}' \
	| awk '!seen[$2]++' >> ${MODDIR}/tmp/hosts.final
fi

sorthosts=$(wc -l < ${MODDIR}/tmp/hosts.final)


# 写入 hosts + bind mount

{
	echo "127.0.0.1 localhost"
	echo "::1 localhost"
	echo ""
	cat ${MODDIR}/tmp/hosts.final
} > ${MODDIR}/system/etc/hosts

umount /system/etc/hosts 2>/dev/null
mount --bind ${MODDIR}/system/etc/hosts /system/etc/hosts
chcon u:object_r:system_file:s0 ${MODDIR}/system/etc/hosts 2>/dev/null

# module.prop 描述更新

sed -i "s|description=.*|description=[😋生效中] $sorthosts 条规则有效; $((allhosts - sorthosts)) 条去重; $(grep -v '^[[:space:]]*#' whitehosts.ini 2>/dev/null | awk 'NF' | wc -l) 白名单; $(grep -v '^[[:space:]]*#' blackhosts.ini 2>/dev/null | awk 'NF' | wc -l) 黑名单; 上次同步 $syncdate;|" \
${MODDIR}/module.prop

echo "$sorthosts 条规则已生效"
sleep 2

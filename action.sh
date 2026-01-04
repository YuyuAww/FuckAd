#!/system/bin/sh

MODDIR=${0%/*}

# 并行下载最大任务数（建议 3~5）
MAX_JOBS=4

# 订阅源（GitHub 加速）
source=$(grep -v '#' ${MODDIR}/source.ini | sed 's/raw.githubusercontent.com/raw.gitmirror.com/g')

syncdate=$(date '+%Y-%m-%d %H:%M:%S')

# 确保工具可执行
chmod 755 $MODDIR/bin/wget
chmod 755 $MODDIR/bin/curl

# 目录准备
[ ! -d "${MODDIR}/tmp" ] && mkdir ${MODDIR}/tmp
[ ! -d "${MODDIR}/system/etc" ] && mkdir -p ${MODDIR}/system/etc

# 清空临时 hosts
: > ${MODDIR}/tmp/hosts.tmp

# 并行同步函数（wget → curl 兜底）

synchosts() {
	jobcount=0

	for sourceurl in $source
	do
	(
		hash=$(echo "$sourceurl" | md5sum | awk '{print $1}')
		tmpfile="${MODDIR}/tmp/${hash}.tmp"
		: > "$tmpfile"

		echo "同步中: $sourceurl"

		# wget 优先
		$MODDIR/bin/wget -q --no-check-certificate -t 1 -T 10 \
		-O "$tmpfile" "$sourceurl"

		# wget 失败或空文件 → curl
		if [ $? -ne 0 ] || [ ! -s "$tmpfile" ]; then
			echo "wget 失败，切换 curl: $sourceurl"
			$MODDIR/bin/curl -L -k --connect-timeout 10 \
			-A "Mozilla/5.0" \
			"$sourceurl" -o "$tmpfile"
		fi

		# 成功才合并
		if [ -s "$tmpfile" ]; then
			cat "$tmpfile" >> ${MODDIR}/tmp/hosts.tmp
		else
			echo "同步失败: $sourceurl"
		fi

		rm -f "$tmpfile"
	) &

		jobcount=$((jobcount + 1))

		# 并发控制
		if [ "$jobcount" -ge "$MAX_JOBS" ]; then
			wait
			jobcount=0
		fi
	done

	wait
}

# 执行同步（失败自动重试）

if [ "$(echo "$source" | wc -l)" != "0" ]; then
	retry=1
	while [ $retry -le 3 ]; do
		synchosts
		[ -s "${MODDIR}/tmp/hosts.tmp" ] && break
		retry=$((retry + 1))
	done
fi

# 后续处理（过滤、去重、黑白名单等）
cat ${MODDIR}/tmp/hosts.tmp | grep -E -v 'localhost|#|!' | grep -E "^[0-9]|::1" | sed 's/\t/ /g' | grep -v '^$' | awk 'NF' > ${MODDIR}/tmp/hosts

allhosts=$(wc -l ${MODDIR}/tmp/hosts | awk '{print $1}')

for whiteurl in $(grep -v '^[ \t]*[#]' whitehosts.ini | awk 'NF > 0')
do
	sed -i "/ $whiteurl\s*/d" ${MODDIR}/tmp/hosts
done

awk '!seen[$2]++' ${MODDIR}/tmp/hosts > ${MODDIR}/tmp/hosts.tmp

for blockurl in $(grep -v '^[ \t]*[#]' blackhosts.ini | awk 'NF > 0')
do
	echo "127.0.0.1  $blockurl" >> ${MODDIR}/tmp/hosts.tmp
done

sorthosts=$(wc -l ${MODDIR}/tmp/hosts.tmp | awk '{print $1}')

if [ -s "${MODDIR}/tmp/hosts.tmp" ]; then
   umount /system/etc/hosts
   mv -f ${MODDIR}/tmp/hosts.tmp ${MODDIR}/system/etc/hosts
   sed -i "s/description=.*/description=[😋生效中] $sorthosts 条规则有效; $((allhosts - sorthosts)) 条规则去重; $(grep -v '^[ \t]*[#]' whitehosts.ini | awk 'NF > 0' | wc -l) 条白名单规则; $(grep -v '^[ \t]*[#]' blackhosts.ini | awk 'NF > 0' | wc -l) 条黑名单规则; 上次同步日期 $syncdate;/" ${MODDIR}/module.prop
   echo "$sorthosts 条规则有效;"
   echo "$((allhosts - sorthosts)) 条规则去重;"
   echo "$(grep -v '^[ \t]*[#]' whitehosts.ini | awk 'NF > 0' | wc -l) 条白名单规则;"
   echo "$(grep -v '^[ \t]*[#]' blackhosts.ini | awk 'NF > 0' | wc -l) 条黑名单规则;"
   echo -e '127.0.0.1  localhost\n::1  localhost' >> ${MODDIR}/system/etc/hosts
   mount --bind ${MODDIR}/system/etc/hosts /system/etc/hosts
else
	echo "此次同步不包含任何可用规则"
fi
sleep 2
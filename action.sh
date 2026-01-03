#!/system/bin/sh
MODDIR=${0%/*}
source=$(cat ${MODDIR}/source.ini | grep -v '#' | sed 's/raw.githubusercontent.com/raw.gitmirror.com/g')
#syncdate=$(date '+%Y-%m-%d')
syncdate=$(date '+%Y-%m-%d %H:%M:%S')
chmod 755 $MODDIR/bin/wget  # 确保 wget 可执行

if [ ! -d "${MODDIR}/tmp" ]; then
	mkdir ${MODDIR}/tmp
fi
if [ ! -d "${MODDIR}/system/etc" ]; then
	mkdir -p ${MODDIR}/system/etc
fi

echo -n '' > ${MODDIR}/tmp/hosts.tmp

synchosts() {
for sourceurl in $source
do
	echo "正在同步 $sourceurl"
	$MODDIR/bin/wget --header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
     -q --no-check-certificate -t 1 -T 10 -O - "$sourceurl" >> ${MODDIR}/tmp/hosts.tmp
done
}

if [ "$(echo $source | wc -l)" != "0" ]; then
	synccount=1
	while [ $synccount -lt 5 ]; do
		if [ -s "${MODDIR}/tmp/hosts.tmp" ]; then
			break
		else
			synchosts
			let synccount++
		fi
	done
fi

# 后续处理（过滤、去重、黑白名单等）保持不变
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
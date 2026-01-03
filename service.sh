#!/system/bin/sh
MODDIR=${0%/*}
busyboxfile=$(find /data/adb -maxdepth 3 -name busybox | head -n 1)

if [ -f "$MODDIR/module.prop.bak" ]; then
    mv -f $MODDIR/module.prop.bak $MODDIR/module.prop
fi

while true; do
  if [ -d "/storage/emulated/0/Android/data" ] && [ "$(getprop sys.boot_completed)" == "1" ]; then
    break
  fi
  sleep 3
done

sleep 10

if [ -f "$MODDIR/syncflag" ]; then
	sh $MODDIR/action.sh
	rm $MODDIR/syncflag
fi

if [ ! -d "$MODDIR/crond" ]; then
	mkdir -p $MODDIR/crond
fi

chmod -R 755 $MODDIR/*

echo "30 12 * * 0 $MODDIR/action.sh" > $MODDIR/crond/root

$busyboxfile crond -c $MODDIR/crond/

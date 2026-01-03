SKIPUNZIP=0

touch $MODPATH/syncflag

#cat $MODPATH/Readme.md
echo '模块具体配置查看readme.md'

set_perm_recursive $MODPATH 0 0 0755 0644
 
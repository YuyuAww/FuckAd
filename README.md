**hosts规则并不是越多越好，规则太多会影响冲浪速度**

- action.sh  hosts同步主程序脚本，可手动运行

- bin/wget  arm64位wget主程序，用于从订阅源拉取规则

- bin/curl  arm64位curl主程序，用于从订阅源拉取规则
- wget  wget下载失败时切换curl下载

- source.ini  hosts订阅源地址，一行一个，#开头为注释行

- whitehosts.ini  白名单域名，放行订阅源中有影响你使用的域名，一行一个，#开头为注释行
- blackhosts.ini  黑名单域名，添加你已知、且订阅源中不存在的广告域名，一行一个 ，#开头为注释行

- service.sh  使用crond命令创建定时任务, 默认每周日下午12时30分自动同步

- Readme.md  模块使用说明文档
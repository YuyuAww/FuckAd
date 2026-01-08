**注意**
- 规则并不是越多越好，规则太多会影响冲浪速度，请根据自身需求，合理选择订阅源

- action.sh  hosts同步主程序脚本，可手动运行

- source.ini  hosts订阅源地址，一行一个，#开头为注释行

- whitehosts.ini  白名单域名，放行订阅源中有影响你使用的域名，一行一个，#开头为注释行

- blackhosts.ini  黑名单域名，添加你已知、且订阅源中不存在的广告域名，一行一个 ，#开头为注释行

- service.sh  使用crond命令创建定时任务, 默认每周日下午12时30分自动同步

**致谢**
- 酷安网友 [@老时光_0](https://www.coolapk.com/u/2253372) - 提供了思路
- [AWAvenue 秋风广告规则](https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/Filters/AWAvenue-Ads-Rule-hosts.txt) - 提供了优秀的广告过滤规则
- [@coolapk 1007](https://raw.githubusercontent.com/lingeringsound/10007_auto/master/all) - 提供了大量广告过滤规则
- [AdHosts](https://raw.githubusercontent.com/samyansan/AdHosts/master/hosts) - 提供了全球最全面的 hosts 文件
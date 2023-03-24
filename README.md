# hpcpilot

#### 介绍
A collection of HPC delivery tools, including basic system configuration, node inspection, performance testing, third-party service installation, etc.

#### 软件架构
shell


#### 安装教程

1.	从网址 https://gitee.com/openeuler/hpcpilot下载压缩包, 解压至{SHARE_PATH}/software/tools/目录下:
注：SHARE_PATH为实际共享目录	
[root@arm47 hpc_script]# pwd
/share/software/tools/hpc_script
[root@arm47 hpc_script]# ll
total 56K
-rwxrwxr-x 1 root root  12K Mar 16 15:01 auto_install_tools.sh
drwxr-xr-x 2 root root 4.0K Mar 16 14:47 basic_script
drwxr-xr-x 2 root root 4.0K Mar 20 09:28 benchmark_script
-rw-r--r-- 1 root root  18K Mar 16 15:01 common.sh
-rw-r--r-- 1 root root  141 Mar 15 09:09 hostname.csv
drwxr-xr-x 2 root root 4.0K Mar 20 09:53 service_script
-rw-r--r-- 1 root root 2.1K Mar 17 17:49 setting.ini
-rw-r--r-- 1 root root 2.1K Mar 15 09:20 users.json
2.	将附件中的脚本上传到对应的目录中，目录结构如下:
[root@arm226 hpc_script]# tree -A -C
.
├── auto_install_tools.sh
├── basic_script
│   ├── auto_check_script.sh
│   ├── auto_init_script.sh
│   ├── auto_install_script.sh
│   ├── cac_directory.sh
│   ├── cac_firewall.sh
│   ├── cac_hostname.sh
│   ├── cac_ibtoroce.sh
│   ├── cac_pass_free.sh
│   ├── cac_selinux.sh
│   ├── cac_ulimit.sh
│   ├── cac_users.sh
│   ├── cas_ansible.sh
│   ├── cas_cuda.sh
│   ├── cas_mellanox.sh
│   ├── cas_nfs.sh
│   └── cas_yum.sh
├── benchmark_script
│   ├── compile_bisheng_hmpi_kml.sh
│   ├── compile_hpl.sh
│   ├── compile_osu.sh
│   └── compile_stream.sh
├── common.sh
├── hostname.csv
├── service_script
│   ├── install_ldap_client.sh
│   ├── install_ldap_cli_TLS.yml
│   ├── install_ldap_server.sh
│   ├── install_ntp_client.sh
│   ├── install_ntp_client.yml
│   ├── install_ntp_server.sh
│   └── install_ntp_server.yml
├── setting.ini
└── users.json


#### 使用说明

1.  xxxx
2.  xxxx
3.  xxxx

#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request


#### 特技

1.  使用 Readme\_XXX.md 来支持不同的语言，例如 Readme\_en.md, Readme\_zh.md
2.  Gitee 官方博客 [blog.gitee.com](https://blog.gitee.com)
3.  你可以 [https://gitee.com/explore](https://gitee.com/explore) 这个地址来了解 Gitee 上的优秀开源项目
4.  [GVP](https://gitee.com/gvp) 全称是 Gitee 最有价值开源项目，是综合评定出的优秀开源项目
5.  Gitee 官方提供的使用手册 [https://gitee.com/help](https://gitee.com/help)
6.  Gitee 封面人物是一档用来展示 Gitee 会员风采的栏目 [https://gitee.com/gitee-stars/](https://gitee.com/gitee-stars/)

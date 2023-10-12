**HPC安装配置辅助工具**

**安装配置操作手册**

# 工具介绍

HPC安装配置辅助工具（HPCPILOT）主要包括批量安装配置OS、挂载存储客户端、批量安装服务、多瑙安装前配置以及benchmark工具安装编译。

OS安装配置包括：YUM源挂载、节点名称hostname配置、免密配置、关闭SELINUX、关闭防火墙、配置/etc/hosts、Mellanox网卡驱动安装配置以及ULIMIT配置。

挂在存储客户端：目前仅支持挂载NFS客户端。

批量安装服务：目前支持的服务主要有时间同步服务Chrony和目录访问协议服务LDAP。

多瑙前安装配置：工具执行节点创建多瑙规划目录和创建本地多瑙用户。

benchmark工具安装编译：毕昇、HPL、OSU、STREAM。

# 使用范围

目前该工具支持适配的操作系统版本主要有：

-   CentOS_7.6_ARM64
-   CentOS_8.2_ARM64
-   Kylin-Server-10-SP2-aarch64-RC01-Build09-20210524
-   openEuler-20.03-LTS-SP3-everything-aarch64

    **注意：如使用其它未支持适配的操作系统版本安装过程可能存在不可预知的问题。**

# 安装教程

## 安装前准备

1.  获取软件工具包。

工具包下载路径：<https://gitee.com/openeuler/hpcpilot>

1.  获取安装依赖包

    麒麟操作系统：https://onebox.huawei.com/p/01eb4ecb1ac64ce926b5879337650ac0

    CentOS操作系统：https://onebox.huawei.com/p/9d6293cab0ce1aad20e38fc751c19b39

    欧拉操作：<https://onebox.huawei.com/p/38838c4d11af2034211080511ed8b7e4>

| 软件包名                                                  | 备注                                                      |
|-----------------------------------------------------------|-----------------------------------------------------------|
| **ansible**                                               | **ansible**                                               |
| **BiSheng-compiler-2.5.0-aarch64-linux.tar.gz**           | **毕昇编译器** **地址供参考，官网版本持续更新中。**       |
| **BoostKit-kml_1.7.0_bisheng.zip**                        | **Kml工具**                                               |
| **cuda_11.4.1_470.57.02_linux_sbsa.run**                  | **Cuda驱动** **官网下载，文件名可能有更新，地址供参考。** |
| **hpl-2.3.tar.gz**                                        | Benchmark测试程序                                         |
| **Hyper-MPI_1.2.1_Sources.tar.gz**                        | **Hmpi**                                                  |
| **jq**                                                    | **Jp**                                                    |
| **Kylin-Server-10-SP2-aarch64-RC01-Build09-20210524.iso** | **镜像文件**                                              |
| **libatomic-7.3.0-2020033101.49.oe1.aarch64 (5).rpm**     | **Benchmark测试依赖**                                     |
| **migrationtools-47-15.el7.noarch.rpm**                   | **LDAP依赖**                                              |
| **MLNX_OFED_LINUX-5.4-3.6.8.1-kylin10sp2-aarch64.tgz**    | **网卡驱动**                                              |
| **osu-micro-benchmarks-5.9.tar.gz**                       | Benchmark测试程序                                         |
| **stream.c**                                              | Benchmark测试程序                                         |
| **tcsh-6.22.02-3.ky10.aarch64.rpm**                       | **网卡驱动依赖**                                          |

1.  规划运维节点

该节点主要用来执行HPC安装配置辅助工具，通过该工具操作其它节点。

## 安装HPCPILOT

1.  在规划的运维节点创建临时目录（**注意：临时目录不可随意更改**）。

手动创建脚本存放目录

mkdir -p /opt/hpcpilot/hpc_script/

手动创建安装依赖包存放目录

mkdir -p /opt/hpcpilot/sourcecode/

1.  上传工具包到手动创建脚本存放目录，
2.  将工具包脚本上传到任意目录（以/tmp目录为例）

    cd /tmp/

    unzip /tmp/ hpcpilot-master.zip

    cd /tmp/hpcpilot-master

    mv hpc_script/\* /opt/hpcpilot/hpc_script/

    最终结构如下图：

    ![](media/5564d101edcf268efd577776d951b6a8.png)

1.  上传安装依赖包到安装依赖包存放目录/opt/hpcpilot/sourcecode/，最终结构如下图：

    ![](media/32d95b6687b767eb4dfa17c72a25972f.png)

## HPCPILOT配置

-   切换到工具脚本临时存放目录

    cd /opt/hpcpilot/hpc_script/

-   配置/opt/hpcpilot/hpc_script/users.json文件

    该文件主要存放多瑙用户信息，用来自动创建多瑙用户。根据现场实际情况修改所有用户id值。默认无需修改。

-   配置/opt/hpcpilot/hpc_script/hostname.csv文件
1.  hostname.csv文件介绍

| 字段名称        | 字段说明                                                                                                                                                                                                                                                                                                                                                            | 备注                                      | 配置示例                      |
|-----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|-------------------------------|
| host_ip         | 节点IP地址                                                                                                                                                                                                                                                                                                                                                          |                                           | 168.17.1.76                   |
| host_name       | 节点hostname                                                                                                                                                                                                                                                                                                                                                        | 用来修改节点hostname                      | master01                      |
| host_group      | 节点分组名称，主要用于批量工具ANSIBLE批量操作时使用。目前涉及到的分组主要用如下： 【ccsccp】 该节点既有scheduler又有portal 【agent】 该节点是多瑙agent节点 【scheduler】 该节点是多瑙scheduler节点 【portal】 该节点是多瑙portal节点 【cli】 该节点是多瑙CLI节点 【ntp_client】 该节点是NTP客户端节点 【ldap_client】该节点是LDAP客户端节点 多个分组实验&符号链接。 | 主要用来生成/etc/ansible/host和/etc/hosts | ccsccp&ntp_server&ldap_client |
| host_expansion  | 扩容节点标识（0=非扩容 1= 扩容）                                                                                                                                                                                                                                                                                                                                    |                                           | 0                             |
| host_compute_ip | 计算节点IP地址，配置网卡使用                                                                                                                                                                                                                                                                                                                                        | 不配置网卡则不填                          |                               |
| host_storage_ip | 存储IP地址，配置网卡使用                                                                                                                                                                                                                                                                                                                                            | 不配置网卡则不填                          |                               |

1.  根据业务规划梳理所有节点分组并填写编辑至hostname.csv文件，字段之间使用逗号分割。
-   配置/opt/hpcpilot/hpc_script/setting.ini文件
1.  setting.ini配置文件属性介绍

| 属性名称                      | 属性描述                                                                     | 配置示例        |
|-------------------------------|------------------------------------------------------------------------------|-----------------|
| common_sys_user_password      | 设置users.json中业务系统用户初始密码                                         | /               |
| common_sys_root_password      | 操作系统root用户密码                                                         | /               |
| basic_om_master_ip            | hpcpilot自动化工具执行节点IP地址                                             | 9.88.40.49      |
| basic_shared_directory        | 共享存储客户端共享目录名称                                                   | /share          |
| basic_share_storage_ip        | 共享存储服务端节点IP地址                                                     | 9.88.40.49      |
| basic_share_storage_directory | 共享存储服务端节点共享目录                                                   | /share_nfs      |
| basic_network_type            | 配置使用所需网络标识（1=IB网络 2=RoCE网络 3=TCP以太网络）,如未填写默认值为3  | 3               |
| basic_vlan_vid                | 配置使用网络VLAN的标识VID，如未填写默认值为701(选填)                         | /               |
| basic_ansible_forks           | 运维工具ansible并发数设置（如果不填或者为空默认值为5）(选填)                 | 6               |
| basic_yum_install_path        | yum镜像安装挂载路径                                                          | /mnt            |
| ntp_server_ip                 | NTP/Chrony服务端IP地址                                                       | 9.88.49.40      |
| ntp_allow_ip                  | 在centOS8.2操作系统上部署ntp服务端时必须设置，例：9.88.0.0/16                | 9.88.0.0/16     |
| ldap_login_password           | ldap管理员密码                                                               | /               |
| master_ldap_server_ip         | ldap服务非HA部署场景下ldap服务端IP，或HA场景下ldap服务端主节点IP             | 9.88.49.40      |
| slave_ldap_server_ip          | ldap服务HA部署场景下ldap服务端备节点IP（选填）                               | /               |
| ldap_domain_name              | 设置ldap服务访问域名名称,如果为空或者不填默认值为：ldap01.huawei.com（选填） | ldap.huawei.com |
| virtual_ldap_server_ip        | ldap服务HA部署场景下ldap服务端虚拟IP（选填）                                 | 9.88.49.45      |

1.  根据客户资料规划节点，包括运维节点IP、LDAP主备节点IP LDAP 虚拟IP、NTP服务端节点IP并编辑填写至setting.ini文件

    注意：

    1、需要提前配置nfs的service的

## 赋予可执行权限

HPCPILOT配置完成无误后，切换至/opt/hpcpilot/hpc_script/目录赋予/opt/hpcpilot/hpc_script/目录及子目录所有\*.sh可执行权限。命令如下：

cd /opt/hpcpilot/hpc_script/

chmod 775 \*.sh

cd /opt/hpcpilot/hpc_script/basic_script

chmod 775 \*.sh

cd ../benchmark_script

chmod 775 \*.sh

cd ../service_script

chmod 775 \*.sh

## 使用指南

步骤一：执行以下命令切换至脚本入口目录

cd /opt/hpcpilot/hpc_script

步骤二：执行以下命令运行脚本工具，进入主菜单

**./auto_install_tools.sh**

**菜单目录及功能如下**

| 菜单名称                                                           | 功能                                                                                                        |
|--------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| 1)auto run initialization script                                   | 一键初始化运维节点，安装YUM源和ANSIBLE                                                                      |
| 2) auto run operating system configuration script.                 | 批量操作OS安装配置自动化脚本                                                                                |
| 3) auto run mount storage device scripts                           | 挂载共享存储，该脚本执行的前提条件是：NFS服务端已配置正确，且各个节点无共享挂载，若有则需要手动逐个取消挂载 |
| 4) auto run chrony ldap service installation script                | 安装chrony服务端和客户端，安装ldap服务端客户端。                                                            |
| 5) auto run donaukit users and directory script.                   | 自动创建donaukit用户和目录                                                                                  |
| 6) auto run benchmark tools and cuda toolkit installation scripts. | 自动安装毕昇编译器，hmpi、kml、benchmark工具(hpl、osu、stream)、cuda驱动                                    |
| 7) auto run check scripts.                                         | 一键检查基础配置项配置是否正确                                                                              |
| 8) system exit.                                                    | 退出                                                                                                        |

根据实际需要选择合适的菜单完成相应的功能。

*注意：该工具一些后面的步骤依赖前面步骤的完成，因此必须按顺序执行，不可直接执行后面步骤，例如子菜单1)是后面菜单的基础，这是因为子菜单1)会安装ansible，而后续批执行操作依赖ansible软件。*

**下文从菜单1) - 7)按顺序进行执行：**

*注意：初次使用，若提示yum源未挂载，ansible未安装。按y确认，进行自动挂载yum源与安装配置ansible。跳至*

1.  输入数字 "1" 执行【一键初始化运维节点，安装YUM源和ANSIBLE】子菜单
2.  键入回车后，输入数字 "2" 进入【操作系统配置】子菜单，子菜单下的具体功能如下：

    建议直接使用这里的子菜单1) installation and configuration all scripts，自动执行所有脚本，防止出现人为操作顺序导致脚本执行失败。

| 子菜单                                               | 功能                             |
|------------------------------------------------------|----------------------------------|
| 1) installation and configuration all scripts.       | 一键安装配置所有OS基础项         |
| 2) yum installation and configuration scripts.       | 安装配置所有除运维节点的YUM源    |
| 3) ansible installation and configuration scripts.   | 运维节点安装配置ANSIBLE软件      |
| 4) hostname installation and configuration scripts.  | 一键修改所有节点的hostname       |
| 5) pass_free installation and configuration scripts. | 一键自动配置所有节点免密配置     |
| 6) selinux installation and configuration scripts.   | 一键自动配置所有节点selinux      |
| 7) firewall installation and configuration scripts.  | 一键自动配置所有节点selinux      |
| 8) mellanox installation and configuration scripts.  | 一键自动安装配置mellanx网卡      |
| 9) ulimit installation and configuration scripts.    | 一键自动配置ulimit到其它计算节点 |
| 10) /etc/hosts synchronize.                          | 同步/etc/hosts到其它计算节点     |
| 11) return to upper-level menu.                      | 返回上级菜单                     |
| 12) system exit.                                     | 退出                             |

-   选择1，默认执行所有脚本配置。(根据提示输入root密码)，支持3次重试

    回显提示是否需要立即重启操作系统，第一次选择y。

    (重启后重新打开工具，执行

    cd /opt/hpcpilot/hpc_scritp

./auto_install_tools.sh

跳至iii;

)

-   选择11，返回上一层
1.  键入回车后，输入数字 "3" 进入【挂载共享存储】子菜单，子菜单下的具体功能如下：

    *注意：*

    1.  *需要先手动配置nfs服务端*
        1.  *nfs服务端和客户端路径不能相同，因为nfs无法在服务端挂载共享出去的目录。*

| 子菜单                         | 功能              |
|--------------------------------|-------------------|
| 1) auto run nfs client script. | 自动配置nfs客户端 |
| 2) return to upper-level menu. | 返回上级菜单      |
| 3) system exit.                | 退出              |

-   执行子菜单1)自动配置nfs客户端
-   选择子菜单2，返回主菜单。
1.  键入回车后，输入数字 "4" 进入【chrony和ldap安装】子菜单，子菜单下的具体功能如下：

| 子菜单                                        | 功能                         |
|-----------------------------------------------|------------------------------|
| 1) automatic chrony server and client script. | 自动安装Chrony服务端和客户端 |
| 2) automatic chrony_server script.            | 自动安装Chrony服务端         |
| 3) automatic chrony_client script.            | 自动安装Chrony客户端         |
| 4) automatic ldap server and client script.   | 自动安装LDAP服务端和客户端   |
| 5) automatic ldap_server script.              | 自动安装LDAP服务端           |
| 6) automatic ldap_client script.              | 自动安装LDAP客户端           |
| 7) return to upper-level menu.                | 返回上级菜单                 |
| 8) system exit.                               | 退出                         |

-   输入数字 "1"，选择子菜单1) 自动安装Chrony服务端和客户端
-   输入数字 "4"，选择子菜单4) 自动安装LDAP服务端和客户端
-   输入数字 "7"，选择子菜单7) 返回上一层

注意：

1.建议选择一键安装，也即执行1)和4)

2\. 若分步安装时，Chrony和LDAP的客户端需先装好各自服务端才可安装，也即3)和6)安装前需要安装2)和5)。

1.  键入回车后，输入数字 "5" 进入【系统用户自动创建。与业务规划目录创建】子菜单

    *注意：*

*运行完成后，会将/opt/hpcpilot目录下的文件，拷贝到共享目录中。后续使用hpcpilot，需在共享路径中执行。(share为共享目录，根据实际配置修改)*

*cd /share/software/tools/hpc_script*

1.  键入回车后，输入数字 "6" 进入【Benchamrk工具和cuda安装】子菜单

| 子菜单                              | 功能                                                                   |
|-------------------------------------|------------------------------------------------------------------------|
| 1).auto run cuda toolkit script     | 批量安装配置cuda toolkit 自动化脚本                                    |
| 2).auto run benchmark all scripts   | 安装编译benchmark所有脚本，包括： bisheng_hmpi_kml、osu、stream以及hpl |
| 3).auto run bisheng_hmpi_kml script | 安装编译bisheng_hmpi_kml                                               |
| 4).auto run osu script              | 安装编译osu                                                            |
| 5).auto run stream script           | 安装编译steam                                                          |
| 6).auto run hpl script              | 安装编译hpl                                                            |
| 7).return to upper-level menu       | 返回上级菜单                                                           |
| 8)system exit                       | 退出                                                                   |

-   输入数字 "1"，选择子菜单1) 批量安装配置cuda toolkit 自动化脚本
-   输入数字 "2"，选择子菜单2) 安装编译benchmark所有脚本，包括： bisheng_hmpi_kml、osu、stream以及hpl
-   输入数字 "7"，选择子菜单7) 返回上级菜单
1.  键入回车后，输入数字 "7" 执行【自动检查脚本】子菜单，若检查均成功则选择退出，若检查某项错误则根据提示，回到对于子菜单重新执行

## 注意事项

1.  手动脚本运行顺序一般为basic_script，service_script，benchmark_script，可根据实际部署情况调整相关运行操作。
2.  运行auto_check_script.sh或auto_install_script.sh执行相关自动化操作也可单独运行单个脚本执行某项操作
3.  该脚本中benchmark_script中的脚本以毕昇,HMPI,KML为依赖搭建的测试模型，其运行顺序为先运行compile_bisheng_hmpi_kml.sh，其他测试工具脚本无指定运行顺序。

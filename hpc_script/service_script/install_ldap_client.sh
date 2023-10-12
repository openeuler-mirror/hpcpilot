#!/bin/bash

######################################################################
# 脚本描述：安装配置LDAP客户端自动化脚本                                     #
# 注意事项：无                                                          #
######################################################################

# 引用公共函数文件开始
if [ "${1}" == "opt" ]; then
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/hpcpilot/hpc_script
else
    # 定义脚本文件、配置文件存放目录
    base_directory=/${1}/software/tools/hpc_script
fi
source ${base_directory}/common.sh ${1}

user_sk_file=/etc/passwd
# 引用公共函数文件结束
function expect_scp_to_remote_command() {
  local ip="$1"
  local pw="$2"
  local source_path="$3"
  local target_path="$4"
    expect << EOF
    log_user 0
    set timeout 120
    spawn bash -c {scp -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o NumberOfPasswordPrompts=1 -q -r root@${ip}:${source_path} ${target_path}}
    expect {
        "yes/no" { send "yes\n";exp_continue }
        "password:" { send -- "${pw}\n" }
        default { exit 1 }
    }
    expect eof
    catch wait result;
    exit [lindex \$result 3]
EOF
    local result=$?
    return $result
}

function scp_to_remote_command() {
  local ip="$1"
  local source_path="$2"
  local target_path="$3"
  local pw="$4"
  echo "remote_ip: ${ip} source_path: ${source_path} target_path: ${target_path} passwd: ${pw}"
  ssh root@${ip} -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o PasswordAuthentication=no "uname" 1>/dev/null 2>/dev/null
  if [ 0 = $? ]; then
    scp -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -q root@${ip}:"${source_path}" "${target_path}"
  else
    yum install -y tcl
    yum install -y expect
    expect_scp_to_remote_command "${ip}" "${pw}" "${source_path}" "${target_path}"
  fi
  local result=$?
  return $result
}

# 服务器节点ROOT登录密码
root_login_password=$(get_ini_value common_global_conf common_sys_root_password)
# openldap服务端IP（HA场景为虚拟IP）
# ldap_server_ip=$(get_ini_value service_conf virtual_ldap_server_ip $(get_ini_value service_conf master_ldap_server_ip))
ldap_domain=$(get_ini_value service_conf ldap_domain_name ldap01.huawei.com)
# 根据ldap服务访问域名获取dc值(array_dc[0]=huawei,array_dc[1]=com)
array_dc=($(get_ldapdc_by_domain))
ldap_base_dc="dc=${array_dc[0]},dc=${array_dc[1]}"
# openldap服务端登录密码
ldap_login_password=$(get_ini_value service_conf ldap_login_password)
# 将ldap.crt证书复制到root目录下
ldap_master_ip=$(get_ini_value service_conf master_ldap_server_ip)
ssh_command "${ldap_master_ip}" "ls ${base_directory}/service_script | grep ldap.crt" "${root_login_password}"
if [ 0 = $? ]; then
    ssh_command "${ldap_master_ip}" "cp ${base_directory}/service_script/ldap.crt /root/" "${root_login_password}"
else
    ssh_command "${ldap_master_ip}" "cp /etc/openldap/certs/ldap.crt /root/" "${root_login_password}"
fi
if [ "${ldap_master_ip}" != "${om_machine_ip}" ];then
  rm -f /root/ldap.crt
fi
#确定要执行安装ldap客户端的hosts，规则如下：
#若为扩容场景，则执行扩容节点中是ldap客户端的节点
#若为非扩容场景，则执行ldap客户端的节点
if [ "$(check_run_expansion)" == "1" ]; then
    play_hosts="expansion : ldap_client"
else
    play_hosts="ldap_client"
fi
#将ldapserver端生成的证书移动ansible服务端节点(运维节点),然后再进行后续分发的步骤
scp_to_remote_command ${ldap_master_ip} /root/ldap.crt /root/ldap.crt ${root_login_password}
ansible-playbook -e "ldap_server_ip=${ldap_domain} ldap_base_dc=${ldap_base_dc} hosts=${play_hosts}" ${base_directory}/service_script/install_ldap_cli_TLS.yml
ansible-playbook -e "ldap_server_ip=${ldap_domain} ldap_login_password=${ldap_login_password} ldap_base_dc=${ldap_base_dc} hosts=${play_hosts}" ${base_directory}/service_script/install_ldap_nslcd.yml
# 在最后一个client 节点执行添加默认用户用来测试
cli_ip=$(ansible ${play_hosts} --list-hosts | shuf -n 1)
ssh_command "${cli_ip}" "./${base_directory}/service_script/add_origin_ldap_user.sh" "${root_login_password}"


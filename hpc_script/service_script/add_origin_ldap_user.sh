#!/usr/bin/env bash

######################################################################
# 脚本描述：执行ldap测试用户脚本                                           #
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

function add_origin_ldap_user(){
  ldap_login_sk=$(get_ini_value service_conf ldap_login_password)
  log_info "Creating a Read-only LDAP User..." true
  ldap_group=`cat /etc/group |grep ldapDemo`
  if [ "$ldap_group" == "" ];then
    groupadd ldapDemo
  fi
  useradd -g ldapDemo ldapDemo
  if [ $? -eq 0 ];then
      log_info "The ldapDemo user is successfully created." true
      cat /etc/group |grep "ldapDemo" > /tmp/group.in
      cd /usr/share/migrationtools/
      ./migrate_group.pl /tmp/group.in /tmp/group.ldif
      gidNumber=`cat /tmp/group.ldif |grep "gidNumber" |awk -F ': ' '{print $2}'`
      cat > /tmp/sk.ldif <<EOF
dn: uid=ldapDemo,ou=People,dc=huawei,dc=com
uid: ldapDemo
cn: ldapDemo
sn: ldapDemo
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
objectClass: shadowAccount
userPassword: {crypt}$6$o/.Ehm5xQBmaBdo.$VLiigsUCbfcaFDrjChgbtPhFkkQf43hkEOyC92qWBxysoIrudwUYbUnI3OKjxgAF4VGP1XRMpgIuo5s0UTKB51
shadowLastChange: 19565
shadowMax: 99999
shadowWarning: 7
loginShell: /bin/bash
uidNumber: $gidNumber
gidNumber: $gidNumber
homeDirectory: /home/ldapDemo
EOF
	  ldapadd -x -w "$ldap_login_sk" -D "cn=root,dc=huawei,dc=com" -f /tmp/group.ldif -H ldaps://${ldap_master_ip}:636
    ldapadd -x -w "$ldap_login_sk" -D "cn=root,dc=huawei,dc=com" -f /tmp/sk.ldif -H ldaps://${ldap_master_ip}:636
    userdel -r ldapDemo
    ldap_user=`ldapsearch -x -b "dc=huawei,dc=com" -H ldaps://${ldap_master_ip}:636 |grep dn |grep "ldapDemo"`
    log_info "Check whether the Read-Only LDAP user is successfully created."
    if [ "$ldap_user" != "" ];then
        log_info "The Read-only LDAP user ldapDemo is successfully created." true
        cat > /tmp/nologin.ldif <<EOF
dn: uid=ldapDemo,ou=People,dc=huawei,dc=com
changetype: modify
replace: loginShell
loginShell: /sbin/nologin
EOF
        ldapmodify -w "$ldap_login_sk" -D "cn=root,dc=huawei,dc=com" -f /tmp/nologin.ldif -H ldaps://${ldap_master_ip}:636
    else
        log_error "Failed to create a Read-only LDAP user. Check the failure cause." true
        exit 1
    fi
  fi
}


# openldap服务端登录密码
ldap_login_psd=$(get_ini_value service_conf ldap_login_password)
# 将ldap.crt证书复制到root目录下
ldap_master_ip=$(get_ini_value service_conf master_ldap_server_ip)

#将ldapserver端生成的证书移动ansible服务端节点(运维节点),然后再进行后续分发的步骤
scp_to_remote_command ${ldap_master_ip} /root/ldap.crt /root/ldap.crt ${root_login_password}
ansible-playbook -e "ldap_server_ip=${ldap_domain} ldap_base_dc=${ldap_base_dc} hosts=${play_hosts}" ${base_directory}/service_script/install_ldap_cli_TLS.yml
ansible-playbook -e "ldap_server_ip=${ldap_domain} ldap_login_psd=${ldap_login_psd} ldap_base_dc=${ldap_base_dc} hosts=${play_hosts}" ${base_directory}/service_script/install_ldap_nslcd.yml
add_origin_ldap_user
ldap_user=`ldapsearch -x -b "dc=huawei,dc=com" -H ldaps://${ldap_master_ip}:636 |grep dn |grep "ldapDemo"`
log_info "Check whether the LDAP client successfully connects to the server." true
if [ "$ldap_user" != "" ];then
    log_info "The LDAP client successfully connects to the server." true
else
    log_error "Failed to connects to the LDAP server, please check." true
fi
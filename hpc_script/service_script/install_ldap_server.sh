#!/bin/bash

######################################################################
# 脚本描述：安装配置LDAP服务端自动化脚本                                     #
# HA mode:mandotory parameters: MASTER_IP ROOT_LOGIN_PW SLAVE_IP     #
#         VIRTUAL_MASTER_IP                                          #
# Non-HA mode: mandotory parameters: MASTER_IP ROOT_LOGIN_PW         #
# 注意事项：无                                                          #
######################################################################
# 引用公共函数文件开始
if [ "${1}" == "opt" ]; then
  # 定义脚本文件、配置文件存放目录
  base_directory=/${1}/hpcpilot/hpc_script
  sourcecode_dir=/${1}/hpcpilot/sourcecode
else
  # 定义脚本文件、配置文件存放目录
  base_directory=/${1}/software/tools/hpc_script
  sourcecode_dir=/${1}/software/sourcecode
fi
source ${base_directory}/common.sh ${1}
# 引用公共函数文件结束

root_dir=${1}
# ldap登录密码
ldap_login_password=$(get_ini_value service_conf ldap_login_password)
# ldap主节点IP地址
ldap_master_ip=$(get_ini_value service_conf master_ldap_server_ip)
# ldap备节点IP地址
ldap_slave_ip=$(get_ini_value service_conf slave_ldap_server_ip)
# HA主备配置时虚拟IP地址
ldap_virtual_ip=$(get_ini_value service_conf virtual_ldap_server_ip)
# 获取ldap服务访问域名,如果不填或者为空默认值为：dc=huawei,dc=com
ldap_domain=$(get_ini_value service_conf ldap_domain_name ldap01.huawei.com)
# 根据ldap服务访问域名获取dc值(array_dc[0]=huawei,array_dc[1]=com)
array_dc=($(get_ldapdc_by_domain))
# 服务器节点ROOT登录密码
root_login_password=$(get_ini_value common_global_conf common_sys_root_password)
# 获取本机IP
IP_ADDR=$(ifconfig -a 2> /dev/null | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")

HOST_NAME=$(hostname)

VIRTUAL_ROUTER_ID=204
ETH_NAME=$(ip addr | grep -B 2 $IP_ADDR | head -n 1 | awk -F: '{print $2}' | tr -d [:blank:])

OS_TYPE=$(cat /etc/system-release | awk '{print $1}')
MIGRATE_DIR="/usr/share/migrationtools/migrate_common.ph"
LDAP_SERVICE_DIR="/usr/lib/systemd/system/slapd.service"
RSA_DIR="/root/.ssh"

CURRENT_PATH=$(pwd)
REMOTE_PATH="/root"

function expect_scp_to_remote_command() {
  local ip="$1"
  local pw="$2"
  local source_path="$3"
  local target_path="$4"
    expect << EOF
    log_user 0
    set timeout 120
    spawn bash -c {scp -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o NumberOfPasswordPrompts=1 -q -r ${source_path} root@${ip}:${target_path}}
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
    scp -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -q "${source_path}" root@${ip}:"${target_path}"
  else
    yum install -y tcl
    yum install -y expect
    expect_scp_to_remote_command "${ip}" "${pw}" "${source_path}" "${target_path}"
  fi
  local result=$?
  return $result
}

function selinux_firewall_check() {
  local selinux_status=$(sestatus | awk 'NR==1{print $3}')
  if [ "${selinux_status}" = "enabled" ]; then
      log_info "Disabling SELinux..." true
      sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config && setenforce 0
      log_info "Operating system needs to be restarted, please run the reboot command." true
      exit 0
  fi
  log_info "Disabling firewalld..." true
  systemctl stop firewalld
  systemctl disable firewalld
  firewall-cmd --state 2>/tmp/firewall_status.txt
  local firewall_status=$(cat /tmp/firewall_status.txt)
  if [[ "${firewall_status}" == "not running" ]]; then
      log_info "The firewall has been disabled." true
  else
      log_error "Failed to disable the firewall." true
      exit 255
  fi
}

function create_slapd_ldif() {
  cat >/etc/openldap/slapd.ldif <<EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcArgsFile: /var/run/openldap/slapd.args
olcPidFile: /var/run/openldap/slapd.pid

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

include: file:///etc/openldap/schema/core.ldif
include: file:///etc/openldap/schema/cosine.ldif
include: file:///etc/openldap/schema/nis.ldif
include: file:///etc/openldap/schema/inetorgperson.ldif

dn: olcDatabase=frontend,cn=config
objectClass: olcDatabaseConfig
objectClass: olcFrontendConfig
olcDatabase: frontend

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,c
 n=auth" manage by * none

dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,c
 n=auth" read by dn.base="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}" read by * none

dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: dc=${array_dc[0]},dc=${array_dc[1]}
olcRootDN: cn=root,dc=${array_dc[0]},dc=${array_dc[1]}
olcRootPW: $1
olcDbDirectory: /var/lib/ldap
olcDbIndex: objectClass eq,pres
olcDbIndex: ou,cn,mail,surname,givenname eq,pres,sub
EOF

  if [ $OS_TYPE != "openEuler" ]; then
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
  fi
}

function deploy_ldap_service() {
    log_info "Yum OpenLDAP service installing..." true
    if [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
        yum -y localinstall ${sourcecode_dir}/migrationtools-47-15.el7.noarch.rpm
        yum -y install openldap openldap-clients openldap-servers openldap-devel migrationtools
        if [ $? -ne 0 ]; then
            log_error "Failed to install the LDAP service." true
            exit 255
        fi
    elif [ $OS_TYPE = "CentOS" ]; then
        yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel migrationtools
        if [ $? -ne 0 ]; then
            log_error "Failed to install the LDAP service." true
            exit 255
        fi
    fi
    log_info "ldap version: $(slapd -VV)" true
    log_info "Configuring the LDAP Service" true
    mv /etc/openldap/slapd.d /etc/openldap/slapd.d.bak
    mkdir -p /etc/openldap/slapd.d
  
    passwd=$(slappasswd -s ${ldap_login_password})
    create_slapd_ldif $passwd
    slapadd -n 0 -F /etc/openldap/slapd.d -l /etc/openldap/slapd.ldif
    chown ldap:ldap -R /etc/openldap/slapd.d
    chown ldap:ldap -R /var/lib/ldap
    chmod 700 -R /var/lib/ldap
    slaptest -u
    if [ $? -eq 0 ]; then
        log_info "Basic configuration of OpenLDAP is complete." true
    else
        log_error "Basic configuration of OpenLDAP is failed." true
        exit 255
    fi
  
    systemctl enable slapd && systemctl start slapd
    if [ "$(systemctl status slapd | grep active | grep running)" != "" ]; then
        log_info "Slapd service is running properly." true
    else
        log_error "Slapd service is running abnormally." true
        exit 255
    fi

    netstat -antup | grep 389 | grep slapd
    if [ $? != 0 ]; then
        log_error "ERROR: The slapd service listening port is abnormal." true
        exit 255
    else
        log_info "The slapd service listening port is normal." true
    fi
    log_info "Modifying migration file..." true
    sed -i "71c \$DEFAULT_MAIL_DOMAIN = \"${array_dc[0]}.${array_dc[1]}\";" $MIGRATE_DIR
    sed -i "74c \$DEFAULT_BASE = \"dc=${array_dc[0]},dc=${array_dc[1]}\";" $MIGRATE_DIR
    sed -i "90s/0/1/g" $MIGRATE_DIR
  
    log_info "Improving service reliability..." true
    limit_nofile=$(cat $LDAP_SERVICE_DIR | grep LimitNOFILE)
    if [ "$limit_nofile" = "" ]; then
        sed -i '/Service/a LimitNOFILE=65535\nRestart=always\nRestartSec=30s\nLimitNPROC=65535' $LDAP_SERVICE_DIR
    fi
    systemctl daemon-reload
    systemctl restart slapd
}

function ldap_database_conf() {
  cat >/root/base.ldif <<EOF
dn: dc=${array_dc[0]},dc=${array_dc[1]}
o: ${array_dc[0]} ${array_dc[1]}
dc: ${array_dc[0]}
objectClass: top
objectClass: dcObject
objectClass: organization

dn: cn=root,dc=${array_dc[0]},dc=${array_dc[1]}
cn: root
objectClass: organizationalRole
description: Directory Manager

dn: ou=People,dc=${array_dc[0]},dc=${array_dc[1]}
ou: People
objectClass: top
objectClass: organizationalUnit

dn: ou=Group,dc=${array_dc[0]},dc=${array_dc[1]}
ou: Group
objectClass: top
objectClass: organizationalUnit
EOF

    log_info "Importing the base database..." true
    ldapadd -x -w "${ldap_login_password}" -D "cn=root,dc=${array_dc[0]},dc=${array_dc[1]}" -f /root/base.ldif -h localhost
    log_info "Checking database status..." true
    ldapsearch -x -D "cn=root,dc=${array_dc[0]},dc=${array_dc[1]}" -w "${ldap_login_password}" -b "dc=${array_dc[0]},dc=${array_dc[1]}" | grep dn
}

function ldap_log_conf() {
  loglevel_file="/root/loglevel.ldif"
  if [ -f "$loglevel_file" ] && [ -s "$loglevel_file" ]; then
    log_warn "ldap visit log file already exists" true
  else

    cat >/root/loglevel.ldif <<EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
EOF

  fi
  ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/loglevel.ldif
  systemctl restart slapd

  cat >>/etc/rsyslog.conf <<EOF
local4.* /var/log/slapd.log
EOF

  systemctl restart rsyslog
  systemctl restart slapd

  cat >/etc/logrotate.d/slapd <<EOF
/var/log/slapd.log{
daily
rotate 5
copytruncate
nocompress
dateext
missingok
}
EOF

  logrotate -f /etc/logrotate.d/slapd
}

function ssh_key_conf() {
    ping -c2 -i0.3 -W1 $1
    if [ $? != 0 ]; then
      log_error "error: Ping $1 failed." true
      return 1
    elif [ -f "$RSA_DIR/id_rsa" ] && [ -f "$RSA_DIR/id_rsa.pub" ]; then
      log_warn "Public/private rsa key pair already exists." true
    else
      log_info "Generate rsa key pair, please keep pressing Enter..." true
      ssh-keygen -t rsa
    fi
  
    ssh-copy-id -i $RSA_DIR/id_rsa.pub $1
    local result=$?
    return $result
}

function master_slave_trust_conf() {
    if [ -n "$NODE_PRI" ]; then
        log_info "Configuring /etc/hosts..." true
        local master_host_name=$(ansible ${ldap_master_ip} -m shell -a 'hostname' | awk '/stdout/ {print $2}' | tr -d '"')
        local slave_host_name=$(ansible ${ldap_slave_ip} -m shell -a 'hostname' | awk '/stdout/ {print $2}' | tr -d '"')
        echo "${ldap_master_ip} $master_host_name" >>/etc/hosts
        echo "${ldap_slave_ip} $slave_host_name" >>/etc/hosts
    fi
    if [ "$NODE_PRI" = "master" ]; then
        ssh_key_conf ${ldap_slave_ip}
    elif [ "$NODE_PRI" = "slave" ]; then
        ssh_key_conf ${ldap_master_ip}
    fi
  
    if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
        echo "SLAPD_LDAPI=yes" >>/etc/sysconfig/slapd
        systemctl restart slapd
    fi
  # Synchronize configuration
  log_info "Synchronize configuration..." true
  sync_path="/root/ldap-sync/"
  mkdir -p $sync_path

  cat >$sync_path/mod_syncprov.ldif <<EOF
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulePath: /usr/lib64/openldap
olcModuleLoad: syncprov.la
EOF

  cat >$sync_path/serverid.ldif <<EOF
dn: cn=config
changetype: modify
add: olcServerId
EOF

  if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ]; then
    if [ "$NODE_PRI" = "master" ]; then
      echo "olcServerId: 1" >>$sync_path/serverid.ldif
    elif [ "$NODE_PRI" = "slave" ]; then
      echo "olcServerId: 2" >>$sync_path/serverid.ldif
    fi
  elif [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
    if [ "$NODE_PRI" = "master" ]; then
      echo "olcServerId: 1 ldap://${ldap_master_ip}" >>$sync_path/serverid.ldif
    elif [ "$NODE_PRI" = "slave" ]; then
      echo "olcServerId: 2 ldap://${ldap_slave_ip}" >>$sync_path/serverid.ldif
    fi
  fi

  cat >$sync_path/syncprov.ldif <<EOF
dn: olcOverlay=syncprov,olcDatabase={2}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpSessionLog: 100
EOF

  cat >$sync_path/sync-ha.ldif <<EOF
dn: olcDatabase={2}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
             provider=ldap://${ldap_master_ip}
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:0
olcSyncrepl: rid=002
             provider=ldap://${ldap_slave_ip}
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
EOF

  log_info "Importing mod_syncprov.ldif..." true
  ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/mod_syncprov.ldif
  log_info "Importing serverid.ldif..." true
  ldapmodify -Y EXTERNAL -H ldapi:/// -f $sync_path/serverid.ldif
  log_info "Importing syncprov.ldif..." true
  ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/syncprov.ldif
  log_info "Importing sync-ha.ldif..." true
  ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/sync-ha.ldif

  chown -R ldap:ldap /etc/openldap/slapd.d/

  systemctl restart slapd

  log_info "View the existing LDAP users." true
  ldapsearch -x -D "cn=root,dc=${array_dc[0]},dc=${array_dc[1]}" -w "${ldap_login_password}" -b "dc=${array_dc[0]},dc=${array_dc[1]}" -H ldap://$IP_ADDR | grep dn

  if [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
    if [ "$NODE_PRI" = "master" ]; then
      sed -i "/^olcServerID/c olcServerID: 1" /etc/openldap/slapd.d/cn\=config.ldif
    elif [ "$NODE_PRI" = "slave" ]; then
      sed -i "/^olcServerID/c olcServerID: 2" /etc/openldap/slapd.d/cn\=config.ldif
    fi
  fi
}

function failover_conf() {
  log_info "ldap failover configuration..." true
  yum install keepalived -y

  failover_path="/root/fail-over"
  mkdir -p $failover_path

  cat >$failover_path/slapd_master.sh <<EOF
#!/bin/bash
systemctl start slapd.service
EOF

  cat >$failover_path/slapd_stop.sh <<EOF
#!/bin/bash
systemctl stop slapd.service
EOF

  cat >$failover_path/slapd_check.sh <<EOF
#!/bin/bash
ldapPid=\$(ps -ef |grep /usr/sbin/slapd|grep -v grep|awk '{print $2}'|grep -v PID)
if [ "\$ldapPid" == "" ]; then
	systemctl start slapd.service
	exit 1
else
	exit 0
fi
EOF

  chmod o+x $failover_path/slapd_master.sh
  chmod o+x $failover_path/slapd_stop.sh
  chmod o+x $failover_path/slapd_check.sh

  if [ "$NODE_PRI" = "master" ]; then
    state="MASTER"
  elif [ "$NODE_PRI" = "slave" ]; then
    state="BACKUP"
  fi

  if [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
    rm -f /etc/keepalived/keepalived.conf
  else

    cat >/etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived
global_defs {
	router_id $HOST_NAME
}
vrrp_script check_ldap_server_status {
	script "$failover_path/slapd_check.sh"
	interval 3
	weight -5
}

vrrp_instance VI_LDAP {
	state $state
	interface $ETH_NAME
	virtual_router_id $VIRTUAL_ROUTER_ID
	priority 100
	advert_int 1
	virtual_ipaddress {
	 ${ldap_virtual_ip}
	}
	notify_master "$failover_path/slapd_master.sh"
	notify_backup "$failover_path/slapd_master.sh"
	notify_stop "$failover_path/slapd_stop.sh"
	track_script {
	  check_ldap_server_status
	}
}
EOF
  fi

  chmod 644 /etc/keepalived/keepalived.conf
  systemctl enable keepalived.service
  systemctl restart keepalived.service

  systemctl disable NetworkManager.service
  systemctl stop NetworkManager.service
}

function ssl_integration() {
  local cert_dir="/etc/openldap/certs"
  [ ! -d ${cert_dir} ] && mkdir ${cert_dir}
  if [ $IP_ADDR = ${ldap_master_ip} ]; then
    log_info "SSL integration on the server..." true
    log_info "Start generating the certificate file." true
    if [ -n "$NODE_PRI" ]; then
      IP_ADD="${ldap_virtual_ip}"
    else
      IP_ADD=$IP_ADDR
    fi

    cat >$cert_dir/my-ssl.conf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = ${ldap_domain}
IP.1 = ${IP_ADD}
EOF

    openssl genrsa -out $cert_dir/ldap.key 4096
    openssl req -new -sha256 -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=HW/OU=IT/CN=${ldap_domain}" -out $cert_dir/ldap.csr -key $cert_dir/ldap.key
    openssl x509 -req -days 3650 -in $cert_dir/ldap.csr -signkey $cert_dir/ldap.key -out $cert_dir/ldap.crt -extfile $cert_dir/my-ssl.conf
    openssl x509 -in $cert_dir/ldap.crt -text -noout
  fi

  if [ "$NODE_PRI" = "slave" ]; then
    scp root@${ldap_master_ip}:$cert_dir/ldap* $cert_dir
  fi

  chown ldap:ldap -R $cert_dir
  cp $cert_dir/ldap.crt ${base_directory}/service_script

  log_info "adding cert file..." true
  sed -i "/^olcTLSCertificateFile/d" /etc/openldap/slapd.d/cn\=config.ldif
  sed -i "/^olcTLSCertificateKeyFile/d" /etc/openldap/slapd.d/cn\=config.ldif
  sed -i "/^olcAllows/d" /etc/openldap/slapd.d/cn\=config.ldif

  echo "olcTLSCertificateFile: $cert_dir/ldap.crt" >>/etc/openldap/slapd.d/cn\=config.ldif
  echo "olcTLSCertificateKeyFile: $cert_dir/ldap.key" >>/etc/openldap/slapd.d/cn\=config.ldif
  echo "olcAllows: bind_v2" >>/etc/openldap/slapd.d/cn\=config.ldif

  log_info "Changing the LDAP Startup Mode..." true
  if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
      sed -i "/^SLAPD_URLS=/c SLAPD_URLS=\"ldapi:/// ldaps:///\"" /etc/sysconfig/slapd
  elif [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ]; then
      sed -i "/^ExecStart=/c ExecStart=/usr/sbin/slapd -u ldap -h \"ldaps:/// ldapi:///\"" /usr/lib/systemd/system/slapd.service
      systemctl daemon-reload
  fi

  log_info "========================= edit_ha_ldif_file ========================= " true
  edit_ha_ldif_file
  log_info "========================= edit_ha_ldif_file end ========================= " true

  systemctl restart slapd.service
  netstat -anp | grep 636 | grep slapd
  if [ $? -eq 0 ]; then
    log_info "TLS/SSL has been integrated into the service order." true
  else
    log_error "Failed to integrate TSL/SSL into the service order." true
    exit 255
  fi
}

function usage() {
  cat <<EOF
Usage:
	e.g.: 
	HA mode: ldap_deploy.sh -m 127.0.0.1 -s 127.0.0.2
	Non HA mode: ldap_deploy.sh 127.0.0.1
		-m		master ip address
		-s		slave ip address
EOF
}

function remove_ldap() {
  log_info "removing openldap-servers..." true
  yum remove -y openldap-servers
  rm -rf /var/lib/ldap
  rm -rf /etc/openldap
  rm -r /root/ldap.crt
}


function edit_ha_ldif_file() {
    if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ]; then
        cat >$sync_path/sync-ha.ldif <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSyncRepl
olcSyncRepl: rid=001
             provider=ldaps://${ldap_master_ip}:636
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             tls_reqcert=allow
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:0
olcSyncrepl: rid=002
             provider=ldaps://${ldap_slave_ip}:636
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             tls_reqcert=allow
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:00
-
replace: olcMirrorMode
olcMirrorMode: TRUE
EOF
    fi

    if [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ]; then
        cat >$sync_path/sync-ha.ldif <<EOF
dn: olcDatabase={2}mdb,cn=config
changetype: modify
replace: olcSyncRepl
olcSyncRepl: rid=001
             provider=ldaps://${ldap_master_ip}:636
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             tls_reqcert=allow
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:0
olcSyncrepl: rid=002
             provider=ldaps://${ldap_slave_ip}:636
             bindmethod=simple
             binddn="cn=root,dc=${array_dc[0]},dc=${array_dc[1]}"
             credentials=${ldap_login_password}
             searchbase="dc=${array_dc[0]},dc=${array_dc[1]}"
             tls_reqcert=allow
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:00
-
replace: olcMirrorMode
olcMirrorMode: TRUE
EOF
    fi
    ldapmodify -Y EXTERNAL -H ldapi:/// -f $sync_path/sync-ha.ldif
    chown -R ldap:ldap /etc/openldap/slapd.d/
    systemctl restart slapd.service
}

function ldap_service_installation_and_deployment() {
    if [ -n "${ldap_master_ip}" ] && [ -n "${ldap_slave_ip}" ] && [ -z "$NODE_PRI" ]; then
        ping -c2 -i0.3 -W1 ${ldap_master_ip}
        if [ $? != 0 ]; then
            log_error "Ping ${ldap_master_ip} failed, The LDAP service installation is terminated." true
            exit 255
        fi
        ping -c2 -i0.3 -W1 ${ldap_slave_ip}
        if [ $? != 0 ]; then
            log_error "Ping ${ldap_slave_ip} failed, The LDAP service installation is terminated." true
            exit 255
        fi

        ssh_command "${ldap_master_ip}" "export NODE_PRI=master && sh $0 ${root_dir}" "${root_login_password}" "true"
        ssh_command "${ldap_slave_ip}" "export NODE_PRI=slave && sh $0 ${root_dir}" "${root_login_password}" "true"
        return 0
    # LDAP非HA且服务端不在当前运维节点
    elif [ -n "${ldap_master_ip}" ] && [ -z "${ldap_slave_ip}" ] && [ $IP_ADDR != ${ldap_master_ip} ]; then
        ssh_command "${ldap_master_ip}" "$0 ${root_dir}" "${root_login_password}"
        return 0
    fi
    if [ "$(rpm -qa | grep ldap)" != "" ]; then
        remove_ldap
    fi
    selinux_firewall_check
    deploy_ldap_service
    ldap_database_conf
    ldap_log_conf
    if [ -n "$NODE_PRI" ]; then
        master_slave_trust_conf
        # edit_ha_ldif_file
        failover_conf
    fi
    ssl_integration
}

ldap_service_installation_and_deployment "$@"
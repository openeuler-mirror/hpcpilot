#!/bin/bash

# HA mode mandotory parameters: MASTER_IP ROOT_LOGIN_PW SLAVE_IP VIRTUAL_MASTER_IP
# Non-HA mode mandotory parameters: MASTER_IP ROOT_LOGIN_PW

root_dir=$(echo "$(pwd)" | awk '{split($1,arr,"/");print arr[2]}')
source /share/software/tools/hpc_script/common.sh share

ROOT_LDAP_INIT_PASSWD=$(get_ini_value service_conf ldap_login_password)
MASTER_IP=$(get_ini_value service_conf master_ldap_server_ip)
SLAVE_IP=$(get_ini_value service_conf slave_ldap_server_ip)
ROOT_LOGIN_PW=$(get_ini_value service_conf common_sys_root_password)
VIRTUAL_MASTER_IP=$(get_ini_value service_conf virtual_ldap_server_ip)

IP_ADDR=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"` # 获取本机IP

HOST_NAME=`hostname`

VIRTUAL_ROUTER_ID=204
ETH_NAME=`ip addr | grep -B 2 $IP_ADDR | head -n 1 | awk -F: '{print $2}' | tr -d [:blank:]`

OS_TYPE=`cat /etc/system-release | awk '{print $1}'`
MIGRATE_DIR="/usr/share/migrationtools/migrate_common.ph"
LDAP_SERVICE_DIR="/usr/lib/systemd/system/slapd.service"
RSA_DIR="/root/.ssh"

CURRENT_PATH=`pwd`
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
    ssh root@${ip} -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o PasswordAuthentication=no "uname"
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

function expect_ssh_command() {
    local ip="$1"
    local pw="$2"
    local cmd="$3"
    local show_info="$4"
    local time_out="$5"

    local expect_show="0"
    [ "${show_info}" = "true" ] && expect_show="1"
    [ -z "${time_out}" ] && time_out=120

    expect << EOF
    log_user "${expect_show}"
    set timeout "${time_out}"
    spawn bash -c {ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o NumberOfPasswordPrompts=1 root@${ip} "${cmd}"}
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

function ssh_command() {
    local ip="$1"
    local cmd="$2"
    local pw="$3"
	local show_info="$4"
    local time_out="$5"

    local ssh_show="-q"
    local blank_set="> /dev/null 2>&1"
    if [ "${show_info}" = "true" ];then
        ssh_show=""
        blank_set=""
    fi
    ssh root@${ip} -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o PasswordAuthentication=no "uname"
    if [ 0 = $? ]; then
        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=10 -o ServerAliveCountMax=3 ${ssh_show} root@${ip} "${cmd}" "${blank_set}"
    else
        expect_ssh_command "${ip}" "${pw}" "${cmd}" "${show_info}" "${time_out}"
    fi
    local result=$?
    return $result
}

function selinux_firewall_check(){
	# selinux status check
	selinux_status=`sestatus |awk 'NR==1{print $3}'`
	if [ "${selinux_status}" = "enabled" ]; then
		echo "Disabling SELinux..."
		sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config && setenforce 0
		echo "The system needs to be restarted, please run the reboot command."
		exit 0
	fi
	
	echo "Disabling firewalld..."
	systemctl stop firewalld
	systemctl disable firewalld
	firewall-cmd --state 2> /tmp/firewall_status.txt
	firewall_status=`cat /tmp/firewall_status.txt`
	if [[ "${firewall_status}" = "not running" ]];then
		echo "The firewall has been disabled."
	else
		echo "Failed to disable the firewall."
		exit 255
	fi
}

function create_slapd_ldif(){
cat > /etc/openldap/slapd.ldif << EOF
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
 n=auth" read by dn.base="cn=root,dc=huawei,dc=com" read by * none

dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: dc=huawei,dc=com
olcRootDN: cn=root,dc=huawei,dc=com
olcRootPW: $1
olcDbDirectory: /var/lib/ldap
olcDbIndex: objectClass eq,pres
olcDbIndex: ou,cn,mail,surname,givenname eq,pres,sub
EOF

	if [ $OS_TYPE != "openEuler" ];then
		cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
	fi
}

function deploy_ldap_service(){
	echo "yum OpenLDAP service installing..."
	if [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		yum -y localinstall /share/software/sourcecode/migrationtools-47-15.el7.noarch.rpm
		yum -y install openldap openldap-clients openldap-servers openldap-devel migrationtools
		if [ $? -ne 0 ];then
			echo "Failed to install the LDAP service."
			exit 255
		fi
	elif [ $OS_TYPE = "CentOS" ];then
		yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel migrationtools
		if [ $? -ne 0 ];then
			echo "Failed to install the LDAP service."
			exit 255
		fi
	fi
		
	echo "ldap version:"
	slapd -VV

	echo "Configuring the LDAP Service"
	mv /etc/openldap/slapd.d /etc/openldap/slapd.d.bak
	mkdir -p /etc/openldap/slapd.d
	
	passwd=`slappasswd -s $ROOT_LDAP_INIT_PASSWD`
	create_slapd_ldif $passwd
	slapadd -n 0 -F /etc/openldap/slapd.d -l /etc/openldap/slapd.ldif
	chown ldap:ldap -R /etc/openldap/slapd.d
	chown ldap:ldap -R /var/lib/ldap
	chmod 700 -R /var/lib/ldap
	slaptest -u
	if [ $? -eq 0 ]; then
		echo "The basic configuration of OpenLDAP is complete."
	else
		echo "ERROR: The basic configuration of OpenLDAP is failde."
		exit 255
	fi
	
	systemctl enable slapd
	systemctl start slapd
	slapd_status=`systemctl status slapd | grep active | grep running`
	if [ "$slapd_status" != "" ];then
		echo "Slapd service is running properly."
	else
		echo "Slapd service is running abnormally."
		exit 255
	fi
	
	netstat -antup | grep 389 | grep slapd
	if [ $? != 0 ]; then
		echo "ERROR: The slapd service listening port is abnormal."
		exit 255
	else 
		echo "The slapd service listening port is normal."
	fi
	
	echo "Modifying migration file..."
	sed -i "71c \$DEFAULT_MAIL_DOMAIN = \"huawei.com\";" $MIGRATE_DIR
	sed -i "74c \$DEFAULT_BASE = \"dc=huawei,dc=com\";" $MIGRATE_DIR
	sed -i "90s/0/1/g" $MIGRATE_DIR
	
	echo "Improving service reliability..."
	limit_nofile=`cat $LDAP_SERVICE_DIR | grep LimitNOFILE`
	if [ "$limit_nofile" = "" ]; then
		sed -i '/Service/a LimitNOFILE=65535\nRestart=always\nRestartSec=30s\nLimitNPROC=65535' $LDAP_SERVICE_DIR
	fi
	
	systemctl daemon-reload
	systemctl restart slapd
}

function ldap_database_conf(){
cat > /root/base.ldif << EOF
dn: dc=huawei,dc=com
o: huawei com
dc: huawei
objectClass: top
objectClass: dcObject
objectclass: organization

dn: cn=root,dc=huawei,dc=com
cn: root
objectClass: organizationalRole
description: Directory Manager

dn: ou=People,dc=huawei,dc=com
ou: People
objectClass: top
objectClass: organizationalUnit

dn: ou=Group,dc=huawei,dc=com
ou: Group
objectClass: top
objectClass: organizationalUnit
EOF
	
	echo "Importing the base database..."
	ldapadd -x -w "$ROOT_LDAP_INIT_PASSWD" -D "cn=root,dc=huawei,dc=com" -f /root/base.ldif -h localhost
	echo "Checking database status..."
	ldapsearch -x -D 'cn=root,dc=huawei,dc=com' -w "$ROOT_LDAP_INIT_PASSWD" -b 'dc=huawei,dc=com' | grep dn
}

function ldap_log_conf(){
	loglevel_file="/root/loglevel.ldif"
	if [ -f "$loglevel_file" ] && [ -s "$loglevel_file" ]; then
		echo "ldap visit log file already exists"
	else

cat > /root/loglevel.ldif << EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
EOF

	fi
	
	ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/loglevel.ldif
	systemctl restart slapd
	
cat >> /etc/rsyslog.conf << EOF
local4.* /var/log/slapd.log
EOF
	
	systemctl restart rsyslog
	systemctl restart slapd
	
cat > /etc/logrotate.d/slapd << EOF
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
	if [ $? != 0 ];then
		echo "error: Ping $1 failed."
		return 1
	elif [ -f "$RSA_DIR/id_rsa" ] && [ -f "$RSA_DIR/id_rsa.pub" ];then
		echo "Public/private rsa key pair already exists."
	else
		echo "Generate rsa key pair, please keep pressing Enter..."
		ssh-keygen -t rsa
	fi
	
	ssh-copy-id -i $RSA_DIR/id_rsa.pub $1
	local result=$?
	return $result
}

function master_slave_trust_conf(){
	if [ -n "$NODE_PRI" ];then
		echo "Configuring /etc/hosts..."
		local master_host_name=`ssh root@$MASTER_IP "hostname"`
		local slave_host_name=`ssh root@$SLAVE_IP "hostname"`
		echo "$MASTER_IP $master_host_name" >> /etc/hosts
		echo "$SLAVE_IP $slave_host_name" >> /etc/hosts
	fi
	
	if [ $NODE_PRI = "master" ];then
		ssh_key_conf $SLAVE_IP
	elif [ $NODE_PRI = "slave" ];then
		ssh_key_conf $MASTER_IP
	fi
	
	if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		echo "SLAPD_LDAPI=yes" >> /etc/sysconfig/slapd;
		systemctl restart slapd
	fi
	
	# Synchronize configuration
	echo "Synchronize configuration..."
	sync_path="/root/ldap-sync/"
	mkdir -p $sync_path

cat > $sync_path/mod_syncprov.ldif << EOF
dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulePath: /usr/lib64/openldap
olcModuleLoad: syncprov.la
EOF
	
cat > $sync_path/serverid.ldif << EOF
dn: cn=config
changetype: modify
add: olcServerId
EOF

	if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ];then
		if [ $NODE_PRI = "master" ];then
			echo "olcServerId: 1" >> $sync_path/serverid.ldif
		elif [ $NODE_PRI = "slave" ];then
			echo "olcServerId: 2" >> $sync_path/serverid.ldif
		fi	
	elif [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		if [ $NODE_PRI = "master" ];then
			echo "olcServerId: 1 ldap://$MASTER_IP" >> $sync_path/serverid.ldif
		elif [ $NODE_PRI = "slave" ];then
			echo "olcServerId: 2 ldap://$SLAVE_IP" >> $sync_path/serverid.ldif
		fi
	fi
	
cat > $sync_path/syncprov.ldif << EOF
dn: olcOverlay=syncprov,olcDatabase={2}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpSessionLog: 100
EOF

cat > $sync_path/sync-ha.ldif << EOF
dn: olcDatabase={2}mdb,cn=config
changetype: modify
add: olcSyncRepl
olcSyncRepl: rid=001
             provider=ldap://$MASTER_IP
             bindmethod=simple
             binddn="cn=root,dc=huawei,dc=com"
             credentials=$ROOT_LDAP_INIT_PASSWD
             searchbase="dc=huawei,dc=com"
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:0
olcSyncrepl: rid=002
             provider=ldap://$SLAVE_IP
             bindmethod=simple
             binddn="cn=root,dc=huawei,dc=com"
             credentials=$ROOT_LDAP_INIT_PASSWD
             searchbase="dc=huawei,dc=com"
             scope=sub
             schemachecking=on
             type=refreshAndPersist
             retry="30 5 300 3"
             interval=00:00:05:00
-
add: olcMirrorMode
olcMirrorMode: TRUE
EOF

	echo "Importing mod_syncprov.ldif..."
	ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/mod_syncprov.ldif
	echo "Importing serverid.ldif..."
	ldapmodify -Y EXTERNAL -H ldapi:/// -f $sync_path/serverid.ldif
	echo "Importing syncprov.ldif..."
	ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/syncprov.ldif
	echo "Importing sync-ha.ldif..."
	ldapadd -Y EXTERNAL -H ldapi:/// -f $sync_path/sync-ha.ldif
	
	chown -R ldap:ldap /etc/openldap/slapd.d/
	
	systemctl restart slapd
	
	echo "View the existing LDAP users."
	ldapsearch -x -D 'cn=root,dc=huawei,dc=com' -w "$ROOT_LDAP_INIT_PASSWD" -b "dc=huawei,dc=com" -H ldap://$IP_ADDR |grep dn
	
	if [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		if [ $NODE_PRI = "master" ];then
			sed -i "/^olcServerID/c olcServerID: 1" /etc/openldap/slapd.d/cn\=config.ldif
		elif [ $NODE_PRI = "slave" ];then
			sed -i "/^olcServerID/c olcServerID: 2" /etc/openldap/slapd.d/cn\=config.ldif
		fi
	fi
}

function failover_conf(){
	echo "ldap failover configuration..."
	yum install keepalived -y
	
	failover_path="/root/fail-over"
	mkdir -p $failover_path
	
cat > $failover_path/slapd_master.sh << EOF
#!/bin/bash
systemctl start slapd.service
EOF

cat > $failover_path/slapd_stop.sh << EOF
#!/bin/bash
systemctl stop slapd.service
EOF

cat > $failover_path/slapd_check.sh << EOF
#!/bin/bash
ldapPid=\$(ps -ef |grep /usr/sbin/slapd|grep -v grep|awk '{print $2}'|grep -v PID)
if [ "\$ldapPid" == "" ]; then
	systemctl stop keepalived.service
	exit 1
else
	exit 0
fi
EOF

	chmod o+x $failover_path/slapd_master.sh
	chmod o+x $failover_path/slapd_stop.sh
	chmod o+x $failover_path/slapd_check.sh
	
	if [ $NODE_PRI = "master" ];then
		state="MASTER"
	elif [ $NODE_PRI = "slave" ];then
		state="BACKUP"
	fi
	
	if [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		rm –f /etc/keepalived/keepalived.conf
	else
	
cat > /etc/keepalived/keepalived.conf << EOF
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
	 $VIRTUAL_MASTER_IP
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

function ssl_integration(){
	local cert_dir="/etc/openldap/certs"
	[ ! -d $cert_dir ] && mkdir $cert_dir
	if [ $IP_ADDR = $MASTER_IP ];then
		echo "SSL integration on the server..."
		echo "Start generating the certificate file."
		
		DOMAIN_NAME=huawei.com
		if [ -n "$NODE_PRI" ];then
			IP_ADD="$VIRTUAL_MASTER_IP"
		else
			IP_ADD=$IP_ADDR
		fi

cat > $cert_dir/my-ssl.conf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = ${DOMAIN_NAME}
IP.1 = ${IP_ADD}
EOF

	openssl genrsa -out $cert_dir/ldap.key 4096
	openssl req -new -sha256 -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=HW/OU=IT/CN=${DOMAIN_NAME}" -out $cert_dir/ldap.csr -key $cert_dir/ldap.key
	openssl x509 -req -days 3650 -in $cert_dir/ldap.csr -signkey $cert_dir/ldap.key -out $cert_dir/ldap.crt -extfile $cert_dir/my-ssl.conf
	openssl x509 -in $cert_dir/ldap.crt -text -noout
	fi

	if [ $NODE_PRI = "slave" ];then
		scp root@$MASTER_IP:$cert_dir/ldap* $cert_dir
	fi
	
	chown ldap:ldap -R $cert_dir
	cp $cert_dir/ldap.crt /share/software/tools/hpc_script/service_script

	echo "adding cert file..."
	sed -i "/^olcTLSCertificateFile/d" /etc/openldap/slapd.d/cn\=config.ldif
	sed -i "/^olcTLSCertificateKeyFile/d" /etc/openldap/slapd.d/cn\=config.ldif
	sed -i "/^olcAllows/d" /etc/openldap/slapd.d/cn\=config.ldif
	
	echo "olcTLSCertificateFile: $cert_dir/ldap.crt" >> /etc/openldap/slapd.d/cn\=config.ldif
	echo "olcTLSCertificateKeyFile: $cert_dir/ldap.key" >> /etc/openldap/slapd.d/cn\=config.ldif
	echo "olcAllows: bind_v2" >> /etc/openldap/slapd.d/cn\=config.ldif
	
	echo "Changing the LDAP Startup Mode..."
	if [ $OS_TYPE = "CentOS" ] || [ $OS_TYPE = "Red Hat Enterprise Linux" ];then
		sed -i "/^SLAPD_URLS=/c SLAPD_URLS=\"ldapi:/// ldaps:///\"" /etc/sysconfig/slapd
	elif [ $OS_TYPE = "Kylin" ] || [ $OS_TYPE = "openEuler" ];then
		sed -i "/^ExecStart=/c ExecStart=/usr/sbin/slapd -u ldap -h \"ldaps:/// ldapi:///\"" /usr/lib/systemd/system/slapd.service
	fi
	
	systemctl restart slapd.service
	netstat -anp | grep 636 | grep slapd
	if [ $? -eq 0 ];then
		echo "The TLS/SSL has been integrated into the service order."
		systemctl daemon-reload
	else
		echo "Failed to integrate TSL/SSL into the service order."
		exit 255
	fi
}

function usage () {
	cat << EOF
Usage:
	e.g.: 
	HA mode: ldap_deploy.sh -m 127.0.0.1 -s 127.0.0.2
	Non HA mode: ldap_deploy.sh 127.0.0.1
		-m		master ip address
		-s		slave ip address
EOF
}

function ldap_service_installation_and_deployment(){
	if [ -n "$MASTER_IP" ] && [ -n "$SLAVE_IP" ] && [ -z "$NODE_PRI" ];then
		ping -c2 -i0.3 -W1 $MASTER_IP
		if [ $? != 0 ];then
			echo "Error: Ping $MASTER_IP failed, The LDAP service installation is terminated."
			exit 255
		fi
		
		ping -c2 -i0.3 -W1 $SLAVE_IP
		if [ $? != 0 ];then
			echo "Error: Ping $SLAVE_IP failed, The LDAP service installation is terminated."
			exit 255
		fi
		
		if [ $IP_ADDR != $MASTER_IP ] && [ $IP_ADDR != $SLAVE_IP ];then
			ssh_command "$MASTER_IP" "export NODE_PRI=master && sh /share/software/tools/hpc_script/service_script/$0" "$ROOT_LOGIN_PW"
			ssh_command "$SLAVE_IP" "export NODE_PRI=slave && sh /share/software/tools/hpc_script/service_script/$0" "$ROOT_LOGIN_PW"
			return 0
		elif [ $IP_ADDR = $MASTER_IP ];then
			export NODE_PRI=master
		elif [ $IP_ADDR = $SLAVE_IP ];then
			export NODE_PRI=slave
		fi
	elif [ -n "$MASTER_IP" ] && [ -z "$SLAVE_IP" ] && [ $IP_ADDR != $MASTER_IP ];then
		ssh_command "$MASTER_IP" "sh /share/software/tools/hpc_script/service_script/$0" "$ROOT_LOGIN_PW"
		exit 0
	fi
	selinux_firewall_check
	deploy_ldap_service
	ldap_database_conf
	ldap_log_conf
	if [ -n "$NODE_PRI" ];then
		master_slave_trust_conf
		failover_conf
	fi
	ssl_integration
}

ldap_service_installation_and_deployment "$@"
exit 0

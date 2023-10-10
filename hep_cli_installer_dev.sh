#!/bin/bash
GREEN='\033[0;32m'
NC='\033[0m'
if [ -n "$(command -v yum)" ];then
echo
cat > /etc/yum.repos.d/qxip_hepic-dev.repo << 'EOF'
[qxip_hepic-dev]
name=qxip_hepic-dev
baseurl=https://0000-0000-0000-rpm:@packagecloud.io/qxip/hepic-dev/rpm_any/rpm_any/$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://0000-0000-0000-rpm:@packagecloud.io/qxip/hepic-dev/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[qxip_hepic-dev-source]
name=qxip_hepic-dev-source
baseurl=https://0000-0000-0000-rpm:@packagecloud.io/qxip/hepic-dev/rpm_any/rpm_any/SRPMS
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://0000-0000-0000-rpm:@packagecloud.io/qxip/hepic-dev/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
yum install -y sudo curl
echo -e "Please insert the provided key to install hep_cli:"
read key
        sed -i "s/0000-0000-0000-rpm/$key/g" /etc/yum.repos.d/qxip_hepic-dev.repo

echo -e "************************************************************"
echo -e "\t ${GREEN} Installing Hepic-Installer a.k.a hep_cli ${NC}\n\t\t"
echo -e "************************************************************"
yum install -y hepic-installer

elif [ -n "$(command -v apt-get)" ];then
apt-get install -y sudo gnupg curl
sudo install -m 0755 -d /etc/apt/keyrings
echo -e "Please insert the provided key to install hep_cli:"
read key
curl -fsSL https://$key:@packagecloud.io/qxip/hepic-dev/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/hepic-dev.gpg
cat > /etc/apt/sources.list.d/qxip_hepic-dev.list << 'EOF'
deb [signed-by=/etc/apt/keyrings/hepic-dev.gpg] https://0000-0000-0000-deb:@packagecloud.io/qxip/hepic-dev/any/ any main
deb-src [signed-by=/etc/apt/keyrings/hepic-dev.gpg] https://0000-0000-0000-deb:@packagecloud.io/qxip/hepic-dev/any/ any main
EOF
sed -i "s/0000-0000-0000-deb/$key/g" /etc/apt/sources.list.d/qxip_hepic-dev.list
echo -n "Running apt-get update... "
apt-get update &> /dev/null
echo "done."


echo -e "************************************************************"
echo -e "\t ${GREEN} Installing Hepic-Installer a.k.a hep_cli ${NC}\n\t\t"
echo -e "************************************************************"
apt-get install -y hepic-installer

fi


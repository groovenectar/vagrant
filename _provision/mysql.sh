#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

echo ">>> Installing MySQL Server"

[[ -z ${1} ]] && { echo "!!! MySQL root password not set. Check the Vagrant file."; exit 1; }

mysql_root_password="${1}"
mysql_enable_remote="${2}"

if [[ -n ${3} ]]; then
	database_name="${3}"
fi

if [[ -n ${4} ]]; then
	database_user="${4}"
fi

if [[ -n ${5} ]]; then
	database_pass="${5}"
fi

if [[ -n ${6} ]]; then
	database_table_prefix="${6}"
fi

if [[ -n ${7} ]]; then
	remote_database_ssh_user="${7}"
fi

if [[ -n ${8} ]]; then
	remote_database_ssh_host="${8}"
fi

if [[ -n ${9} ]]; then
	remote_database_name="${9}"
fi

if [[ -n ${10} ]]; then
	remote_database_user="${10}"
fi

if [[ -n ${11} ]]; then
	remote_database_pass="${11}"
fi

if [[ -n ${12} ]]; then
	remote_database_table_prefix="${12}"
fi

if [[ -n ${13} ]]; then
	synced_folder="${13}"
fi

if [[ -n ${14} ]]; then
	local_http_url="${14}"
fi

if [[ -n ${15} ]]; then
	local_https_url="${15}"
fi

if [[ -n ${16} ]]; then
	mysql_remote_pull_script="${16}"
fi

if [[ -n ${17} ]]; then
	mysql_version="${17}"
fi

if [[ -n ${18} ]]; then
	local_http_url="${18}"
fi

if [[ -n ${19} ]]; then
	local_https_url="${19}"
fi

if [[ -n ${20} ]]; then
	magento="${20}"
fi

if [[ -n ${21} ]]; then
	wordpress="${21}"
fi

# Install MySQL without password prompt
# Set username and password to 'root'
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $1"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $1"

# Install MySQL Server
# -qq implies -y --force-yes
if [ ${mysql_version} == "5.5" ]; then
	sudo apt-get install -qq mysql-server-5.5 mysql-client-5.5 || true
else
	sudo apt-get install -qq mysql-server-5.6 mysql-client-5.6 || true
fi


if [[ -n ${database_name} ]]; then
	echo ">>> Create new database"
	echo "CREATE DATABASE IF NOT EXISTS ${database_name};" | mysql -uroot -p"${mysql_root_password}"
	if [[ "${database_user}" != 'root' ]]; then
		# This creates the user if not exists
		echo "GRANT ALL PRIVILEGES ON ${database_name}.* TO '${database_user}'@'localhost' IDENTIFIED BY '${database_pass}';" | mysql -uroot -p"${mysql_root_password}"
		echo "FLUSH PRIVILEGES;" | mysql -uroot -p"${mysql_root_password}"
	fi
fi

if [[ -n ${remote_database_ssh_user} ]]; then
	# Can't prompt for SSH password during provision
	# ssh "${remote_database_ssh_user}@${remote_database_ssh_host}" mysqldump --single-transaction --user="${remote_database_user}" --password="\"${remote_database_pass}\"" "${remote_database_name}" | mysql -uroot -p"${mysql_root_password}" "${database_name}"
	# So do it on first boot
	script_path="/home/vagrant/mysql_remote_pull.sh"
	link_path="/etc/profile.d/0001_mysql_remote_pull.sh"
	# Make this vagrant user so we can delete the file later without sudo
	sudo chown vagrant:vagrant /etc/profile.d

	if [[ ${mysql_remote_pull_script} =~ '://' ]]; then
		sudo curl --silent -L ${mysql_remote_pull_script} > ${script_path}
	else
		sudo cp ${synced_folder}/${mysql_remote_pull_script} ${script_path}
	fi

	sudo sed -i "s#=\"\${1}#=\"${database_name}#g" ${script_path}
	sudo sed -i "s#=\"\${2}#=\"${database_user}#g" ${script_path}
	sudo sed -i "s#=\"\${3}#=\"${database_pass}#g" ${script_path}
	sudo sed -i "s#=\"\${4}#=\"${database_table_prefix}#g" ${script_path}
	sudo sed -i "s#=\"\${5}#=\"${remote_database_ssh_user}#g" ${script_path}
	sudo sed -i "s#=\"\${6}#=\"${remote_database_ssh_host}#g" ${script_path}
	sudo sed -i "s#=\"\${7}#=\"${remote_database_name}#g" ${script_path}
	sudo sed -i "s#=\"\${8}#=\"${remote_database_user}#g" ${script_path}
	sudo sed -i "s#=\"\${9}#=\"${remote_database_pass}#g" ${script_path}
	sudo sed -i "s#=\"\${10}#=\"${remote_database_table_prefix}#g" ${script_path}
	sudo sed -i "s#=\"\${11}#=\"${local_http_url}#g" ${script_path}
	sudo sed -i "s#=\"\${12}#=\"${local_https_url}#g" ${script_path}
	sudo sed -i "s#=\"\${13}#=\"${magento}#g" ${script_path}

	# Prompt to delete from startup
	printf "\nif [[ \$- == *i* ]] ; then echo; read -p \"Finished. Remove from startup? \" -n 1 -r; if [[ \$REPLY =~ ^[Yy]$ ]]; then rm ${link_path}; fi; echo; echo; fi;" | sudo tee -a ${script_path}

	# Allow vagrant user to delete it
	sudo chmod u+x ${script_path}
	sudo chown vagrant:vagrant ${script_path}
	sudo ln -s ${script_path} ${link_path}
	sudo chown -h vagrant:vagrant ${link_path}
fi

# Make MySQL connectable from outside world without SSH tunnel
if [ ${mysql_enable_remote} == "true" ]; then
	# enable remote access
	# setting the mysql bind-address to allow connections from everywhere
	sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

	# adding grant privileges to mysql root user from everywhere
	# thx to http://stackoverflow.com/questions/7528967/how-to-grant-mysql-privileges-in-a-bash-script for this
	MYSQL=`which mysql`

	Q1="GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$1' WITH GRANT OPTION;"
	Q2="FLUSH PRIVILEGES;"
	SQL="${Q1}${Q2}"

	$MYSQL -uroot -p$1 -e "$SQL"

	service mysql restart
fi

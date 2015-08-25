#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

echo "Setting Timezone & Locale to $2 & C.UTF-8"
sudo timedatectl set-timezone $2

# Update
sudo apt-get update

# Install base packages
# -qq implies -y --force-yes
sudo apt-get install -qq curl unzip git-core ack-grep software-properties-common build-essential

# Disable case sensitivity
sudo shopt -s nocasematch

if [[ ! -z $1 && ! $1 =~ false && $1 =~ ^[0-9]*$ ]]; then
	echo ">>> Setting up Swap ($1 MB)"

	# Create the Swap file
	sudo fallocate -l $1M /swapfile

	# Set the correct Swap permissions
	sudo chmod 600 /swapfile

	# Setup Swap space
	sudo mkswap /swapfile

	# Enable Swap space
	sudo swapon /swapfile

	# Make the Swap file permanent
	echo "/swapfile   none    swap    sw    0   0" | tee -a /etc/fstab

	# Add some swap settings:
	# vm.swappiness=10: Means that there wont be a Swap file until memory hits 90% useage
	# vm.vfs_cache_pressure=50: read http://rudd-o.com/linux-and-free-software/tales-from-responsivenessland-why-linux-feels-slow-and-how-to-fix-that
	sudo printf "vm.swappiness=10\nvm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf && sysctl -p
fi

# Enable case sensitivity
sudo shopt -u nocasematch

echo ">>> Setting up ll alias"
echo "alias ll='ls -la'" >> /home/vagrant/.bash_aliases
echo "alias sudo='sudo '" >> /home/vagrant/.bash_aliases
source /home/vagrant/.bash_aliases

# echo ">>> Installing Screen"
# -qq implies -y --force-yes
# sudo apt-get install -qq screen
# sudo touch /home/vagrant/.screenrc
# sudo echo -e "startup_message off\ncaption always '%{= dg} %H %{G}%=%?%{d}%-w%?%{r}(%{d}%n %t%? {%u} %?%{r})%{d}%?%+w%?%=%{G} %{B}%M %d %c:%s '" >> /home/vagrant/.screenrc
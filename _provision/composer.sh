#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Test if PHP is installed
php -v > /dev/null 2>&1
PHP_IS_INSTALLED=$?

# Test if HHVM is installed
hhvm --version > /dev/null 2>&1
HHVM_IS_INSTALLED=$?

[[ $HHVM_IS_INSTALLED -ne 0 && $PHP_IS_INSTALLED -ne 0 ]] && { printf "!!! PHP/HHVM is not installed.\n    Installing Composer aborted!\n"; exit 0; }

# Test if Composer is installed
composer -v > /dev/null 2>&1
COMPOSER_IS_INSTALLED=$?

# True, if composer is not installed
if [[ $COMPOSER_IS_INSTALLED -ne 0 ]]; then
	echo ">>> Installing Composer"
	if [[ $HHVM_IS_INSTALLED -eq 0 ]]; then
		# Install Composer
		sudo wget --quiet https://getcomposer.org/installer
		hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 installer
		sudo mv composer.phar /usr/local/bin/composer
		sudo rm installer

		# Add an alias that will allow us to use composer without timeout's
		printf "\n# Add an alias for sudo\n%s\n# Use HHVM when using Composer\n%s" \
		"alias sudo=\"sudo \"" \
		"alias composer=\"hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 -v Eval.Jit=false /usr/local/bin/composer\"" \
		>> "/home/vagrant/.profile"

		# Resource .profile
		# Doesn't seem to work do! The alias is only usefull from the moment you log in: vagrant ssh
		. /home/vagrant/.profile
	else
		# Install Composer
		curl -sS https://getcomposer.org/installer | php
		sudo mv composer.phar /usr/local/bin/composer
	fi
else
	echo ">>> Updating Composer"

	if [[ $HHVM_IS_INSTALLED -eq 0 ]]; then
		sudo hhvm -v ResourceLimit.SocketDefaultTimeout=30 -v Http.SlowQueryThreshold=30000 -v Eval.Jit=false /usr/local/bin/composer self-update
	else
		sudo composer self-update
	fi
fi

#!/usr/bin/env bash
set -e
modules="\
      puppetlabs-apt \
      puppetlabs-postgresql \
      puppetlabs-stdlib  \
      puppetlabs-vcsrepo  \
      ripienaar-concat \
      stankevich-python \
      "

if [ "$EUID" -ne "0" ] ; then
        echo "Script must be run as root." >&2
        exit 1
fi

if ! which puppet > /dev/null ; then
        echo "Puppet is NOT installed. Installing"
        sudo apt-get install --assume-yes puppet
fi
 
echo "Installing Puppet modules"
mkdir -p /etc/puppet/modules;

for module in $modules; do
    #sudo puppet module install --force $module
    #sudo puppet module install $module 2>/dev/null || echo "$module: seems to be already installed :)"
    sudo puppet module install $module || echo "ERROR: Epa, parece q algo no anduvo bien aca. Ya instalado tal vez?" >&2 
done

echo "Puppet modules installed"


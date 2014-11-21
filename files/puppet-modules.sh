#!/usr/bin/env bash
set -e
modules="\
      puppetlabs-apt \
      puppetlabs-mongodb \
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
        echo "Puppet is NOT installed. Aborting"
        exit 1
fi
 
echo "Installing Puppet modules"
mkdir -p /etc/puppet/modules;


for module in $modules; do
    #sudo puppet module install --force $module
    sudo puppet module install $module 2>/dev/null || echo "$module: seems to be already installed :)"
done

echo "Puppet modules installed"


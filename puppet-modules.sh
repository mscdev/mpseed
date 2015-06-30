#!/usr/bin/env bash
set -e
modules="\
puppetlabs-apt 1.8.0:\
puppetlabs-concat 1.2.3:\
puppetlabs-postgresql 4.3.0:\
puppetlabs-stdlib 4.6.0:\
puppetlabs-vcsrepo 1.3.0:\
stankevich-python 1.9.4"

if [ "$EUID" -ne "0" ] ; then
        echo "Script must be run as root." >&2
        exit 1
fi

if ! which puppet > /dev/null ; then
        echo "Puppet is NOT installed. Installing"
        sudo apt-get install --assume-yes puppet
echo
        echo "Puppet already present"
fi
 
echo "Installing Puppet modules"
mkdir -p /etc/puppet/modules;

IFS=":"
for module in $modules; do
    name=$(echo $module | cut -d " " -f 1)
    ver=$(echo $module | cut -d " " -f 2)
    #sudo puppet module install --force $module
    #sudo puppet module install $module 2>/dev/null || echo "$module: seems to be already installed :)"
    sudo puppet module install $name --version $ver || echo "ERROR: Epa, parece q algo no anduvo bien aca. Ya instalado tal vez?" >&2 
done

echo "Puppet modules installed"

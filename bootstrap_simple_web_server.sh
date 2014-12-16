#!/usr/bin/env bash
WWW_USER=vagrant

apt-get update
apt-get install -y apache2
if ! [ -L /var/www ]; then
  chown -R vagrant /var/www
  #rm -rf /var/www
  #ln -fs /vagrant /var/www
fi

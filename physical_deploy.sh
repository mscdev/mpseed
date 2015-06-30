# sudo su mkdir /repo   
# sudo chmod 777 /repo   
sudo /repo/mpseed/puppet-modules.sh

# Just to fix locale problems
#sudo locale-gen de_DE.UTF-8 

sudo FACTER_PROJECTID=vtfx puppet apply --debug /repo/mpseed/manifests/main.pp
# Fix puppet postgres problem
#sudo mkdir -p /var/lib/postgresql/9.3/main 
sudo pg_createcluster 9.3 main --start


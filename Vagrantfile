# -*- mode: ruby -*-
# vi: set ft=ruby :
useDevOptions = "_development.mode"
if File.exist?(useDevOptions)
    puts "INFO: Development settings"
    production_mode=false
else
    puts "INFO: Production settings"
    production_mode=true
end
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.provider :virtualbox do |vb| 
        if production_mode == false
            vb.gui = true # Don't boot with headless mode
        end
        # Use VBoxManage to customize the VM
        vb.customize ["modifyvm", :id, "--memory", "768"]
    end

    config.vm.define "main", primary: true do |replicator|
        replicator.vm.box = "ubuntu/trusty64"
        replicator.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
        config.vm.provider :virtualbox do |vb| 
            vb.customize ["modifyvm", :id, "--memory", "2000"]
            vb.customize ["modifyvm", :id, "--ioapic", "on"]
            vb.customize ["modifyvm", :id, "--cpus", "2"]
            #vb.memory = 2048
            #vb.cpus = 2
        end

        replicator.vm.hostname="vtfx.dev.mainstorconcept.de"

        if production_mode == true
            ARGV.delete_at(1)
            config.vm.network :public_network, ip: "172.20.1.20"

            # IP address of your LAN's router
            default_router = "172.20.1.254"

            # change/ensure the default route via the local network's WAN router, 
            # useful for public_network/bridged mode
            config.vm.provision :shell, :inline => "echo 'Network POSCONFIG'; ip route delete default || true; ip route add default via #{default_router}"
            #config.vm.provision :shell, :inline => "echo 'Network POSCONFIG'; ip route delete default 2>&1 >/dev/null || true; ip route add default via #{default_router}"

        else
            replicator.vm.network :private_network, ip: "192.168.55.20"
            replicator.vm.network :forwarded_port, guest: 80, host: 8080
        end


        replicator.vm.provision :shell, :path => "puppet-install.sh"
        replicator.vm.provision :shell, :path => "puppet-modules.sh"

        replicator.vm.provision :puppet do |puppet|
            puppet.manifests_path = "manifests"
            puppet.manifest_file  = "site.pp"
        end
    end 

    if production_mode == false
        config.vm.define "vte1" do |vte1|
            vte1.vm.box = "suse/sless11"
            vte1.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/sles-11sp1-x64-vbox4210.box" 

            vte1.vm.hostname="source.mainstorconcept.de"
            vte1.vm.network :private_network, ip: "192.168.55.31"
        end 
        config.vm.define "vte2" do |vte2|
            vte2.vm.box = "suse/sless11"
            vte2.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/sles-11sp1-x64-vbox4210.box" 

            vte2.vm.hostname="destination.mainstorconcept.de"
            vte2.vm.network :private_network, ip: "192.168.55.32"
            #vte2.vm.provision :shell, :path => "vte-provision.sh"
        end 
    end 
end

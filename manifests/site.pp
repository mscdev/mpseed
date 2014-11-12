Exec { path => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' }

# Global variables
$inc_file_path = '/vagrant/files' # Absolute path to the files directory 

$user = 'user' # User to create
$password = 'abcdef1' # The user's password

$project = 'vtfx' # Used in nginx and uwsgi
$domain_name = 'vtfx.mainstorconcept.de' # Used in nginx, uwsgi and virtualenv directory
$db_name = 'vtfx' # Mysql database name to create
$db_user = 'vtfx' # Mysql username to create
$db_password = 'vtfx' # Mysql password for $db_user

$tz = 'Europe/Berlin' # Timezone

include users
include paquetes
include database
include app_sources
include virtualenv
include app_deploy

include nginx
include uwsgi
include timezone
include extra_software


class { 'python':
    dev        => true, # install python-dev
    pip        => true,
    version    => 'system',
    virtualenv => true,
}

class { 'apt':
  always_apt_update    => true,
}
Class['apt'] -> Class['python']      
Class['apt'] -> Class['paquetes']      
Class['apt'] -> Class['database']      
Class['apt'] -> Class['app_sources']   
Class['apt'] -> Class['virtualenv']    
Class['apt'] -> Class['app_deploy']    
Class['apt'] -> Class['nginx']         
Class['apt'] -> Class['uwsgi']         
Class['apt'] -> Class['timezone']      
Class['apt'] -> Class['extra_software']


class users {
    group { 'www-data':
        ensure => present,
    }

    user { 'www-data':
        ensure => present,
        groups => ['www-data'],
        membership => minimum,
        shell => "/bin/bash",
        require => Group['www-data']
    }

    user { $user:
      ensure     => "present",
      managehome => true,
      shell => "/bin/bash",
      password => '$6$AmBNh8J7nMlCZcl$kiCaNL0ex.7Oab13v1jJy5QFzdd95KjSIhNgkubjLGQhkajUC0Uw2u6pXJ.t5c9oirHctq2MmZDlEIy3P3cgt0',
      groups => ['sudo', 'admin', 'vagrant'],
    }

    # SSH Keys
    file { "/home/$user/.ssh":
        ensure => "directory",
        owner  => "$user",
        group  => "$user",
        mode   => 777,
    }
    file { "/home/$user/.ssh/id_rsa.pub":
        ensure => present,
        owner  => "$user",
        group  => "$user",
        mode => '0600',
        source =>"${inc_file_path}/ssh/id_rsa.pub",
    }
    file { "/home/$user/.ssh/id_rsa":
        ensure => present,
        owner  => "$user",
        group  => "$user",
        mode => '0600',
        source =>"${inc_file_path}/ssh/id_rsa",
    }

    file { "/home/$user/.bash_aliases":
        ensure => "file",
        owner  => "$user",
        group  => "$user",
        content  => "alias wd='cd /var/www/$project/repo; source /var/www/$project/env/bin/activate'
                   \nalias run='/var/www/$project/repo/webapp/manage.py runserver 0.0.0.0:8888'
                   \nalias pp='sudo puppet apply /vagrant/manifests/replicator.pp'",
        mode   => 755,
    }
    file { "/home/vagrant/.bash_aliases":
        ensure => "file",
        owner  => "vagrant",
        group  => "vagrant",
        content  => "alias pp='sudo puppet apply /vagrant/manifests/site.pp'",
        mode   => 755,
    }
}

class virtualenv {
    python::virtualenv { "/var/www/${project}/env":
    ensure       => present,
    version      => 'system',
    requirements => "/var/www/${project}/repo/webapp/requirements.txt",
    #proxy        => 'http://proxy.domain.com:3128',
    #systempkgs   => true,
    distribute   => false,
    owner        => "$user",
    group        => "$user",
    #cwd          => '/var/www/virtualenvs/${project}',
    timeout      => 100,
    require => [Class['app_sources'], Class['database']],
    before => Class['app_deploy'],
    }
}

class paquetes {

    $vcs = [ 'git',  ]
    package { $vcs: ensure => latest }

    package { 'fabric':
        ensure => latest,
        provider => pip,
        require => Package['python-pip']
    }
}

class app_sources {
    $dirs = [ "/var/www", 
              "/var/www/${project}",
              "/var/www/${project}/media", 
              "/var/www/${project}/static", 
#              "/var/www/${project}/env",
]

    file { $dirs:
        ensure => "directory",
        owner  => "$user",
        group  => "$user",
        mode   => 755,
    }

    file { "/var/www/${project}/static": 
        mode => 777,
    }

    file { "/etc/puppet/hiera.yaml":
         ensure => "present",
    }

    file { "/var/www/${project}/repo/":
        ensure => link,
        target => '/repo/',
    } 
    #vcsrepo { "/var/www/${project}/repo":
    #    #ensure => present,
    #    ensure => latest,
    #    provider => git,
    #    source => "git://redmine.mainstorconcept.de/vtfx-II.git",
    #    revision => 'master',
    #    user => "$user",
    #    require => Package['git']
    #}
}

class app_deploy {
    exec { "fab deploy:host=vagrant@localhost --password=vagrant":
        #cwd     => "/var/www/${project}/repo/webapp",
        cwd     => "/vtfx",
        provider=> shell,
        logoutput => true,
        #path    => ["/usr/bin", "/usr/sbin"]
    }

}

class database {
    $postgres = [ 'postgresql', 'libpq-dev', ]
    package { $postgres: ensure => latest }

    class { 'postgresql::server':
        ip_mask_deny_postgres_user => '0.0.0.0/32',
        ip_mask_allow_all_users    => '0.0.0.0/0',
        listen_addresses           => '*',
        #ipv4acls                   => ['hostssl all johndoe 192.168.0.0/24 cert'],
        #manage_firewall            => true,
        postgres_password          => 'postgres',
    }

    postgresql::server::db { $db_name:
        user     => $db_user,
        password => postgresql_password($db_user, $db_password),
    }
}


class uwsgi {
    package { ['uwsgi', 'uwsgi-plugin-python']:
        ensure => installed,
        require => Class['paquetes'],
    }
    file { '/etc/uwsgi/apps-available/vtfx.ini':
        ensure => present,
        owner => 'root',
        group => 'root',
        mode => '0644',
        source =>"${inc_file_path}/uwsgi/vtfx.ini",
        require => Package['uwsgi'],
    }
    file { '/etc/uwsgi/apps-enabled/vtfx.ini':
        ensure => link,
        target => '/etc/uwsgi/apps-available/vtfx.ini',
        require => Package['uwsgi'],
    } 
    service { 'uwsgi':
        ensure => running,
        provider => upstart,
        enable => true,
        hasrestart => false,
        hasstatus => false,
        require => [ File['/etc/uwsgi/apps-enabled/vtfx.ini'], Class['virtualenv'] ],
        subscribe => File['/etc/uwsgi/apps-available/vtfx.ini'],
    }
}

class nginx {
    package { 'nginx':
        ensure => present,
        require => Class['paquetes'],
    }
    file { '/etc/nginx/sites-available/vtfx':
        ensure => file,
        owner => 'root',
        group => 'root',
        mode => '640',
        source =>"${inc_file_path}/nginx/vtfx",
        #content => template("${inc_file_path}/nginx/vtfx.erb"),
        require => Package['nginx'],
    }
    # Disable default config
    file { '/etc/nginx/sites-enabled/default':
        ensure => absent,
        require => Package['nginx'],
    } 
    file { '/etc/nginx/sites-enabled/vtfx':
        ensure => link,
        target => '/etc/nginx/sites-available/vtfx',
        require => Package['nginx'],
    } 
    service { 'nginx':
        ensure => running,
        enable => true,
        hasstatus => true,
        hasrestart => true,
        subscribe => File['/etc/nginx/sites-available/vtfx'],
    }
}


class timezone {
  package { "tzdata":
    ensure => latest,
  }

  file { "/etc/localtime":
    require => Package["tzdata"],
    source => "file:///usr/share/zoneinfo/${tz}",
  }
}

class extra_software {
  package { 'vim':
    ensure => latest,
  }
}

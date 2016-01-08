Exec { path => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' }


$user = 'admin' # User to create
$password = 'abcdef1' # The user's password
$password_hash = '$6$AmBNh8J7nMlCZcl$kiCaNL0ex.7Oab13v1jJy5QFzdd95KjSIhNgkubjLGQhkajUC0Uw2u6pXJ.t5c9oirHctq2MmZDlEIy3P3cgt0'

if $projectid == undef {
    fail("Sorry man, you suck: 'projectid fact not defined'")
}
$project = "${projectid}" 

$pip_requirements_file = "requirements.txt"

if $internet == 'false' {
    if $version_dir == undef {
      fail("Sorry man, you suck: 'version fact not defined' and internet fact == 'false'")
    }
    notice("Trying to run puppet without internet connection")
    #$project_path="${version_dir}"
    $pip_packages_path = "${version_dir}/requirements/pip"
    $package_version = 'present'
    #$apt_update = false
    $extra_pip_args = "--upgrade --no-index --find-links ${pip_packages_path}"

    exec {'apt-update': 
      command => "${version_dir}/repo/install_deb_pkgs_no_internet.sh ${version_dir}/requirements/deb"
    }
}
else {
    notice("Running puppet with internet connection")
    #$project_path = "/var/www/${project}"
    exec { "apt-update":
        command => "/usr/bin/apt-get update"
    }
    $package_version = 'latest'
    #$apt_update = true
    $extra_pip_args = '--upgrade'
}

Exec["apt-update"] -> Package <| |>

# Global variables
$project_path = "/var/www/${project}" # Base dir
$repo_path = "${project_path}/repo" # Git repo (or repository 'snapshot')
$mpseed_path = "${repo_path}/mpseed" # MPSEED sources
$inc_file_path = "${mpseed_path}/files" # Include files for this puppet manifest

# Database
$db_name = "${project}" # Mysql database name to create
$db_user = "${project}" # Mysql username to create
$db_password = "${project}" # Mysql password for $db_user

# Environment
$domain_name = "${project}.mainstorconcept.de" # Used in nginx, uwsgi and virtualenv directory
$tz = 'Europe/Berlin' # Timezone
$alias_run_puppet="alias pp='sudo FACTER_PROJECTID=${project} FACTER_UNMODIFY_DB=False puppet apply --debug ${mpseed_path}/manifests/main.pp'"
$alias_run_puppet_extras="alias ppe='sudo FACTER_PROJECTID=${project} FACTER_UNMODIFY_DB=False puppet apply --debug ${repo_path}/puppet_extras.pp'"
$alias_flower="alias flower='(cd /var/www/vtfx/repo/webapp && /var/www/vtfx/env/bin/celery --app=vtfx.celery:app flower)'"
$fabric_local_deploy="fab deploy:host=${user}@localhost --password=${password} --fabfile=${repo_path}/fabfile.py"

include users
include paquetes
include database
include app_sources
include virtualenv
include app_deploy
include nginx
include uwsgi
include timezone

#Class['apt']      -> Class['python']
#Class['apt']      -> Class['paquetes']      
#Class['python']   -> Class['virtualenv']
#Class['paquetes'] -> Class['timezone']      
#Class['paquetes'] -> Class['database']      
#Class['paquetes'] -> Class['app_sources']   
#Class['paquetes'] -> Class['nginx']         
#Class['virtualenv'] -> Class['uwsgi']         
#Class['uwsgi']    -> Class['app_deploy']    
#
#class { 'apt':
#  always_apt_update    => $apt_update,
#}



class { 'python':
    dev        => true, # install python-dev
    pip        => true,
    version    => 'system',
    virtualenv => true,
}

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
      password => $password_hash,
      groups => ['sudo',] # 'vagrant'], On bare matal there is no vagrant
    }
    file { "/home/$user/.bash_aliases":
        ensure => "file",
        owner  => "$user",
        group  => "$user",
        content  => "alias wd='cd ${repo_path}; source ${project_path}/env/bin/activate'
                   \nalias run='${repo_path}/webapp/manage.py runserver 0.0.0.0:8888'
                   \nalias ff='${fabric_local_deploy}'
                   \n${alias_run_puppet}
                   \n${alias_run_puppet_extras}
                   \n${alias_flower}",
        mode   => 755,
    }

    # NO VAGRANT on barematal machines
    ## Be nice with vagrant user too
    #file { "/home/vagrant/.bash_aliases":
    #    ensure => "file",
    #    owner  => "vagrant",
    #    group  => "vagrant",
    #    content  => "${alias_run_puppet}
    #               \n${alias_run_puppet_extras}",
    #    mode   => 755,
    #}
}


class virtualenv {
    python::virtualenv { "${project_path}/env":
        ensure       => present,
        version      => 'system',
        distribute   => false,
        owner        => "www-data",
        group        => "$user",
        require => [Class['app_sources'], Class['database']],
        before => Class['app_deploy'],
        extra_pip_args  => $extra_pip_args,
    } ->
    python::requirements { "${repo_path}/webapp/${pip_requirements_file}" :
        virtualenv => "${project_path}/env",
        owner      => "www-data",
        group      => "$user",
        forceupdate => true,
        extra_pip_args => $extra_pip_args,
    }
}

class paquetes {
    $essentials = [ 'git', 'ifenslave', 'vim', 'ipython', 'screen', 'httpie', 'zip', 'unzip', 'ntp']
    package { $essentials: ensure => $package_version }

    package { ['fabric==1.8.1', 'pycrypto', 'ecdsa']:
        ensure => present,
        provider => pip,
        require => [ Package['python-pip'], Package['python-dev'] ]
    }
}

class app_sources {
    $dirs = [ "/var/www", 
              "${project_path}",
#              "${project_path}/env",
] 
    file { $dirs:
        ensure => "directory",
        owner  => "$user",
        group  => "$user",
        mode   => 755,
    }
    file { ["${project_path}/static",
            "${project_path}/media",]: 
        ensure => "directory",
        mode => 777,
    }
    file { "/etc/puppet/hiera.yaml":
         ensure => "present",
    }
    # Default to play nice with vagrant and with first install
    #file { "${repo_path}/":
    #    ensure => link,
    #    target => '/repo/',
    #} 
    file { "/var/log/${project}":
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'admin',
        mode   => 775
    } 
}

class app_deploy {
    exec {$fabric_local_deploy:
        provider  => shell,
        logoutput => true,
        timeout   => 0, 
        #path     => ["/usr/bin", "/usr/sbin"]
        require => [ Class['virtualenv'], Class['uwsgi'], Class['nginx'] ]
    }
    file { "/etc/sudoers.d/20-update":
        content => "
            Defaults!/usr/bin/puppet env_keep+=FACTER_PROJECTID
            Defaults!/usr/bin/puppet env_keep+=FACTER_INTERNET
            www-data ALL=(ALL) NOPASSWD:/usr/bin/puppet apply *
        ",
    }
}

class database {
    if $unmodify_db == undef or $unmodify_db != 'True' {
        $postgres = [ 'postgresql', 'libpq-dev', ]
        package { $postgres: ensure => $package_version }

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
        cron { 'postgres vacuuming':
            command => "/usr/bin/vacuumdb --all --analyze --verbose > /tmp/postgres_vacuum_analyze.log 2>&1",
            user    => 'postgres',
            minute  => '1',
            hour  => '5',
        }
    }
}

class uwsgi {
    package { ['uwsgi', 'uwsgi-plugin-python']:
        ensure => present,
        #  require => Class['paquetes'],
    }
    file { "/etc/uwsgi/apps-available/${project}.ini":
        ensure => present,
        owner => 'root',
        group => 'root',
        mode => '0644',
        content => template("${inc_file_path}/uwsgi/main.erb"),
        #source =>"${inc_file_path}/uwsgi/main.ini",
        require => Package['uwsgi'],
    }
    file { "/etc/uwsgi/apps-enabled/${project}.ini":
        ensure => link,
        target => "/etc/uwsgi/apps-available/${project}.ini",
        require => Package['uwsgi'],
    }
    file { "/var/log/uwsgi/${project}-req.log":
        ensure => present,
        owner => 'www-data',
        group => 'www-data',
        mode => '0640',
        require => Package['uwsgi'],
    }
    file { "/var/log/uwsgi/${project}-err.log":
        ensure => present,
        owner => 'www-data',
        group => 'www-data',
        mode => '0640',
        require => Package['uwsgi'],
    }
    service { 'uwsgi':
        ensure => running,
        provider => upstart,
        enable => true,
        hasrestart => false,
        hasstatus => false,
        require => [ File["/etc/uwsgi/apps-enabled/${project}.ini"], Class['virtualenv'] ],
        subscribe => File["/etc/uwsgi/apps-available/${project}.ini"],
    }
}

class nginx {
    package { 'nginx':
        ensure => present,
        #require => Class['paquetes'],
    }
    file { "/etc/nginx/sites-available/${project}":
        ensure => file,
        owner => 'root',
        group => 'root',
        mode => '640',
        #source =>"${inc_file_path}/nginx/${project}",
        content => template("${inc_file_path}/nginx/main.erb"),
        require => Package['nginx'],
    }
    # Disable default config
    file { "/etc/nginx/sites-enabled/default":
        ensure => absent,
        require => Package['nginx'],
    } 
    file { "/etc/nginx/sites-enabled/${project}":
        ensure => link,
        target => "/etc/nginx/sites-available/${project}",
        require => Package['nginx'],
    } 
    file { "/etc/nginx/locations.d":
        ensure => directory,
        owner => 'root',
        group => 'root',
        mode => '755',
        require => Package['nginx'],
    }
    service { 'nginx':
        ensure => running,
        enable => true,
        hasstatus => true,
        hasrestart => true,
        subscribe => File["/etc/nginx/sites-available/${project}"],
    }
}

class timezone {
  package { "tzdata":
    ensure => $package_version,
  }
  file { "/etc/localtime":
    require => Package["tzdata"],
    source => "file:///usr/share/zoneinfo/${tz}",
  }
}

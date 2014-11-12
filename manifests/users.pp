# requires packages whois
# $chotipass = 'abcdef1'
# password => generate('/bin/sh', '-c', "mkpasswd -m sha-512 ${chotipass} | tr -d '\n'")
# abcdef1='$6$AmBNh8J7nMlCZcl$kiCaNL0ex.7Oab13v1jJy5QFzdd95KjSIhNgkubjLGQhkajUC0Uw2u6pXJ.t5c9oirHctq2MmZDlEIy3P3cgt0'


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

    user { 'user':
      ensure     => "present",
      managehome => true,
      password => '$6$AmBNh8J7nMlCZcl$kiCaNL0ex.7Oab13v1jJy5QFzdd95KjSIhNgkubjLGQhkajUC0Uw2u6pXJ.t5c9oirHctq2MmZDlEIy3P3cgt0',
    }
}

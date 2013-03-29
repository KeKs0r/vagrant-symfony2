file { "/etc/apt/sources.list.d/squeeze-backports.list":
    ensure  => file,
    owner   => root,
    group   => root,
    content => "deb http://backports.debian.org/debian-backports squeeze-backports main",
}


exec { "import-gpg":
    command => "/usr/bin/wget -q http://www.dotdeb.org/dotdeb.gpg -O -| /usr/bin/apt-key add -"
}

exec { "/usr/bin/apt-get update":
    require => [File["/etc/apt/sources.list.d/squeeze-backports.list"], Exec["import-gpg"]],
}



class { "system": }

file { "/etc/motd":
    ensure  => file,
    mode    => "0644",
    owner   => "root",
    group   => "root",
    content => template("system/motd.erb"),
}

            system::package { "build-essential": }
                system::package { "curl": }
                system::package { "git-core": }
                system::package { "vim": }
                system::package { "yui-compressor": }
    
system::config { "bashrc":
    name   => ".bashrc",
    source => "/vagrant/files/system/bashrc",
}


class { "apache": }

class { "apache::mod::php":
    require => Package["php5"]
}


apache::mod { "rewrite": }
apache::mod { "headers": }

apache::vhost { "dev.local":
    priority    => "50",
    vhost_name  => "*",
    port        => "80",
    docroot     => "/var/www/vhosts/dev.local/",
    serveradmin => "admin@dev.local",
    template    => "system/apache-default-vhost.erb",
    override    => "All",
}

file { "phpmyadmin-vhost-creation":
    path    => "/etc/apache2/sites-enabled/phpmyadmin.conf",
    ensure  => "/vagrant/files/apache/sites-enabled/phpmyadmin.conf",
    require => [Package["php5"], Package["apache2"]],
    owner   => "root",
    group   => "root",
}


class { "mysql":
    root_password => "",
    require       => Exec["apt-update"],
}


class { "php": }

file { "php5-ini-apache2-config":
    path    => "/etc/php5/apache2/php.ini",
    ensure  => "/vagrant/files/php/php.ini",
    require => Package["php5"],
}

file { "php5-ini-cli-config":
    path    => "/etc/php5/cli/php.ini",
    ensure  => "/vagrant/files/php/php-cli.ini",
    require => Package["php5"],
}

php::module { "common": }
php::module { "dev": }

    php::module { "mysql": }
    php::module { "intl": }
    php::module { "cli": }
    php::module { "imagick": }
    php::module { "gd": }
    php::module { "xsl": }
    php::module { "mcrypt": }
    php::module { "curl": }
    php::module { "xdebug": }
    php::module { "imap": }
    php::module { "apc":
      module_prefix => "php-",
#      module_prefix => "php5-",
    }
    php::module { "sqlite": }

class { "pear": }

pear::package { "PEAR": }
pear::package { "PHPUnit": }

# pear::channel { "phpunit":
#     url => "pear.phpunit.de",
# }
# 
# pear::channel { "symfony2":
#     url     => "pear.symfony.com",
#     require => Exec["pear-channel-phpunit"],
# }
# 
# pear::channel { "symfony1":
#     url     => "pear.symfony-project.com",
#     require => Exec["pear-channel-symfony2"],
# }
# 
# pear::channel { "components":
#     url     => "components.ez.no",
#     require => Exec["pear-channel-symfony1"],
# }

system::package { "phpmyadmin":
    require => Package["php5"]
}


class { "ruby":
    gems_version  => "latest"
}

system::package { "libsqlite3-dev":
    require => Package["ruby"],
}

#exec { "capifony-install":
#    command => "gem install -q --no-verbose --no-ri --no-rdoc capifony",
#    path    => "/bin:/usr/bin",
#    require => [
#        Package["ruby"],
#        Package["libsqlite3-dev"],
#    ],
#}

# Change user / group
#exec { "UsergroupChange" :
#    command => "sed -i 's/User apache/User vagrant/ ; s/Group apache/Group vagrant/' /etc/httpd/conf/httpd.conf",
#    onlyif  => "grep -c 'User apache' /etc/httpd/conf/httpd.conf",
#    require => Package["apache"],
#    notify  => Service['apache'],
#}

file { "/var/www/vhosts/dev.local/app/cache" :
#    owner  => "root",
#    group  => "vagrant",
    mode   => 0777,
    require => Package["php"],
}



class { "composer":
    command_name => "composer",
    target_dir   => "/usr/local/bin",
    auto_update  => true
}


system::package { "zsh": }
#
exec { "oh-my-zsh-install":
    command => "git clone https://github.com/robbyrussell/oh-my-zsh.git /home/vagrant/.oh-my-zsh",
    path    => "/bin:/usr/bin",
    require => Package["zsh"],
}

exec { "default-zsh-shell":
    command => "chsh -s /usr/bin/zsh vagrant",
    unless  => "grep -E \"^vagrant.+:/usr/bin/zsh$\" /etc/passwd",
    require => Package["zsh"],
    path    => "/bin:/usr/bin",
}

file { "zshrc-file-creation":
    path    => "/home/vagrant/.zshrc",
    ensure  => "/vagrant/files/.zshrc",
   require => Exec["oh-my-zsh-install"],
   owner   => "vagrant",
    group   => "vagrant",
    replace => false,
}


# Create our initial db
    exec { "database_create" :
        command => "/usr/bin/php /var/www/vhosts/dev.local/app/console doctrine:database:create || true",
        require => [ Service["mysql"] ],
    }
	
	exec { "schema_create" :
        command => "/usr/bin/php /var/www/vhosts/dev.local/app/console doctrine:schema:create || true",
        require => [ Service["mysql"], Exec["database_create"] ],
    }

    exec { "fixture_load" :
        command => "/usr/bin/php /var/www/vhosts/dev.local/app/console doctrine:fixtures:load --no-interaction || true",
        require => Exec["schema_create"],
    }

class { "solr":
  install => "source",
  install_source => "http://www.apache.org/dist/lucene/solr/4.2.0/solr-4.2.0.tgz",
}

file { "solrconfig.xml":
    path    => "/etc/solr/conf/solrconfig.xml",
    ensure  => "/vagrant/files/solr/conf/solrconfig.xml",
    require => Package["solr"],
}


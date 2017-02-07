# == Class: duo_unix::pam
#
# Provides duo_unix functionality for SSH via PAM
#
# === Authors
#
# Mark Stanislav <mstanislav@duosecurity.com>
#
class duo_unix::pam inherits duo_unix {
  $aug_pam_path     = "/files${duo_unix::pam_file}"
  $aug_pam_ssh_path = "/files${duo_unix::pam_ssh_file}"
  $aug_match        = "${aug_pam_path}/*/module[. = '${duo_unix::pam_module}']"

  file { '/etc/duo/pam_duo.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('duo_unix/duo.conf.erb'),
    require => Package[$duo_unix::duo_package];
  }

  if $duo_unix::manage_ssh {
    augeas { 'Duo Security SSH Configuration' :
      changes => [
        'set /files/etc/ssh/sshd_config/UsePAM yes',
        'set /files/etc/ssh/sshd_config/UseDNS no',
        'set /files/etc/ssh/sshd_config/ChallengeResponseAuthentication yes'
      ],
      require => Package[$duo_unix::duo_package],
      notify  => Service[$duo_unix::ssh_service];
    }
  }

  if $duo_unix::manage_pam {
    if $::osfamily == 'RedHat' {
      augeas { 'PAM Configuration':
        changes => [
          "set ${aug_pam_path}/2/control ${duo_unix::pam_unix_control}",
          "ins 100 after ${aug_pam_path}/2",
          "set ${aug_pam_path}/100/type auth",
          "set ${aug_pam_path}/100/control sufficient",
          "set ${aug_pam_path}/100/module ${duo_unix::pam_module}"
        ],
        require => Package[$duo_unix::duo_package],
        onlyif  => "match ${aug_match} size == 0";
      }

    } else {
      augeas { 'PAM Configuration':
        changes => [
          "set ${aug_pam_path}/1/control ${duo_unix::pam_file}",
          "ins 100 after ${aug_pam_path}/1",
          "set ${aug_pam_path}/100/type auth",
          "set ${aug_pam_path}/100/control '[success=1 default=ignore]'",
          "set ${aug_pam_path}/100/module ${duo_unix::pam_module}"
        ],
        require => Package[$duo_unix::duo_package],
        onlyif  => "match ${aug_match} size == 0";
      }
    }
  }
  if $duo_unix::manage_pam_ssh_key {
    if $::osfamily == 'Debian' {
      augeas { 'PAM SSH Duo Configuration 1':
        changes => [
          "ins 101 after ${aug_pam_ssh_path}/include[1]",
          "set ${aug_pam_ssh_path}/101/type auth",
          "set ${aug_pam_ssh_path}/101/control '[success=1 default=ignore]'",
          "set ${aug_pam_ssh_path}/101/module ${duo_unix::pam_module}",
        ],
      require   => Package[$duo_unix::duo_package],
      onlyif    => "match ${aug_pam_ssh_path}/*/module[. = '${duo_unix::pam_module}'] size == 0";
      }
      augeas { 'PAM SSH Duo Configuration 2':
        changes => [
          "ins 102 after ${aug_pam_ssh_path}/1",
          "set ${aug_pam_ssh_path}/102/type auth",
          "set ${aug_pam_ssh_path}/102/control requisite",
          "set ${aug_pam_ssh_path}/102/module pam_deny.so",
        ],
      require   => Augeas['PAM SSH Duo Configuration 1'],
      onlyif    => "match ${aug_pam_ssh_path}/*/module[. = 'pam_deny.so'] size == 0";
      }
      augeas { 'PAM SSH Duo Configuration 3':
        changes => [
          "ins 103 after ${aug_pam_ssh_path}/2",
          "set ${aug_pam_ssh_path}/103/type auth",
          "set ${aug_pam_ssh_path}/103/control required",
          "set ${aug_pam_ssh_path}/103/module pam_permit.so",
        ],
      require   => Augeas['PAM SSH Duo Configuration 2'],
      onlyif    => "match ${aug_pam_ssh_path}/*/module[. = 'pam_permit.so'] size == 0";
      }
      if $::facts['os']['release']['major'] =~ /14/ {
        augeas { 'PAM SSH Duo Configuration 4':
          changes => [
            "ins 104 after ${aug_pam_ssh_path}/3",
            "set ${aug_pam_ssh_path}/104/type auth",
            "set ${aug_pam_ssh_path}/104/control optional",
            "set ${aug_pam_ssh_path}/104/module pam_cap.so",
          ],
        require   => Augeas['PAM SSH Duo Configuration 3'],
        onlyif    => "match ${aug_pam_ssh_path}/*/module[. = 'pam_cap.so'] size == 0";
        }
      }
      file_line { 'sshd-common-auth':
        path    => '/etc/pam.d/sshd',
        line    => '# @include common-auth',
        match   => 'common-auth',
        require => Augeas['PAM SSH Duo Configuration 1'],
      }
    }
    else {
      notify { 'This is only supported on Debian based systems':}
    }
  }
}

package Mojolicious::Plugin::SimpleAuth;
use Mojo::Base 'Mojolicious::Plugin';

use String::Random;
use CellBIS::Random;
use Mojo::SimpleAuth;
use Mojo::SimpleAuth::Sessions;
use Mojo::Util 'dumper';

use Scalar::Util qw(blessed weaken);

# ABSTRACT: The Minimalistic Authentication
our $VERSION = '0.1';

has mojo_sa     => 'Mojo::SimpleAuth';
has utils       => sub { Mojolicious::Plugin::SimpleAuth::_utils->new };
has random      => 'String::Random';
has crand       => 'CellBIS::Random';
has use_cookies => 1;

sub register {
  my ($self, $app, $conf) = @_;

  # Home Dir
  my $home = $app->home->detect;

  # Check Config
  $conf                    //= {};
  $conf->{'helper.prefix'} //= 'msa';
  $conf->{'via'}           //= 'db:sqlite';
  $conf->{'dir'}           //= 'migrations';
  $conf->{'sth'}           //= '';
  $conf->{'csrf.name'}     //= 'msa_csrf_token';
  $conf->{'csrf.state'}    //= 'new';
  $conf->{'s.time'}        //= '1w';
  $conf->{'c.time'}        //= '1w';
  $conf->{'helper'}        //= '';

  my $time_session = $self->utils->time_convert($conf->{'s.time'});
  my $time_cookies = $self->utils->time_convert($conf->{'c.time'});
  $conf->{'cookies'} //= {
    name     => 'clg',
    path     => '/',
    httponly => 1,
    expires  => time + $time_session,
    max_age  => $time_session,
    secure   => 0
  };
  $conf->{'session'} //= {
    cookie_name        => '_msa',
    cookie_path        => '/',
    default_expiration => $time_cookies,
    secure             => 0
  };
  $conf->{dir} = $home . '/' . $conf->{'dir'};

  my $msa = $self->mojo_sa->new(
    via => $conf->{via},
    sth => $conf->{sth},
    dir => $conf->{dir}
  );
  $msa->prepare;

  # Check Database Migration
  $msa->check_file_migration();
  $msa->check_migration();

  # Helper Prefix
  my $prefix = $conf->{'helper.prefix'};

  $app->hook(
    after_build_tx => sub {
      my ($tx, $c) = @_;
      $c->sessions(Mojo::SimpleAuth::Sessions->new(%{$conf->{session}}));
      $c->sessions->max_age(1)
        if defined $c->sessions->max_age
        && defined $conf->{'session'}->{max_age};
    }
  );

  $app->helper($prefix . '_signin' => sub { $self->_sign_in($conf, $msa, @_) });
  $app->helper($prefix . '_signout' => sub { $self->_sign_out(@_) });
  $app->helper(
    $prefix . '_has_auth' => sub { $self->_has_auth($conf, $msa, @_) });
  $app->helper($prefix . '_regen_cookie' => sub { $self->_update_cookie(@_) });

  $app->helper($prefix . '_csrf' => sub { $self->_csrf($conf, @_) });
  $app->helper($prefix . '_csrf_regen' => sub { $self->_csrfreset($conf, @_) });
  $app->helper($prefix . '_csrf_get' => sub { $self->_csrf_get($conf, @_) });
  $app->helper($prefix . '_csrf_val' => sub { $self->_csrf_val($conf, @_) });
}

sub _val {
  my ($plugin, $conf, $msa, $c) = @_;

  my $csrf_val = $conf->{'helper.prefix'} . '_csrf_val';
  my $coo      = $c->cookie($conf->{cookies}->{name});
  return [undef, undef] unless $coo;

  ($msa->handler->check(1, $coo), $c->$csrf_val());
}

sub _sign_in {
  my ($plugin, $conf, $msa, $c, $idtfy) = @_;

  my $backend = $msa->handler;
  my $cv = $plugin->utils->cookies_login($conf, $plugin, $c);

  return $backend->create($idtfy, $cv->[0], $cv->[1]);
}

sub _sign_out {
  my ($self, $c) = @_;

  $c->session(expires => 1);
}

sub _has_auth {
  my ($self, $conf, $msa, $c) = @_;

  my ($rc, $rt) = $self->_val($conf, $msa, $c);
  if ($rc && ref $rc && $rt) {
    return [$rc, $rt];
  }
  return undef;
}

sub _update_cookie {
  my ($self, $c) = @_;

}

sub _csrf {
  my ($plugin, $conf, $c) = @_;

  # Generate CSRF Token if not exists
  unless ($c->session($conf->{'csrf.name'})) {
    my $cook = $plugin->utils->gen_cookie($plugin->random, 3);
    my $csrf = $plugin->crand->new->random($cook, 2, 3);

    $c->session($conf->{'csrf.name'} => $csrf);
    $c->res->headers->append('X-MSA-CSRF-Token' => $csrf);
  }
}

sub _csrfreset {
  my ($plugin, $conf, $c) = @_;

  my $coon = $plugin->utils->gen_cookie($plugin->random, 3);
  my $csrf = $plugin->crand->new->random($coon, 2, 3);

  $c->session($conf->{'csrf.name'} => $csrf);
  $c->res->headers->header('X-MSA-CSRF-Token' => $csrf);
}

sub _csrf_get {
  my ($plugin, $conf, $c) = @_;
  return $c->session($conf->{'csrf.name'})
    || $c->req->headers->header('X-MSA-CSRF-Token');
}

sub _csrf_val {
  my ($plugin, $conf, $c) = @_;

  my $get_csrf = $plugin->_csrf_get($conf, $c);
  my $csrf_header = $c->res->headers->header('X-MSA-CSRF-Token');
  return $get_csrf if $csrf_header eq $get_csrf;
}

package Mojolicious::Plugin::SimpleAuth::_csrf;
use Mojo::Base -base;

sub from_db {
  my ($self, $csrf) = @_;
}

sub from_req {
  my ($self, $csrf) = @_;
}


package Mojolicious::Plugin::SimpleAuth::_utils;
use Mojo::Base -base;

sub get_session {
  my ($self, $app, $conf) = @_;

  my $csrf = $app->session($conf->{'csrf.name'});
}

sub cookies_login {
  my ($self, $conf, $plugin, $app) = @_;

  my $csrf_get = $conf->{'helper.prefix'} . '_csrf_get';
  my $csrf_reg = $conf->{'helper.prefix'} . '_csrf';
  my $csrf     = $app->$csrf_get() || $app->$csrf_reg();

  my $cookie_key = $conf->{'cookies'}->{name};
  my $cookie_val
    = Mojo::Util::hmac_sha1_sum($self->gen_cookie($plugin->random, 5), $csrf);
  $app->cookie($cookie_key, $cookie_val, $conf->{'cookies'});
  [$cookie_val, $csrf];
}

sub check_cookies_login {
  my ($self, $app, $conf) = @_;
  return $app->cookie($conf->{'cookies'}->{name});
}

sub gen_cookie {
  my ($self, $random, $num) = @_;
  $num //= 3;
  $random->new->randpattern('CnCCcCCnCn' x $num);
}

sub hash_union {
  my ($self, $indicator, $src, $target) = @_;
}

sub time_convert {
  my ($self, $abbr) = @_;

  # Reset shortening time
  $abbr //= '1h';
  $abbr =~ qr/^([\d.]+)(\w)/;

  # Set standard of time units
  my $minute = 60;
  my $hour   = 60 * 60;
  my $day    = 24 * $hour;
  my $week   = 7 * $day;
  my $month  = 30 * $day;
  my $year   = 12 * $month;

  # Calculate by time units.
  my $identifier;
  $identifier = int $1 * 1   if $2 eq 's';
  $identifier = $1 * $minute if $2 eq 'm';
  $identifier = $1 * $hour   if $2 eq 'h';
  $identifier = $1 * $day    if $2 eq 'd';
  $identifier = $1 * $week   if $2 eq 'w';
  $identifier = $1 * $month  if $2 eq 'M';
  $identifier = $1 * $year   if $2 eq 'y';
  return $identifier;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::SimpleAuth - Mojolicious Web Authentication.

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('SimpleAuth');
  $self->plugin('SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_',
    via => 'db:mysql',
    dir => 'your-dir-cfg-auth',
    sth => <Your Handler Here>
  }); # With Options

  # Mojolicious Lite
  plugin 'SimpleAuth';
  plugin 'SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_',
    via => 'db:mysql',
    dir => 'your-dir-config-auth',
    sth => <Your Handler Here>
  };

=head1 DESCRIPTION

L<Mojolicious::Plugin::SimpleAuth> is a L<Mojolicious> plugin for
Web Authentication. (Minimalistic and Powerful).

=head1 OPTIONS

=head2 helper.prefix

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_'
  };
  
To change prefix of all helpers. By default, C<helper.prefix> is C<msa_>.

=head2 via

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    via => 'db:mysql', # OR
    via => 'db:pg'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    via => 'db:mysql', # OR
    via => 'db:pg'
  };
  
Use one of C<'db:mysql'> or C<'db:pg'> or C<'db:sqlite'>.
(For C<'db:sqlite'> option does not need to be specified,
as it would by default be using C<'db:sqlite'>
if option C<via> is not specified).

=head2 dir

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    dir => 'your-custon-dirname-here'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    dir => 'your-custon-dirname-here'
  };
  
Specified directory for L<Mojolicious::Plugin::SimpleAuth> configure files.

=head2 sth (Storage Handler)

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    sth => 'Mojo::SQLite'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    sth => 'Mojo::SQLite'
  };
  
Storage Handler can be use namespace string or methods has been initialization.
If C<sth> does not to be specified, then L<Mojo::SQLite> will be used
for this options by default.

=head1 HELPERS

By default, prefix for all helpers using C<msa_>, but you can
do change that with option C<helper.prefix>.

=head2 msa_signin

  $c->msa_signin('login-identify')
  
Helper for action sign-in (login) web application.

=head2 msa_signout

  $c->msa_signout; # In the controllers
  
Helper for action sign-out (logout) web application.

=head2 msa_has_auth

  $c->msa_has_auth; # In the controllers
  
Helper for checking if routes has authenticated.

=head2 msa_csrf

  $c->msa_csrf; # In the controllers
  <%= msa_csrf %> # In the template.
  
Helper for generate csrf;

=head2 msa_csrf_val

  $c->msa_csrf_val; # In the controllers
  
Helper for validation that csrf from request routes.

=head2 msa_val

  $c->msa_val; # In the controllers
  
Helper for do validate authentication.

=head1 METHODS

L<Mojolicious::Plugin::SimpleAuth> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojo::SimpleAuth>,
L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=head1 AUTHOR

Achmad Yusri Afandi, C<yusrideb@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Achmad Yusri Afandi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

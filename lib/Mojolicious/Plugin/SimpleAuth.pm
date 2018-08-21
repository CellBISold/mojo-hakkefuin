package Mojolicious::Plugin::SimpleAuth;
use Mojo::Base 'Mojolicious::Plugin';

use String::Random;
use CellBIS::Random;
use Mojo::SimpleAuth;
use Mojo::SimpleAuth::Sessions;
use Mojo::Util qw(dumper secure_compare);

# ABSTRACT: The Minimalistic Mojolicious Authentication
our $VERSION = '0.1';

has mojo_sa => 'Mojo::SimpleAuth';
has utils   => sub {
  state $utils
    = Mojolicious::Plugin::SimpleAuth::_utils->new(random => 'String::Random');
};
has cookies => sub {
  state $cookies = Mojolicious::Plugin::SimpleAuth::_cookies->new(
    utils  => shift->utils,
    random => 'String::Random'
  );
};
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
  $conf->{'stash.prefix'}  //= 'msa';
  $conf->{'via'}           //= 'db:sqlite';
  $conf->{'dir'}           //= 'migrations';
  $conf->{'sth'}           //= '';
  $conf->{'csrf.name'}     //= 'msa_csrf_token';
  $conf->{'csrf.state'}    //= 'new';
  $conf->{'s.time'}        //= '1w';
  $conf->{'c.time'}        //= '1w';
  $conf->{'callback'}      //= {
    'has_auth' => sub { },
    'sign_in'  => sub { },
    'sign_out' => sub { }
  };

  my $time_session = $self->utils->time_convert($conf->{'s.time'});
  my $time_cookies = $self->utils->time_convert($conf->{'c.time'});
  $conf->{'cookies'} //= {
    name     => 'clg',
    path     => '/',
    httponly => 1,
    expires  => time + $time_cookies,
    max_age  => $time_cookies,
    secure   => 0
  };
  $conf->{'session'} //= {
    cookie_name        => '_msa',
    cookie_path        => '/',
    default_expiration => $time_session,
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
  my $pre = $conf->{'helper.prefix'};

  $app->hook(
    after_build_tx => sub {
      my ($tx, $c) = @_;
      $c->sessions(Mojo::SimpleAuth::Sessions->new(%{$conf->{session}}));
      $c->sessions->max_age(1) if $c->sessions->can('max_age');
    }
  );

  $app->helper($pre . '_signin' => sub { $self->_sign_in($conf, $msa, @_) });
  $app->helper($pre . '_signout' => sub { $self->_sign_out($conf, $msa, @_) });
  $app->helper($pre . '_has_auth' => sub { $self->_has_auth($conf, $msa, @_) });
  $app->helper(
    $pre . '_auth_update' => sub { $self->_update_auth($conf, $msa, @_) });

  $app->helper($pre . '_csrf' => sub { $self->_csrf($conf, @_) });
  $app->helper($pre . '_csrf_regen' => sub { $self->_csrfreset($conf, @_) });
  $app->helper($pre . '_csrf_get' => sub { $self->_csrf_get($conf, @_) });
  $app->helper($pre . '_csrf_val' => sub { $self->_csrf_val($conf, @_) });
}

sub _sign_in {
  my ($self, $conf, $msa, $c, $idtfy) = @_;

  my $backend = $msa->backend;
  my $cv = $self->cookies->create($conf, $c);

  return $backend->create($idtfy, $cv->[0], $cv->[1],
    $self->utils->time_convert($conf->{'c.time'}));
}

sub _sign_out {
  my ($self, $conf, $msa, $c, $identify) = @_;

  # Session Destroy :
  $c->session(expires => 1);

  my $cookie = $self->cookies->delete($conf, $c);
  return $msa->backend->delete($identify, $cookie);
}

sub _has_auth {
  my ($self, $conf, $msa, $c) = @_;

  my $result   = {result => 0, code => 404, data => 'empty'};
  my $csrf_get = $conf->{'helper.prefix'} . '_csrf_get';
  my $coo      = $c->cookie($conf->{cookies}->{name});

  return $result unless $coo;

  my $auth_check = $msa->backend->check(1, $coo);

  if ($auth_check->{result} == 1) {
    $result
      = $auth_check->{data}->{csrf} eq $c->$csrf_get()
      ? {result => 1, code => 200, data => ''}
      : {result => 3, code => 406, data => ''};
    $c->stash(
      $conf->{'stash.prefix'} . '.identify' => $auth_check->{data}->{identify});
  }
  return $result;
}

sub _update_auth {
  my ($self, $conf, $msa, $c, $identify, $to_update) = @_;

  # CSRF and cookies login update
  my $update;
  if ($to_update) {
    $update = $self->_csrfreset($conf, $c) if $to_update eq 'csrf';
    $update = $self->cookies->update($conf, $c) if $to_update eq 'cookie';
  }
  else {
    $update = $self->cookies->update($conf, $c, 1);
  }

  # Update to db
  my $result = {result => 0};
  if (my ($cookie, $csrf) = @{$update}) {
    if ($to_update) {
      $result = $msa->backend->update_cookie($identify, $cookie)
        if $to_update eq 'cookie';
      $result = $msa->backend->update_csrf($identify, $csrf)
        if $to_update eq 'csrf';
    }
    else {
      $result = $msa->backend->update($identify, $cookie, $csrf);
    }
  }
  return $result;
}

sub _csrf {
  my ($self, $conf, $c) = @_;

  # Generate CSRF Token if not exists
  unless ($c->session($conf->{'csrf.name'})) {
    my $cook = $self->utils->gen_cookie(3);
    my $csrf = $self->crand->new->random($cook, 2, 3);

    $c->session($conf->{'csrf.name'} => $csrf);
    $c->res->headers->append('X-MSA-CSRF-Token' => $csrf);
  }
}

sub _csrfreset {
  my ($self, $conf, $c) = @_;

  my $coon = $self->utils->gen_cookie(3);
  my $csrf = $self->crand->new->random($coon, 2, 3);

  $c->session($conf->{'csrf.name'} => $csrf);
  $c->res->headers->header('X-MSA-CSRF-Token' => $csrf);
  return $csrf;
}

sub _csrf_get {
  my ($plugin, $conf, $c) = @_;
  return $c->session($conf->{'csrf.name'})
    || $c->req->headers->header('X-MSA-CSRF-Token');
}

sub _csrf_val {
  my ($plugin, $conf, $c) = @_;

  my $get_csrf    = $c->session($conf->{'csrf.name'});
  my $csrf_header = $c->res->headers->header('X-MSA-CSRF-Token');
  return $csrf_header if $csrf_header eq $get_csrf;
}

package Mojolicious::Plugin::SimpleAuth::_cookies;
use Mojo::Base -base;

has 'random';
has 'utils';

sub create {
  my ($self, $conf, $app) = @_;

  my $csrf_get = $conf->{'helper.prefix'} . '_csrf_get';
  my $csrf_reg = $conf->{'helper.prefix'} . '_csrf_regen';
  my $csrf     = $app->$csrf_get() || $app->$csrf_reg();

  my $cookie_key = $conf->{'cookies'}->{name};
  my $cookie_val
    = Mojo::Util::hmac_sha1_sum($self->utils->gen_cookie(5), $csrf);
  $app->cookie($cookie_key, $cookie_val, $conf->{'cookies'});
  [$cookie_val, $csrf];
}

sub update {
  my ($self, $conf, $app, $csrf_reset) = @_;

  if ($self->check($app, $conf)) {
    my $csrf
      = $conf->{'helper.prefix'} . ($csrf_reset ? '_csrfreset' : '_csrf_get');
    $csrf = $app->$csrf();

    my $cookie_key = $conf->{'cookies'}->{name};
    my $cookie_val
      = Mojo::Util::hmac_sha1_sum($self->utils->gen_cookie(5), $csrf);
    $app->cookie($cookie_key, $cookie_val, $conf->{'cookies'});
    return [$cookie_val, $csrf];
  }
  }
  return undef;
}

sub delete {
  my ($self, $conf, $app) = @_;

  if (my $cookie = $self->check($app, $conf)) {
    $app->cookie($conf->{'cookies'}->{name} => '', {expires => 1});
    return $cookie;
  }
  return undef;
}

sub check {
  my ($self, $app, $conf) = @_;
  return $app->cookie($conf->{'cookies'}->{name});
}

package Mojolicious::Plugin::SimpleAuth::_utils;
use Mojo::Base -base;

has 'random';

sub gen_cookie {
  my ($self, $num) = @_;
  $num //= 3;
  $self->random->new->randpattern('CnCCcCCnCn' x $num);
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
    sth => <Your Backend Here>
  }); # With Options

  # Mojolicious Lite
  plugin 'SimpleAuth';
  plugin 'SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_',
    via => 'db:mysql',
    dir => 'your-dir-config-auth',
    sth => <Your Backend Here>
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
  
Storage Backend Handler can be use namespace string or methods has been initialization.
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

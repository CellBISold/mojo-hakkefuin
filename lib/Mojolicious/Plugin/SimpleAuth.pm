package Mojolicious::Plugin::SimpleAuth;
use Mojo::Base 'Mojolicious::Plugin';

use CellBIS::Random;
use Mojo::Hakkefuin;
use Mojo::Hakkefuin::Utils;
use Mojo::Hakkefuin::Sessions;
use Mojo::Util qw(dumper secure_compare);

# ABSTRACT: The Minimalistic Mojolicious Authentication
our $VERSION = '0.2';

has mojo_hf => 'Mojo::Hakkefuin';
has utils   => sub {
  state $utils = Mojo::Hakkefuin::Utils->new(random => 'String::Random');
};
has cookies => sub {
  state $cookies = Mojolicious::Plugin::SimpleAuth::_cookies->new(
    utils  => shift->utils,
    random => 'String::Random'
  );
};
has random => 'String::Random';
has crand  => 'CellBIS::Random';

sub register {
  my ($self, $app, $conf) = @_;

  # Home Dir
  my $home = $app->home->detect;

  # Check Config
  $conf                    //= {};
  $conf->{'helper.prefix'} //= 'mhf';
  $conf->{'stash.prefix'}  //= 'mhf';
  $conf->{'via'}           //= 'sqlite';
  $conf->{'dir'}           //= 'migrations';
  $conf->{'csrf.name'}     //= 'mhf_csrf_token';
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
    cookie_name        => '_hakkefuin',
    cookie_path        => '/',
    default_expiration => $time_session,
    secure             => 0
  };
  $conf->{dir} = $home . '/' . $conf->{'dir'};

  # Build mojo-simple_auth Params
  my @mhf_params
    = $conf->{table_config} && $conf->{migration}
    ? (table_config => $conf->{table_config}, migration => $conf->{migration})
    : (via => $conf->{via}, dir => $conf->{dir});
  push @mhf_params, dir => $conf->{dir};
  push @mhf_params, via => $conf->{via};
  push @mhf_params, dsn => $conf->{dsn} if $conf->{dsn};
  my $mhf = $self->mojo_hf->new(@mhf_params);

  # Check Database Migration
  $mhf->check_file_migration();
  $mhf->check_migration();

  # Helper Prefix
  my $pre = $conf->{'helper.prefix'};

  $app->hook(
    after_build_tx => sub {
      my ($tx, $c) = @_;
      $c->sessions(Mojo::Hakkefuin::Sessions->new(%{$conf->{session}}));
      $c->sessions->max_age(1) if $c->sessions->can('max_age');
    }
  );

  $app->helper($pre . '_signin'  => sub { $self->_sign_in($conf, $mhf, @_) });
  $app->helper($pre . '_signout' => sub { $self->_sign_out($conf, $mhf, @_) });
  $app->helper($pre . '_has_auth' => sub { $self->_has_auth($conf, $mhf, @_) });
  $app->helper(
    $pre . '_auth_update' => sub { $self->_auth_update($conf, $mhf, @_) });

  $app->helper($pre . '_csrf' => sub { $self->_csrf($conf, @_) });
  $app->helper(
    $pre . '_csrf_regen' => sub { $self->_csrfreset($conf, $mhf, @_) });
  $app->helper($pre . '_csrf_get' => sub { $self->_csrf_get($conf, @_) });
  $app->helper($pre . '_csrf_val' => sub { $self->_csrf_val($conf, @_) });
  $app->helper(mhf_backend => sub { $mhf->backend });
}

sub _sign_in {
  my ($self, $conf, $mhf, $c, $idtfy) = @_;

  my $backend = $mhf->backend;
  my $cv      = $self->cookies->create($conf, $c);

  return $backend->create($idtfy, $cv->[0], $cv->[1],
    $self->utils->time_convert($conf->{'c.time'}));
}

sub _sign_out {
  my ($self, $conf, $mhf, $c, $identify) = @_;

  # Session Destroy :
  $c->session(expires => 1);

  my $cookie = $self->cookies->delete($conf, $c);
  return $mhf->backend->delete($identify, $cookie);
}

sub _has_auth {
  my ($self, $conf, $mhf, $c) = @_;

  my $result   = {result => 0, code => 404, data => 'empty'};
  my $csrf_get = $conf->{'helper.prefix'} . '_csrf_get';
  my $coo      = $c->cookie($conf->{cookies}->{name});

  return $result unless $coo;

  my $auth_check = $mhf->backend->check(1, $coo);

  if ($auth_check->{result} == 1) {
    $result
      = $auth_check->{data}->{csrf} eq $c->$csrf_get()
      ? {result => 1, code => 200, data => $auth_check->{data}}
      : {result => 3, code => 406, data => ''};
    $c->stash(
      $conf->{'stash.prefix'} . '.backend-id' => $auth_check->{data}->{id});
    $c->stash(
      $conf->{'stash.prefix'} . '.identify' => $auth_check->{data}->{identify});
  }
  return $result;
}

sub _auth_update {
  my ($self, $conf, $mhf, $c, $identify) = @_;

  my $result = {result => 0};
  my $update = $self->cookies->update($conf, $c, 1);
  my $csrf   = ref $update->[1] eq 'ARRAY' ? $update->[1]->[1] : $update->[1];
  $result = $mhf->backend->update($identify, $update->[0], $csrf);

  return $result;
}

sub _csrf {
  my ($self, $conf, $c) = @_;

  # Generate CSRF Token if not exists
  unless ($c->session($conf->{'csrf.name'})) {
    my $cook = $self->utils->gen_cookie(3);
    my $csrf = $self->crand->new->random($cook, 2, 3);

    $c->session($conf->{'csrf.name'} => $csrf);
    $c->res->headers->append('X-MHF-CSRF-Token' => $csrf);
  }
}

sub _csrfreset {
  my ($self, $conf, $mhf, $c, $id) = @_;

  my $coon = $self->utils->gen_cookie(3);
  my $csrf = $self->crand->new->random($coon, 2, 3);

  my $result = $mhf->backend->update_csrf($id, $csrf) if $id;

  $c->session($conf->{'csrf.name'} => $csrf);
  $c->res->headers->header('X-MHF-CSRF-Token' => $csrf);
  return [$result, $csrf];
}

sub _csrf_get {
  my ($self, $conf, $c) = @_;
  return $c->session($conf->{'csrf.name'})
    || $c->req->headers->header('X-MHF-CSRF-Token');
}

sub _csrf_val {
  my ($self, $conf, $c) = @_;

  my $get_csrf    = $c->session($conf->{'csrf.name'});
  my $csrf_header = $c->res->headers->header('X-MHF-CSRF-Token');
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
  my $csrf     = $app->$csrf_get() || $app->$csrf_reg()->[1];

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
      = $conf->{'helper.prefix'} . ($csrf_reset ? '_csrf_regen' : '_csrf_get');
    $csrf = $app->$csrf();

    my $cookie_key = $conf->{'cookies'}->{name};
    my $cookie_val
      = Mojo::Util::hmac_sha1_sum($self->utils->gen_cookie(5), $csrf);
    $app->cookie($cookie_key, $cookie_val, $conf->{'cookies'});
    return [$cookie_val, $csrf];
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

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::SimpleAuth - Mojolicious Web Authentication.

=head1 SYNOPSIS

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here_',
    'stash.prefix' => 'your_stash_prefix_here',
    via => 'mysql',
    dir => 'your-dir-location-file-db'
  };

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here',
    'stash.prefix' => 'your_stash_prefix_here',
    via => 'mysql',
    dir => 'your-dir-location-file-db'
  });
  
=head1 DESCRIPTION

L<Mojolicious::Plugin::SimpleAuth> is a L<Mojolicious> plugin for
Web Authentication. (Minimalistic and Powerful).

=head1 OPTIONS

=head2 helper.prefix

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'helper.prefix' => 'your_prefix_here'
  };
  
To change prefix of all helpers. By default, C<helper.prefix> is C<mhf_>.

=head2 stash.prefix

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'stash.prefix' => 'your_stash_prefix_here'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'stash.prefix' => 'your_stash_prefix_here'
  };
  
To change prefix of stash. By default, C<stash.prefix> is C<mhf_>.

=head2 csrf.name

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'csrf.name' => 'your_csrf_name_here'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'csrf.name' => 'your_csrf_name_here'
  };
  
To change csrf name in session and HTTP Headers. By default, C<csrf.prefix>
is C<mhf_csrf_token>.

=head2 via

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    via => 'mysql', # OR
    via => 'pg'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    via => 'mysql', # OR
    via => 'pg'
  };
  
Use one of C<'mysql'> or C<'pg'> or C<'sqlite'>. (For C<'sqlite'> option
does not need to be specified, as it would by default be using C<'sqlite'>
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

=head2 c.time

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    'c.time' => '1w'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    'c.time' => '1w'
  };
  
Specified cookie expires time. By default is 1 week.


=head2 s.time

  # Mojolicious
  $self->plugin('SimpleAuth' => {
    's.time' => '1w'
  });

  # Mojolicious Lite
  plugin 'SimpleAuth' => {
    's.time' => '1w'
  };
  
Specified cookie session expires time. By default is 1 week. For an explanation
of the time abbreviation for C<c.time> and C<s.time> helper,
see L<Mojo::Hakkefuin::Utils>.

=head1 HELPERS

By default, prefix for all helpers using C<mhf_>, but you can do change that
with option C<helper.prefix>.

=head2 mhf_signin

  $c->mhf_signin('login-identify') # In the controllers
  
Helper for action sign-in (login) web application.

=head2 mhf_signout

  $c->mhf_signout('login-identify'); # In the controllers
  
Helper for action sign-out (logout) web application.

=head2 mhf_has_auth

  $c->mhf_has_auth; # In the controllers
  
Helper for checking if routes has authenticated.

=head2 mhf_csrf

  $c->mhf_csrf; # In the controllers
  <%= mhf_csrf %> # In the template.
  
Helper for generate csrf;

=head2 mhf_csrf_val

  $c->mhf_csrf_val; # In the controllers
  
Helper for validation that csrf from request routes.

=head2 mhf_backend

  $c->mhf_backend; # In the controllers
  
Helper for access to backend.

=head1 METHODS

L<Mojolicious::Plugin::SimpleAuth> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<https://github.com/CellBIS/mojo-hakkefuin>,
<Mojolicious::Guides>, L<https://mojolicious.org>.

=head1 AUTHOR

Achmad Yusri Afandi, C<yusrideb@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Achmad Yusri Afandi

This program is free software, you can redistribute it and/or modify it
under the terms of the Artistic License version 2.0.

=cut

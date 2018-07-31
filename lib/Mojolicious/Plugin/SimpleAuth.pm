package Mojolicious::Plugin::SimpleAuth;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::SimpleAuth;

use Scalar::Util qw(blessed);

# ABSTRACT: The Minimalistic Authentication
our $VERSION = '0.1';

sub register {
  my ($plugin, $app, $conf) = @_;

  # Home Dir
  my $home = $app->home->detect;

  # Check Config
  $conf                    //= {};
  $conf->{'helper.prefix'} //= 'msa';
  $conf->{'via'}           //= 'db:sqlite';
  $conf->{'dir'}           //= 'migrations';
  $conf->{'sth'}           //= '';
  $conf->{'helper'}        //= '';
  $conf->{dir} = $home . '/' . $conf->{'dir'};

  my $simple_auth = Mojo::SimpleAuth->new(
    via => $conf->{via},
    sth => $conf->{sth},
    dir => $conf->{dir}
  );
  $simple_auth->prepare;

  # Check Database Migration
  $simple_auth->check_file_migration();
  $simple_auth->check_migration();

  # Helper Prefix
  my $helper_prefix = $conf->{'helper.prefix'};

  $app->helper(
    $helper_prefix . '_signin' => sub {
      "${helper_prefix}_signin test";
    }
  );

  $app->helper(
    $helper_prefix . '_signout' => sub {
      "${helper_prefix}_signout test";
    }
  );

  $app->helper(
    $helper_prefix . '_has_auth' => sub {
      "${helper_prefix}_has_auth test";
    }
  );

  $app->helper(
    $helper_prefix . '_csrf' => sub {
      "${helper_prefix}_csrf test";
    }
  );

  $app->helper(
    $helper_prefix . '_csrf_val' => sub {
      "${helper_prefix}_csrf_val test";
    }
  );

  $app->helper(
    $helper_prefix . '_val' => sub {
      "${helper_prefix}_val test";
    }
  );
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
    dir => 'your-dir-config-auth',
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
  
To change prefix of all helpers.

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
  
Storage Handler can be the namespace string or methods has been initialization.
If C<sth> does not to be specified, then L<Mojo::SQLite> will be used
for this options by default.

=head1 HELPERS

By default, prefix for all helpers using C<msa_>, but you can
do change that with option C<helper.prefix>.

=head2 msa_signin

  $c->msa_signin;
  
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

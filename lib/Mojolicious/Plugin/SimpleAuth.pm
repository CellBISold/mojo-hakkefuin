package Mojolicious::Plugin::SimpleAuth;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::SimpleAuth;
use Scalar::Util qw(blessed);

# ABSTRACT: Simple Ways Authentication for Mojolicious Apps
our $VERSION = '0.1';

sub register {
  my ($plugin, $app, $conf) = @_;
  
  # Home Dir
  my $home = $app->home->detect;

  # Check Config
  $conf //= {};
  $conf->{'helper.prefix'} //= 'msa';
  $conf->{'via'}           //= 'db:sqlite';
  $conf->{'dir'}           //= 'migrations';
  $conf->{'dbh'}           //= '';
  $conf->{'helper'}        //= '';
  $conf->{dir}             = $home . '/' . $conf->{'dir'};
  
  my $simple_auth = Mojo::SimpleAuth->new(
    via => $conf->{via},
    dbh => $conf->{dbh},
    dir => $conf->{dir}
  );
  $simple_auth->prepare;
  
  # Check Database Migration
  $simple_auth->check_file_migration();
  $simple_auth->check_migration();

  # Helper Prefix
  my $helper_prefix  = $conf->{'helper.prefix'};

  $app->helper(
    $helper_prefix . '_signin' => sub {
      "${helper_prefix}_signin test"
    }
  );

  $app->helper(
    $helper_prefix . '_signout' => sub {
      "${helper_prefix}_signout test"
    }
  );

  $app->helper(
    $helper_prefix . '_has_auth' => sub {
      "${helper_prefix}_has_auth test"
    }
  );

  $app->helper(
    $helper_prefix . '_csrf' => sub {
      "${helper_prefix}_csrf test"
    }
  );

  $app->helper(
    $helper_prefix . '_csrf_val' => sub {
      "${helper_prefix}_csrf_val test"
    }
  );

  $app->helper(
    $helper_prefix . '_val' => sub {
      "${helper_prefix}_val test"
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

  # Mojolicious Lite
  plugin 'SimpleAuth';

=head1 DESCRIPTION

L<Mojolicious::Plugin::SimpleAuth> is a L<Mojolicious> plugin for
Simple ways for Web Authentication.

=head1 METHODS

L<Mojolicious::Plugin::SimpleAuth> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut

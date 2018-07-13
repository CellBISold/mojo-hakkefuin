package Mojolicious::Plugin::csAuth;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($plugin, $app) = @_;
  
  $app->helper(cb_sign_in => sub {
  
  });
  
  $app->helper(cb_sign_out => sub {
  
  });
  
  $app->helper(cb_has_auth => sub {
  
  });
  
  $app->helper(cb_csrf => sub {
  
  });
  
  $app->helper(cb_validation => sub {
  
  });
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::cellbisSimAuth - Mojolicious Plugin for Web Authentication.

=head1 DESCRIPTION

L<Mojolicious::Plugin::cellbisSimAuth> is a L<Mojolicious> plugin for Simple Web Authentication.

=head1 METHODS

L<Mojolicious::Plugin::cellbisSimAuth> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

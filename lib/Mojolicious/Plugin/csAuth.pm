package Mojolicious::Plugin::csAuth;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($plugin, $app) = @_;
  
  $app->helper(cs_sign_in => sub {
  
  });
  
  $app->helper(cs_sign_out => sub {
  
  });
  
  $app->helper(cs_has_auth => sub {
  
  });
  
  $app->helper(cs_csrf => sub {
  
  });
  
  $app->helper(cs_csrf_val => sub {
  
  });
  
  $app->helper(cs_val => sub {
  
  });
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::csAuth - Mojolicious Plugin for Web Authentication.

=head1 DESCRIPTION

L<Mojolicious::Plugin::csAuth> is a L<Mojolicious> plugin for Simple Web Authentication.

=head1 METHODS

L<Mojolicious::Plugin::csAuth> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut

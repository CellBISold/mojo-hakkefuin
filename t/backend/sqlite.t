use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Mojo::Util 'secure_compare';
use Mojo::File;
use Test::Mojo;

# Home Dir
my $home = app->home->detect;
my $path = Mojo::File->new($home . '/migrations');

# User :
my $USERS = {yusrideb => 's3cr3t',};

plugin "SimpleAuth", {dir => 'migrations'};

get '/' => sub {
  my $c = shift;
  $c->render(
    text => 'Welcome to Sample testing Mojolicious::Plugin::SimpleAuth');
};

get '/login-page' => sub {
  my $c = shift;
  $c->render(text => 'login');
};

post '/login' => sub {
  my $c = shift;

  # Query or POST parameters
  my $user = $c->param('user') || '';
  my $pass = $c->param('pass') || '';

  if ($USERS->{$user} && secure_compare $USERS->{$user}, $pass) {
    return $c->render(
      text => $c->msa_signin($user) ? 'login success' : 'error login');
  }
  else {
    return $c->render(text => 'error user or pass');
  }
};

get '/page' => sub {
  my $c = shift;
  $c->render(
    text => $c->msa_has_auth()->{'result'} == 1 ? 'page' : 'Unauthenticated');
};

post '/logout' => sub {
  my $c = shift;

  if ($c->msa_has_auth()->{'result'}) {
    if ($c->msa_signout()) {
      $c->render(text => 'logout success');
    }
  }

};

# Authentication Testing
my $t = Test::Mojo->new;
$t->ua->max_redirects(1);

# Main page
$t->get_ok('/')->status_is(200)
  ->content_is('Welcome to Sample testing Mojolicious::Plugin::SimpleAuth');

# Login Page
$t->get_ok('/login-page')->status_is(200)->content_is('login', 'Login Page');

# Login Action is fails.
$t->post_ok('/login?user=yusrideb&pass=s3cr3t1')->status_is(200)
  ->content_is('error user or pass', 'Fail Login');

# Login Action is Success
$t->post_ok('/login?user=yusrideb&pass=s3cr3t')->status_is(200)
  ->content_is('login success', 'Success Login');

# Page with Authenticated
$t->get_ok('/page')->status_is(200)->content_is('page', 'Authenticated page');

# Logout
$t->post_ok('/logout')->status_is(200)
  ->content_is('logout success', 'Logout Success');

# Page without Authenticated
$t->get_ok('/page')->status_is(200)
  ->content_is('Unauthenticated', 'Unauthenticated page');

done_testing();

# Remove dir migration after testing.
$path->remove_tree;

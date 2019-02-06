use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Mojo::Util 'secure_compare';
use Mojo::File;
use Test::Mojo;

plan skip_all => 'set TEST_ONLINE_mysql to enable this test'
  unless $ENV{TEST_ONLINE_mysql};

# User :
my $USERS = {yusrideb => 's3cr3t'};

plugin "SimpleAuth", {via => 'mysql', dsn => $ENV{TEST_ONLINE_mysql}};

app->secrets(['s3cr3t_m0j0l!c1oU5']);

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

get '/csrf-reset' => sub {
  my $c = shift;

  my $data_result = 'can\'t reset';
  my $result      = $c->msa_has_auth();
  if ($result->{result} == 1) {
    $data_result = 'error reset';
    my $do_reset = $c->msa_csrf_regen($c->stash('msa.backend-id'));
    $data_result = 'success reset' if ($do_reset->[0]->{result} == 1);
  }
  $c->render(text => $data_result);
};

get '/page' => sub {
  my $c = shift;
  $c->render(
    text => $c->msa_has_auth()->{'code'} == 200 ? 'page' : 'Unauthenticated');
};

get '/stash' => sub {
  my $c = shift;
  my $check_stash
    = $c->msa_has_auth()->{code} == 200
    ? $c->stash->{'msa.identify'}
    : 'fail stash login';
  $c->render(text => $check_stash);
};

post '/logout' => sub {
  my $c = shift;

  my $check_auth = $c->msa_has_auth();
  if ($check_auth->{'code'} == 200) {
    if ($c->msa_signout($c->stash->{'msa.identify'})->{code} == 200) {
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

# Check Stash login
$t->get_ok('/stash')->status_is(200);

# CSRF Reset
$t->get_ok('/csrf-reset')->status_is(200)
  ->content_is('success reset', 'CSRF reset success');

# Page with Authenticated
$t->get_ok('/page')->status_is(200)->content_is('page', 'Authenticated page');

# Logout
$t->post_ok('/logout')->status_is(200)
  ->content_is('logout success', 'Logout Success');

# Page without Authenticated
$t->get_ok('/page')->status_is(200)
  ->content_is('Unauthenticated', 'Unauthenticated page');

# Check stash login without Authenticated
$t->get_ok('/stash')->status_is(200)
  ->content_is('fail stash login', 'stash is not found');

done_testing();

# Clear
$t->app->mhf_backend->empty_table;
$t->app->mhf_backend->drop_table;

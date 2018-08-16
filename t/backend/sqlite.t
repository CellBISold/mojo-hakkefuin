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
    'text' => 'Welcome to Sample testing Mojolicious::Plugin::SimpleAuth');
};

# Group for login page
group {

  # Login Page check authentication.
  under sub {
    my $c = shift;

    return 1 unless $c->msa_has_auth()->{'result'};

    $c->redirect_to($c->req->url);
    return undef;
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
      $c->msa_signin($user);
      $c->redirect_to('/page');
    } else {
      return $c->render(text => 'error user or pass');
    }
  };

};

# Group for all page
group {

  # All Page check authentication.
  under sub {
    my $c = shift;

    if ($c->msa_has_auth()->{'result'}) {
      return 1;
    } else {
      my $url = $c->req->url !~ qr/login/ ? $c->req->url : '/';
      $c->redirect_to($url);
      return undef;
    }
  };

  get '/page' => sub {
    my $c = shift;
    $c->render(text => 'page');
  };
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
$t->post_ok('/login?user=yusrideb&pass=s3cr3t1')->status_is(200)->content_is('error user or pass', 'Fail Login');

# Login Action is Success
$t->post_ok('/login?user=yusrideb&pass=s3cr3t')->status_is(302)->content_is('', 'Success Login');

done_testing();

# Remove dir migration after testing.
$path->remove_tree;

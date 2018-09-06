package Mojo::SimpleAuth;
use Mojo::Base -base;

use Carp 'croak';
use File::Spec::Functions 'file_name_is_absolute';
use Scalar::Util qw(blessed weaken);
use Mojo::File qw(path);
use Mojo::Util qw(dumper);
use Mojo::Loader 'load_class';
use String::Random;
use CellBIS::SQL::Abstract;

# Attributes
has random => sub { String::Random->new };
has 'via';
has 'dir';
has 'table_config';    # not yet implemented.

# Internal Attributes
has 'backend';
has 'migration_status' => 0;

sub check_file_migration {
  my $self = shift;

  my $backend        = $self->backend;
  my $file_migration = $backend->file_migration();
  unless (-d $self->dir) { mkdir $self->dir }
  unless (-f $file_migration) {
    path($file_migration)->spurt($backend->table_query())
      if ($self->table_config);
  }
  return $self;
}

sub check_migration {
  my $self = shift;

  my $backend = $self->backend;
  my $check   = $backend->check_table();
  unless ($check->{result}) {
    croak "Can't create table database"
      unless $backend->create_table->{code} == 200;
  }
  return $self;
}

sub new {
  my $self = shift->SUPER::new(@_);

  $self->{via} //= 'sqlite';

  # Build params for backend
  my @param
    = $self->table_config
    ? (dir => $self->dir, %{$self->table_config})
    : (dir => $self->dir);

  # Load class backend
  my $class = 'Mojo::SimpleAuth::Backend::' . $self->via;
  my $load  = load_class $class;
  croak ref $load ? $load : qq{Backend "$class" missing} if $load;
  $self->backend($class->new(@param));

  return $self;
}

sub _check_migration_file {
  my $self = shift;

  my $loc_file = $self->dir . $self->backend()->file_migration;
  if (-f $loc_file) {
    return $self unless $self->backend()->table()->{result};
  }
  else {
    my $content_file = $self->backend()->table_query();
    path($loc_file)->spurt($content_file);
    return $self unless $self->backend()->table()->{result};
  }
}

1;

=encoding utf8

=head1 NAME

Mojo::SimpleAuth - Abstraction for L<Mojolicious::Plugin::SimpleAuth>

=head1 SYNOPSIS

  use Mojo::SimpleAuth;
  
  # SQLite as backend
  my $msa = Mojo::SimpleAuth->new({ dir => 'migrations' });
  
  # MySQL as backend
  my $msa = Mojo::SimpleAuth->new({
    via => 'mysql',
    dir => 'migrations'
  });
  
  # PostgreSQL as backend
  my $msa = Mojo::SimpleAuth->new({
    via => 'pg',
    dir => 'migrations'
  });

=head1 DESCRIPTION

General abstraction for L<Mojolicious::Plugin:::SimpleAuth>. By defaults
storage handler using L<Mojo::SQLite>

=head1 ATTRIBUTES

L<Mojo::SimpleAuth> inherits all attributes from
L<Mojo::Base> and implements the following new ones.

=head2 via

  $msa->via;
  $msa->via('mysql');
  $msa->via('sqlite');
  $msa->via('pg');
  
Specify of backend via MariaDB/MySQL or SQLite or PostgreSQL.
This attribute by default contains <db:sqlite>.

=head2 dir

  $msa->dir;
  $msa->dir('migrations');
  
Specify the migration storage directory for L<Mojo::SimpleAuth> configuration file.
This attribute by default contains C<migrations>.

=head1 METHODS

L<Mojo::SimpleAuth> inherits all methods from
L<Mojo::Base> and implements the following new ones.

=head2 check_file_migration()

  $msa->check_file_migration();
  
Checking file migration on your application directory.

=head2 check_migration()

  $msa->check_migration();
  
Checking migration database storage

=head1 SEE ALSO

=over 2

=item * L<Mojolicious::Plugin::SimpleAuth>

=item * L<Mojo::SimpleAuth>

=item * L<Mojo::mysql>

=item * L<Mojo::Pg>

=item * L<Mojo::SQLite>

=item * L<Mojolicious::Guides>

=item * L<https://mojolicious.org>

=back

=cut

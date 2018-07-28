package Mojo::SimpleAuth;
use Mojo::Base -base;

use Carp 'croak';
use File::Spec::Functions 'file_name_is_absolute';
use Scalar::Util qw(blessed);
use Mojo::File qw(path);
use Mojo::Util qw(dumper);
use Mojo::Loader 'load_class';
use DBI;
use String::Random;
use CellBIS::SQL::Abstract;

# Attributes
has random => sub { String::Random->new };
has 'sth';
has 'via';
has 'dir';
has 'table_config';    # not yet implemented.

# Internal Attribute
has 'type';
has 'handler';
has 'migration_status' => 0;

sub check_file_migration {
  my $self = shift;

  my $backend        = $self->handler();
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

  my $backend = $self->handler();
  my $check   = $backend->check_table();
  unless ($check->{result} == 1) {
    croak "Can't create table database" unless $backend->create_table();
  }
  return $self;
}

sub prepare {
  my $self = shift;
  $self->{via} = 'db:sqlite';

  $self->{type} = $self->via =~ m/^db\:/ ? 'db' : 'api';
  $self->_for_handler();
  return $self;
}

sub _for_handler {
  my $self = shift;

  my $handler_via;
  my @param
    = $self->table_config
    ? (dir => $self->dir, %{$self->table_config})
    : (dir => $self->dir);

  my $for_handler = $self->_via_db();
  my $get_handler = $for_handler->{$self->via};
  $handler_via = $for_handler->{$self->via}(@param);
  $self->handler($handler_via);
  return $self;
}

sub _check_migration_file {
  my $self = shift;

  my $loc_file = $self->dir . $self->handler()->file_migration;
  if (-f $loc_file) {
    return $self unless $self->handler()->table()->{result};
  }
  else {
    my $content_file = $self->handler()->table_query();
    path($loc_file)->spurt($content_file);
    return $self unless $self->handler()->table()->{result};
  }
}

sub _via_db {
  my $self = shift;
  return {
    'db:sqlite' => sub {
      load_class 'Mojo::SimpleAuth::handler::sqlite';
      state $sqlite = Mojo::SimpleAuth::handler::sqlite->new(@_);
      $sqlite->prepare();
      return $sqlite;
    },
    'db:mysql' => sub {
      load_class 'Mojo::SimpleAuth::handler::mysql';
      state $mysql = Mojo::SimpleAuth::handler::mysql->new(@_);
    },
    'db:pg' => sub {
      load_class 'Mojo::SimpleAuth::handler::pg';
      state $pg = Mojo::SimpleAuth::handler::pg->new(@_);
    }
  };
}

sub _via_db_sqlite {
  load_class 'Mojo::SimpleAuth::handler::sqlite';
  state $sqlite = Mojo::SimpleAuth::handler::sqlite->new(@_);
}

sub _via_db_mysql {
  load_class 'Mojo::SimpleAuth::handler::mysql';
  state $mysql = Mojo::SimpleAuth::handler::mysql->new(@_);
}

sub _via_db_pg {
  load_class 'Mojo::SimpleAuth::handler::pg';
  state $pg = Mojo::SimpleAuth::handler::pg->new(@_);
}

1;

=encoding utf8

=head1 NAME

Mojo::SimpleAuth - Abstraction for L<Mojolicious::Plugin::SimpleAuth>

=head1 SYNOPSIS

  use Mojo::SimpleAuth;
  
  my $msa = Mojo::SimpleAuth->new({
    sth => 'Mojo::SQLite',
    via => 'db:sqlite',
    dir => 'migrations'
  });
  $msa->prepare();

=head1 DESCRIPTION

General abstraction for L<Mojolicious::Plugin:::SimpleAuth>.
By defaults store handler using L<Mojo::SQLite>

=head1 ATTRIBUTES

L<Mojo::SimpleAuth> inherits all attributes from
L<Mojo::Base> and implements the following new ones.

=head2 sth

  $msa->sth('Mojo::mysql');
  $msa->sth('Mojo::SQLite');
  $msa->sth('Mojo::Pg');
  
Specify of storage handler. Currently, available for L<Mojo::mysql>, L<Mojo::Pg>,
and L<Mojo::SQLite>. By default using L<Mojo::SQLite>.

=head2 via

  $msa->via;
  $msa->via('db:mysql');
  $msa->via('db:sqlite');
  $msa->via('db:pg');
  
Specify of handler via MariaDB/MySQL or SQLite or PostgreSQL.

=head2 dir

  $msa->dir;
  $msa->dir('migration');
  
Specify the migration storage directory for L<Mojo::SimpleAuth> configuration file.

=head1 METHODS

L<Mojo::SimpleAuth> inherits all methods from
L<Mojo::Base> and implements the following new ones.

=head2 prepare()

  $msa->prepare();
  
Setup storage handler.

=head2 check_file_migration()

  $msa->check_file_migration();
  
Checking file migration on your application directory.

=head2 check_migration()

  $msa->check_migration();
  
Checking migration database storage

=head1 AUTHOR

Achmad Yusri Afandi, C<yusrideb@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Achmad Yusri Afandi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut

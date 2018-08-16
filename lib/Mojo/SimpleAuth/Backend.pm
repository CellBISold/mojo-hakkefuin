package Mojo::SimpleAuth::Backend;
use Mojo::Base -base;

use Mojo::Loader 'load_class';

# Attributes
has 'sth';
has 'via';
has 'dir';
has 'table_config';    # not yet implemented.

# Internal Attributes
has 'type';
has 'result';

sub action {
  my $self = shift;

  $self->{type} = $self->via =~ m/^db\:/ ? 'db' : 'api';
  my $handler_via;
  my @param
    = $self->table_config
    ? (sth => $self->sth, dir => $self->dir, %{$self->table_config})
    : (sth => $self->sth, dir => $self->dir);

  my $for_handler = $self->_via_db();
  $handler_via = $for_handler->{$self->via}(@param);
  $self->result($handler_via);
  return $self;
}

sub _via_db {
  my $self = shift;
  return {
    'db:sqlite' => sub {
      load_class 'Mojo::SimpleAuth::Backend::sqlite';
      state $sqlite = Mojo::SimpleAuth::Backend::sqlite->new(@_);
      $sqlite->prepare();
      return $sqlite;
    },
    'db:mysql' => sub {
      load_class 'Mojo::SimpleAuth::Backend::mysql';
      state $mysql = Mojo::SimpleAuth::Backend::mysql->new(@_);
    },
    'db:pg' => sub {
      load_class 'Mojo::SimpleAuth::Backend::pg';
      state $pg = Mojo::SimpleAuth::Backend::pg->new(@_);
    }
  };
}

1;

=encoding utf8

=head1 NAME

Mojo::SimpleAuth::Backend - Backend Handler

=head1 DESCRIPTION

Backend handler for Mojo::SimpleAuth

=cut

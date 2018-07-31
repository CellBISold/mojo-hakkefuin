package Mojo::SimpleAuth::Handler;
use Mojo::Base -base;

use Mojo::Loader 'load_class';

# Attributes
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
    ? (dir => $self->dir, %{$self->table_config})
    : (dir => $self->dir);

  my $for_handler = $self->_via_db();
  $handler_via = $for_handler->{$self->via}(@param);
  $self->result($handler_via);
  return $self;
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

1;

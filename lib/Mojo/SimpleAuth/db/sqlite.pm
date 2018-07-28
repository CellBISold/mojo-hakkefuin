package Mojo::SimpleAuth::db::sqlite;
use Mojo::Base -base;

use Mojo::SQLite;
use CellBIS::Random;
use CellBIS::SQL::Abstract;

has 'dbh';
has 'mojo';
has random   => CellBIS::Random->new;
has abstract => CellBIS::SQL::Abstract->new;

has table_name     => 'mojo_simple_auth';
has id             => 'id_auth';
has identify       => 'identify';
has cookie         => 'cookie';
has create_date    => 'create_date';
has expire_date    => 'expire_date';
has status         => 'status';
has file_migration => 'mojo_simple_auth.db';

sub check_table {
  my $self = shift;

}

sub table {
  my $self        = shift;
  my $table_query = $self->table_query;

  my $result = $self->dbh->db->query($table_query);
  return $self unless $result->rows;

  return $result->rows;
}

sub table_query {
  my $self = shift;

  $self->abstract->create_table(
    $self->table_name,
    [
      $self->id,          $self->cookie, $self->create_date,
      $self->expire_date, $self->status
    ],
    {
      $self->id =>
        {type => {name => 'integer'}, is_primarykey => 1, is_autoincre => 1},
      $self->identify    => {type => {name => 'text'}},
      $self->cookie      => {type => {name => 'text'}},
      $self->create_date => {type => {name => 'datetime'}},
      $self->expire_date => {type => {name => 'datetime'}},
      $self->status      => {type => {name => 'integer'}},
    }
  );
}

1;

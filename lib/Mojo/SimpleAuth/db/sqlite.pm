package Mojo::SimpleAuth::db::sqlite;
use Mojo::Base -base;

use Scalar::Util 'blessed';
use Mojo::SQLite;
use CellBIS::Random;
use CellBIS::SQL::Abstract;

has 'dbh';
has 'dir';
has 'app';
has random   => 'CellBIS::Random';
has abstract => 'CellBIS::SQL::Abstract';

has table_name  => 'mojo_simple_auth';
has id          => 'id_auth';
has identify    => 'identify';
has cookie      => 'cookie';
has create_date => 'create_date';
has expire_date => 'expire_date';
has status      => 'status';

sub file_migration {
  my $self = shift;
  return $self->dir . '/msa_sqlite.sql';
}

sub file_db {
  my $self = shift;
  return 'sqlite:' . $self->dir . '/msa_sqlite.db';
}

sub prepare {
  my $self = shift;
  my $dbh  = Mojo::SQLite->new($self->file_db);
  $self->{dbh} = $dbh;
}

sub check_table {
  my $self = shift;

  my $result = {result => 0};
  my $query = "SELECT name
    FROM sqlite_master
    WHERE type='table'
      AND tbl_name='$self->table_name'
    ORDER BY name";
  if (my $dbh = $self->dbh->db->query($query)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub create_table {
  my $self        = shift;
  my $table_query = $self->table_query;

  my $result = $self->dbh->db->query($table_query);
  return $self unless $result->rows;

  return $result->rows;
}

sub table_query {
  my $self = shift;

  $self->abstract->new(db_type => 'sqlite')->create_table(
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

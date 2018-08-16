package Mojo::SimpleAuth::Handler::sqlite;
use Mojo::Base -base;

use Carp 'croak';
use Scalar::Util 'blessed';
use Mojo::SQLite;
use CellBIS::SQL::Abstract;

has 'dbh';
has 'dir';
has 'app';
has abstract =>
  sub { state $abstract = CellBIS::SQL::Abstract->new(db_type => 'sqlite') };

has table_name  => 'mojo_simple_auth';
has id          => 'id_auth';
has identify    => 'identify';
has cookie      => 'cookie';
has csrf        => 'csrf';
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
  my $q = "SELECT name
    FROM sqlite_master
    WHERE type='table'
      AND tbl_name='$self->table_name'
    ORDER BY name";
  if (my $dbh = $self->dbh->db->query($q)) {
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
      $self->id,   $self->identify,    $self->cookie,
      $self->csrf, $self->create_date, $self->expire_date,
      $self->status
    ],
    {
      $self->id =>
        {type => {name => 'integer'}, is_primarykey => 1, is_autoincre => 1},
      $self->identify    => {type => {name => 'text'}},
      $self->cookie      => {type => {name => 'text'}},
      $self->csrf        => {type => {name => 'text'}},
      $self->create_date => {type => {name => 'datetime'}},
      $self->expire_date => {type => {name => 'datetime'}},
      $self->status      => {type => {name => 'integer'}},
    }
  );
}

sub create {
  my ($self, $identify, $cookie, $csrf, $expires) = @_;

  my $datetime = 'datetime("now", "localtime", "' . $expires . ' seconds")';

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->insert(
    $self->table_name,
    [
      $self->identify,    $self->cookie,      $self->csrf,
      $self->create_date, $self->expire_date, $self->status
    ],
    [$identify, $cookie, $csrf, $datetime, $datetime, 0]
  );
  my $dbh = $self->dbh->db->query($q);
  $result->{result} = $dbh->rows if $dbh;
  return $result;
}

sub read {
  my ($self, $identify, $cookie) = @_;

  $identify //= '';
  $cookie   //= '';

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->select($self->table_name, [],
    {where => "$self->identify = '$identify' AND $self->cookie = '$cookie'"});
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub update {
  my ($self, $id, $cookie, $csrf) = @_;

  my $result = {result => 0, csrf => $csrf, cookie => $cookie};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update(
    $self->table_name,
    [$self->cookie, $self->csrf],
    [$cookie,       $csrf],
    where =>
      "$self->id = '$id' AND $self->expire_date > datetime('now','localtime')"
  );
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub update_csrf {
  my ($self, $id, $csrf) = @_;

  my $result = {result => 0, data => $csrf};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update($self->table_name, [$self->csrf], [$csrf],
    where =>
      "$self->id = '$id' AND $self->expire_date > datetime('now','localtime')");
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub update_cookie {
  my ($self, $id, $cookie) = @_;

  my $result = {result => 0, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->update($self->table_name, [$self->cookie], [$cookie],
    where =>
      "$self->id = '$id' AND $self->expire_date > datetime('now','localtime')");
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub delete {
  my ($self, $id, $cookie) = @_;

  my $result = {result => 0, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->delete($self->table_name, [],
    {where => $self->identify . " = '$id' AND $self->cookie = '$cookie'"});
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub check {
  my ($self, $id, $cookie) = @_;

  my $result = {result => 0, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->select(
    $self->table_name,
    [],
    {
      where => $self->identify
        . " = '$id' OR "
        . $self->cookie
        . " = '$cookie' AND "
        . $self->expire_date
        . " > datetime('now','localtime')",
      limit => 1
    }
  );
  my $rv = $self->dbh->db->query($q);
  if ($rv->rows) {
    $result->{result} = $rv->rows;
    $result->{data}   = {
      cookie   => $cookie,
      csrf     => $rv->hash->{$self->csrf},
      identify => $rv->hash->{$self->identify}
    };
  }
  return $result;
}

sub last_insert_id { shift->dbh->{private_mojo_last_insert_id} }

1;

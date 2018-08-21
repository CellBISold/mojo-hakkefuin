package Mojo::SimpleAuth::Backend::sqlite;
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
has cookie_lock => 'cookie_lock';
has lock        => 'lock';

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

  my $result = {result => 0, code => 400};
  my $q = $self->abstract->select('sqlite_master', ['name'],
    {where => 'type=\'table\' AND tbl_name=\'' . $self->table_name . '\''});

  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->hash;
    $result->{code}   = 200;
  }
  return $result;
}

sub create_table {
  my $self        = shift;
  my $table_query = $self->table_query;

  my $result = {result => 0, code => 400};

  if (my $dbh = $self->dbh->db->query($table_query)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub table_query {
  my $self = shift;

  $self->abstract->new(db_type => 'sqlite')->create_table(
    $self->table_name,
    [
      $self->id,          $self->identify,    $self->cookie,
      $self->csrf,        $self->create_date, $self->expire_date,
      $self->cookie_lock, $self->lock
    ],
    {
      $self->id =>
        {type => {name => 'integer'}, is_primarykey => 1, is_autoincre => 1},
      $self->identify    => {type => {name => 'text'}},
      $self->cookie      => {type => {name => 'text'}},
      $self->csrf        => {type => {name => 'text'}},
      $self->create_date => {type => {name => 'datetime'}},
      $self->expire_date => {type => {name => 'datetime'}},
      $self->cookie_lock =>
        {type => {name => 'text'}, default => '\'no-lock\'', is_null => 1},
      $self->lock => {type => {name => 'integer'}},
    }
  );
}

sub create {
  my ($self, $identify, $cookie, $csrf, $expires) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};

  my $now_time    = 'datetime("now", "localtime")';
  my $expire_time = 'datetime("now", "localtime", "' . $expires . ' seconds")';
  my $q           = $self->abstract->insert(
    $self->table_name,
    [
      $self->identify,    $self->cookie,      $self->csrf,
      $self->create_date, $self->expire_date, $self->cookie_lock,
      $self->lock
    ],
    [$identify, $cookie, $csrf, $now_time, $expire_time, $now_time, 0]
  );
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub read {
  my ($self, $identify, $cookie) = @_;

  $identify //= 'null';
  $cookie   //= 'null';

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};
  my $q = $self->abstract->select($self->table_name, [],
    {where => "$self->identify = '$identify' AND $self->cookie = '$cookie'"});
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = 1;
    $result->{code}   = 200;
    $result->{data}   = $dbh->hash;
  }
  return $result;
}

sub update {
  my ($self, $id, $cookie, $csrf) = @_;

  return {result => 0, code => 500, csrf => $csrf, cookie => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, csrf => $csrf, cookie => $cookie};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update(
    $self->table_name,
    [$self->cookie, $self->csrf],
    [$cookie,       $csrf],
    where => "$self->id = '$id' AND "
      . $self->expire_date
      . " > datetime('now','localtime')"
  );
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub update_csrf {
  my ($self, $id, $csrf) = @_;

  return {result => 0, code => 500, data => $csrf}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $csrf};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update($self->table_name, [$self->csrf], [$csrf],
        where => "$self->id = '$id' AND "
      . $self->expire_date
      . " > datetime('now','localtime')");
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub update_cookie {
  my ($self, $id, $cookie) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->update($self->table_name, [$self->cookie], [$cookie],
        where => "$self->id = '$id' AND "
      . $self->expire_date
      . " < datetime('now','localtime')");
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub delete {
  my ($self, $id, $cookie) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->delete($self->table_name,
    {where => $self->identify . " = ? AND " . $self->cookie . " = ?"});
  if (my $dbh = $self->dbh->db->query($q, $id, $cookie)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub check {
  my ($self, $id, $cookie) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie, code => '404'};
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
  if (my $rv = $self->dbh->db->query($q)) {
    my $r_data = $rv->hash;
    $result = {
      result => $rv->rows,
      code   => 200,
      data   => {
        cookie   => $cookie,
        csrf     => $r_data->{$self->csrf},
        identify => $r_data->{$self->identify}
      }
    };
  }
  return $result;
}

sub last_insert_id { shift->dbh->{private_mojo_last_insert_id} }

1;

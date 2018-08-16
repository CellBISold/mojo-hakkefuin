package Mojo::SimpleAuth::Backend::mysql;
use Mojo::Base -base;

use Carp 'croak';
use Scalar::Util 'blessed';
use CellBIS::SQL::Abstract;

has 'dbh' => sub { croak "Uninitialized Database Handler" unless shift->dbh };
has 'dir';
has 'app';
has abstract => sub { state $abstract = CellBIS::SQL::Abstract->new };

has table_name  => 'mojo_simple_auth';
has id          => 'id_auth';
has identify    => 'identify';
has cookie      => 'cookie';
has create_date => 'create_date';
has expire_date => 'expire_date';
has status      => 'status';

sub file_migration {
  my $self = shift;
  return $self->dir . '/msa_mariadb.sql';
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
      $self->id,          $self->identify,    $self->cookie,
      $self->create_date, $self->expire_date, $self->status
    ],
    {
      $self->id =>
        {type => {name => 'int'}, is_primarykey => 1, is_autoincre => 1},
      $self->identify    => {type => {name => 'text'}},
      $self->cookie      => {type => {name => 'text'}},
      $self->create_date => {type => {name => 'datetime'}},
      $self->expire_date => {type => {name => 'datetime'}},
      $self->status      => {type => {name => 'int'}},
    }
  );
}

sub create {
  my ($self, $identify, $cookie) = @_;

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->insert(
    $self->table_name,
    [
      $self->identify,    $self->cookie, $self->create_date,
      $self->expire_date, $self->status
    ],
    [$identify, $cookie, 'NOW()', 'NOW()', 0]
  );
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub read {
  my ($self, $identify, $cookie) = @_;

  $identify //= '';
  $cookie   //= '';

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->select($self->table_name, [],
    {where => "$self->identify = '$identify' OR $self->cookie = '$cookie'"});
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub update {
  my ($self, $id, $cookie) = @_;

  $id     //= 'null';
  $cookie //= 'null';

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->update($self->table_name, [$self->cookie], [$cookie],
    where => "$self->id = '$id' OR $self->cookie = '$cookie'");
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

sub delete {
  my ($self, $identify, $cookie) = @_;

  $identify //= '';
  $cookie   //= '';

  my $result = {result => 0, data => $cookie};
  my $q = $self->abstract->delete($self->table_name, [],
    {where => $self->identify . " = '$identify' AND $self->cookie = '$cookie'"}
  );
  if (my $dbh = $self->dbh->db->query($q)) {
    $result->{result} = $dbh->rows;
  }
  return $result;
}

1;

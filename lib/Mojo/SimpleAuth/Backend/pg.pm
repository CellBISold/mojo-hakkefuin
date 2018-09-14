package Mojo::SimpleAuth::Backend::pg;
use Mojo::Base 'Mojo::SimpleAuth::Backend';

use Mojo::Pg;
use Mojo::Util 'dumper';
use CellBIS::SQL::Abstract;

has 'pg';
has 'file_migration';
has abstract => sub { CellBIS::SQL::Abstract->new };

sub new {
  my $self = shift->SUPER::new(@_);

  say $self->dsn;
  $self->file_migration($self->dir . '/msa_pg.sql');
  $self->pg(Mojo::Pg->new($self->dsn()));

  return $self;
}

sub check_table {
  my $self = shift;

  my $result = {result => 0, code => 400};
  my $q = $self->abstract->select(
    'information_schema.tables',
    ['table_name'],
    {
      where =>
        'table_type=\'BASE TABLE\' AND table_schema=\'public\' AND table_name=\''
        . $self->table_name . '\''
    }
  );
  if (my $dbh = $self->pg->db->query($q)) {
    $result->{result} = $dbh->hash;
    $result->{code}   = 200;
  }
  return $result;
}

sub create_table {
  my $self        = shift;
  my $table_query = $self->table_query;

  my $result = {result => 0, code => 400};

  if (my $dbh = $self->pg->db->query($table_query)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub table_query {
  my $self = shift;

  my $data = '';
  $data .= 'CREATE TABLE IF NOT EXISTS ' . $self->table_name . '(';
  $data .= $self->id . ' bigserial NOT NULL PRIMARY KEY, ';
  $data .= $self->identify . ' TEXT NOT NULL, ';
  $data .= $self->cookie . ' TEXT NOT NULL, ';
  $data .= $self->csrf . ' TEXT NOT NULL, ';
  $data .= $self->create_date . ' TIMESTAMP NOT NULL, ';
  $data .= $self->expire_date . ' TIMESTAMP NOT NULL, ';
  $data .= $self->cookie_lock . ' TEXT DEFAULT \'no_lock\' NULL, ';
  $data .= $self->lock . ' INT NOT NULL)';
  return $data;
}

sub create {
  my ($self, $identify, $cookie, $csrf, $expires) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};

  my $msa_utils   = $self->msa_util->new;
  my $now_time    = $msa_utils->sql_datetime(0);
  my $expire_time = $msa_utils->sql_datetime($expires);
  if (
    my $dbh = $self->pg->db->insert(
      $self->table_name,
      {
        $self->identify    => $identify,
        $self->cookie      => $cookie,
        $self->csrf        => $csrf,
        $self->create_date => $now_time,
        $self->expire_date => $expire_time,
        $self->lock        => '0'
      }
    )
    )
  {
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
  my $q = $self->abstract->select(
    $self->table_name,
    [],
    {
          where => $self->identify
        . " = '$identify' AND "
        . $self->cookie
        . " = '$cookie'"
    }
  );
  if (my $dbh = $self->pg->db->query($q)) {
    $result->{result} = 1;
    $result->{code}   = 200;
    $result->{data}   = $dbh->hash;
  }
  return $result;
}

sub update {
  my ($self, $id, $cookie, $csrf) = @_;

  my $msa_utils = $self->msa_util->new;
  my $now_time  = $msa_utils->sql_datetime(0);

  return {result => 0, code => 500, csrf => $csrf, cookie => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, csrf => $csrf, cookie => $cookie};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update(
    $self->table_name,
    {$self->cookie, => $cookie, $self->csrf => $csrf},
    {
          where => '('
        . $self->id
        . " = '$id' OR "
        . $self->identify
        . " = '$id') AND "
        . $self->expire_date
        . " > '$now_time'"
    }
  );
  if (my $dbh = $self->pg->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub update_csrf {
  my ($self, $id, $csrf) = @_;

  my $msa_utils = $self->msa_util->new;
  my $now_time  = $msa_utils->sql_datetime(0);

  return {result => 0, code => 500, data => $csrf}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $csrf};
  return $result unless $id && $csrf;

  my $q = $self->abstract->update(
    $self->table_name,
    {$self->csrf => $csrf},
    {
          where => $self->id
        . " = '$id' AND "
        . $self->expire_date
        . " > '$now_time'"
    }
  );
  if (my $dbh = $self->pg->db->query($q)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub update_cookie {
  my ($self, $id, $cookie) = @_;

  my $msa_utils = $self->msa_util->new;
  my $now_time  = $msa_utils->sql_datetime(0);

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->update(
    $self->table_name,
    {$self->cookie => $cookie},
    {
          where => $self->id
        . " = '$id' AND "
        . $self->expire_date
        . " > '$now_time'"
    }
  );
  if (my $dbh = $self->pg->db->query($q)) {
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
  if (my $dbh = $self->pg->db->query($q, $id, $cookie)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub check {
  my ($self, $id, $cookie) = @_;

  my $msa_utils = $self->msa_util->new;
  my $now_time  = $msa_utils->sql_datetime(0);

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};
  return $result unless $id && $cookie;

  my $q = $self->abstract->select(
    $self->table_name,
    [],
    {
      where => '('
        . $self->identify
        . " = '$id' OR "
        . $self->cookie
        . " = '$cookie') AND "
        . $self->expire_date
        . " > '$now_time'",
      limit => 1
    }
  );
  if (my $rv = $self->pg->db->query($q)) {
    my $r_data = $rv->hash;
    $result = {
      result => 1,
      code   => 200,
      data   => {
        cookie   => $cookie,
        id       => $r_data->{$self->id},
        csrf     => $r_data->{$self->csrf},
        identify => $r_data->{$self->identify}
      }
    };
  }
  return $result;
}

sub empty_table {
  my $self = shift;
  my $result = {result => 0, code => 500, data => 'can\'t delete table'};

  if (my $dbh = $self->pg->db->query('DELETE FROM ' . $self->table_name)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
    $result->{data}   = '';
  }
  return $result;
}

sub drop_table {
  my $self = shift;
  my $result = {result => 0, code => 500, data => 'can\'t drop table'};

  if (my $dbh
    = $self->pg->db->query('DROP TABLE IF EXISTS ' . $self->table_name))
  {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
    $result->{data}   = '';
  }
  return $result;
}

1;

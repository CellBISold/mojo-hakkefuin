package Mojo::SimpleAuth::Backend::mysql;
use Mojo::Base 'Mojo::SimpleAuth::Backend';

use Mojo::mysql;
use CellBIS::SQL::Abstract;

has 'mysql';
has 'file_migration';
has abstract => sub { state $abstract = CellBIS::SQL::Abstract->new };

sub new {
  my $self = shift->SUPER::new(@_);

  $self->file_migration($self->dir . '/msa_mysql.sql');
  $self->mysql(Mojo::mysql->new($self->dsn()));

  return $self;
}

sub check_table {
  my $self = shift;

  my $result = {result => 0, code => 400};
  my $q = $self->abstract->select('information_schema.tables', ['table_name'],
    {where => 'table_name=\'' . $self->table_name . '\''});

  if (my $dbh = $self->mysql->db->query($q)) {
    $result->{result} = $dbh->hash;
    $result->{code}   = 200;
  }
  return $result;
}

sub create_table {
  my $self        = shift;
  my $table_query = $self->table_query;

  my $result = {result => 0, code => 400};

  if (my $dbh = $self->mysql->db->query($table_query)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub table_query {
  my $self = shift;

  $self->abstract->new(db_type => 'mysql')->create_table(
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
      $self->cookie_lock => {
        type      => {name => 'varchar', size => 100},
        'default' => '\'no_lock\'',
        is_null   => 1
      },
      $self->lock => {type => {name => 'int'}}
    }
  );
}

sub create {
  my ($self, $identify, $cookie, $csrf, $expires) = @_;

  return {result => 0, code => 500, data => $cookie}
    unless $self->check_table->{result};

  my $result = {result => 0, code => 400, data => $cookie};

  my $msa_utils   = $self->msa_util->new;
  my $now_time    = $msa_utils->sql_datetime(0);
  my $expire_time = $msa_utils->sql_datetime($expires);
  my $q           = $self->abstract->insert(
    $self->table_name,
    [
      $self->identify,    $self->cookie,      $self->csrf,
      $self->create_date, $self->expire_date, $self->cookie_lock,
      $self->lock
    ],
    [$identify, $cookie, $csrf, $now_time, $expire_time, $now_time, 0]
  );

  # warn $q;
  if (my $dbh = $self->mysql->db->query($q)) {
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
  if (my $dbh = $self->mysql->db->query($q)) {
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
  if (my $dbh = $self->mysql->db->query($q)) {
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
  if (my $dbh = $self->mysql->db->query($q)) {
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
  if (my $dbh = $self->mysql->db->query($q)) {
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
  if (my $dbh = $self->mysql->db->query($q, $id, $cookie)) {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
  }
  return $result;
}

sub check {
  my ($self, $id, $cookie) = @_;

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
        . " > NOW()",
      limit => 1
    }
  );
  if (my $rv = $self->mysql->db->query($q)) {
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

  if (my $dbh = $self->mysql->db->query('DELETE FROM ' . $self->table_name)) {
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
    = $self->mysql->db->query('DROP TABLE IF EXISTS ' . $self->table_name))
  {
    $result->{result} = $dbh->rows;
    $result->{code}   = 200;
    $result->{data}   = '';
  }
  return $result;
}

1;

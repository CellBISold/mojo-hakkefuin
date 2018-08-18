requires "Mojolicious"            => 0;
requires "Mojo::SQLite"           => 0;
requires "Scalar::Util"           => 0;
requires "CellBIS::Random"        => 0;
requires "CellBIS::SQL::Abstract" => "1.1";

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build"       => "0.28";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::Pod"               => "1.41";
  requires "Test::Pod::Coverage"     => "1.08";
};

feature 'all', 'Using MariaDB/MySQL and PostgreSQL as database backend', sub {
  requires 'Mojo::Pg'    => '4.08';
  requires 'Mojo::mysql' => '1.07';
};

feature 'pg', 'PostgreSQL database backend', sub {
  requires 'Mojo::Pg' => '4.08';
};

feature 'mysql', 'MariaDB/MySQL database backend', sub {
  requires 'Mojo::mysql' => '1.07';
};

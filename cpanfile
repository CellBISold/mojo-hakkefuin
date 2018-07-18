requires "DBD::mysql" => 0;
requires "DBD::SQLite" => 0;
requires "Mojolicious" => 0;
requires "Scalar::Util" => 0;
requires "CellBIS::SQL::Abstract" => 0;
requires "Moo" => 0;

on 'build' => sub {
  requires "Module::Build" => "0.28";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "Module::Build" => "0.28";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};

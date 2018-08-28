package Mojo::SimpleAuth::Utils;
use Mojo::Base -base;

use Mojo::Date;

sub sql_datetime {
  my ($self, $time_plus) = @_;
  $time_plus //= 0;
  my $epoch     = Mojo::Date->new(scalar localtime)->epoch;
  my $to_get_dt = Mojo::Date->new($epoch + $time_plus)->to_datetime;
  $to_get_dt =~ qr/^([0-9\-]+)\w([0-9\:]+)(.*)/;
  return $1 . ' ' . $2;
}

sub time_convert {
  my ($self, $abbr) = @_;

  # Reset shortening time
  $abbr //= '1h';
  $abbr =~ qr/^([\d.]+)(\w)/;

  # Set standard of time units
  my $minute = 60;
  my $hour   = 60 * 60;
  my $day    = 24 * $hour;
  my $week   = 7 * $day;
  my $month  = 30 * $day;
  my $year   = 12 * $month;

  # Calculate by time units.
  my $identifier;
  $identifier = int $1 * 1   if $2 eq 's';
  $identifier = $1 * $minute if $2 eq 'm';
  $identifier = $1 * $hour   if $2 eq 'h';
  $identifier = $1 * $day    if $2 eq 'd';
  $identifier = $1 * $week   if $2 eq 'w';
  $identifier = $1 * $month  if $2 eq 'M';
  $identifier = $1 * $year   if $2 eq 'y';
  return $identifier;
}

1;

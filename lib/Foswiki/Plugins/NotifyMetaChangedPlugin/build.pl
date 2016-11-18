#!/usr/bin/perl -w
use strict;
use warnings;

BEGIN {
  unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

package NotifyMetaChangedBuild;
our @ISA = qw(Foswiki::Contrib::Build);

sub new {
  my $class = shift;
  return bless($class->SUPER::new("NotifyMetaChangedPlugin"), $class);
}

sub target_build {
  my $this = shift;
  $this->SUPER::target_build();
}

package main;
my $build = new NotifyMetaChangedBuild();
$build->build($build->{target});

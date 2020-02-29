#!/usr/bin/perl
use v5.18;
use warnings;
use strict;
use diagnostics;

BEGIN { push @INC, qw| lib/ .|}
use Population;
use Individual;


my $target_filename = $ARGV[0];

Individual->init_alleles(100);
my $population = Population->new({
                                  target_image_filename => $target_filename,
                                  population_size => 60,
                                  bcm_ratio => '1:4:1'
                                 });

$population->generate_individuals();

my $i = 1;
while ($i++) {
  $population->create_images();
  my $fitness = $population->prep_next_generation();
  say "Gen $i Fitness: $fitness\n";
}

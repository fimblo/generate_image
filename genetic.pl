#!/usr/bin/perl
use v5.18;
use warnings;
use strict;
use diagnostics;

BEGIN { push @INC, qw| lib/ .|}
use Population;
use Individual;


my $target_filename = $ARGV[0];

Individual->init_alleles(20);
my $population = Population->new({
                                  target_image_filename => $target_filename,
                                  population_size => 60,
                                  bcm_ratio => '1:4:1'
                                 });

$population->generate_individuals();

my $i = 1;
while ($i++) {
  $population->create_images();
  my @survivors = @{$population->prep_next_generation()};
  $survivors[0]->save_to_disk(sprintf "%06d", $i);


  my (@fitness, @allele_count, $operations);
  for my $s (@survivors) {
    push @fitness, $s->fitness();
    push @allele_count, $s->number_of_alleles();
    $operations .= $s->previous_operation();
  }
  my $best_f = sprintf "%.8f", $fitness[0];
  my $avg_f = sprintf "%.8f", average(@fitness);
  my $stdev_f = sprintf "%.8f", stdev(@fitness);
  my $best_a = sprintf "%05d", $allele_count[0];
  my $avg_a = sprintf "%08.2f", average(@allele_count);
  my $stdev_a = sprintf "%08.2f", stdev(@allele_count);

  say "Gen $i: Fitness(B:$best_f A:$avg_f S:$stdev_f) Number of Alleles(B:$best_a A:$avg_a S:$stdev_a)";
  say $operations;
}



sub pad {
  my $val = shift;
  my $pad_size = 6;
  return '0'x ($pad_size - length($val));
}






sub average{
  my @data = @_;
  die("Empty array\n") unless @data;

  my $total = 0;
  $total += $_ for @data;

  return $total / @data;
}


sub stdev{
  my @data = @_;

  return 0 if (@data == 1);

  my $average = &average(@data);
  my $sqtotal = 0;
  for (@data) {
    $sqtotal += ($average - $_) ** 2;
  }
  my $std = ($sqtotal / (@data - 1)) ** 0.5;
  return $std;
}

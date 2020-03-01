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
Individual->max_alleles(800);

my $population = Population->new({
                                  target_image_filename => $target_filename,
                                  population_size => 60,
                                  bcm_ratio => '1:4:1'
                                 });

$population->generate_individuals();

my $i = 1;
my $prev_best = 1;
while () {
  $population->create_images();
  my @best_indivs = @{$population->prep_next_generation()};


  my (@fitness, @allele_count, $operations);
  for my $bi (@best_indivs) {
    push @fitness, $bi->fitness();
    push @allele_count, $bi->number_of_alleles();
    $operations .= $bi->previous_operation();
  }
  my $gen_i = sprintf "%4d", $i;
  my $best_f = sprintf "%.8f", $fitness[0];
  my $avg_f = sprintf "%.8f", average(@fitness);
  my $stdev_f = sprintf "%.8f", stdev(@fitness);
  my $best_a = sprintf "%5d", $allele_count[0];
  my $avg_a = sprintf "%8.2f", average(@allele_count);
  my $stdev_a = sprintf "%8.2f", stdev(@allele_count);

  say "Gen $gen_i: Fitness(B:$best_f A:$avg_f S:$stdev_f)";
  say "          Number of Alleles(B:$best_a A:$avg_a S:$stdev_a)";
  say "          $operations";

  if ($fitness[0] < $prev_best) {
    $best_indivs[0]->save_to_disk(sprintf "%06d", $i);
    $prev_best = $fitness[0];
  }

  $i++;
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

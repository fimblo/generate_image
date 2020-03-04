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


# Main loop
my $i = 1;
my $prev_best = 1;
my $curr_best = 1;
while ($curr_best > 0.01) {
  $population->create_images();
  my @best_indivs = @{$population->prep_next_generation()};

  $curr_best = &show_status_update([@best_indivs]);

  if ($curr_best < $prev_best) {
    $best_indivs[0]->save_to_disk(sprintf "%06d", $i);
    $prev_best = $curr_best;
  }

  $i++;
}




sub show_status_update {
  my $arg = shift;
  my @best_indivs = @$arg;

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

  my $prev_f;
  if ($prev_best - $fitness[0] < 0.000000000001) {
    $prev_f = 0;
  } else {
    $prev_f = sprintf "%.8f", $fitness[0] - $prev_best;
  }

  my @top_ids = map {$_->id()} @best_indivs[0..2];
  my $top_id_str = join ', ', @top_ids;

  say "Gen $gen_i: Top three individuals ($top_id_str) Map of Operations: ($operations) ";
  say "          Fitness (B:$best_f A:$avg_f S:$stdev_f)";
  say "          Fitness diff for best individual: $prev_f";
  say "          Number of Alleles (B:$best_a A:$avg_a S:$stdev_a)";


  return $fitness[0];
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

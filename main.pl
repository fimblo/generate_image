#!/usr/bin/perl
use v5.28.1;
use warnings;
use strict;
use Data::Dumper;

BEGIN { push @INC, 'lib/'}

use Genes qw/
  &set_max_population
  &generate_genes
  &create_images
  &get_comparisons_to_source
  &get_best_gene_indices
  &get_best_distance
  &mutate_population
  &mate_population
  &save_image
  &save_gene
  /;
# --------------------------------------------------


my $SOURCE_IMAGE_FILENAME = 'anna.png';
my $iterations = 1;
my $pool = 10;

# Create an array of genes
&set_max_population($pool);
my $population = &generate_genes();

for (my $i = 0; $i < $iterations; $i++) {

  # map of images, key is index in $population
  my $images = &create_images($population);

  # get indices of best genes in population arref
  my $best_indices = &get_best_gene_indices($images, $SOURCE_IMAGE_FILENAME);
  my @best_genes = @{$population}[@$best_indices];

  # get an array of mutants
  my $mutants = &mutate_population(\@best_genes);

  # get an array of kids
  my $children = &mate_population(\@best_genes);


  # prep for next round
  $population = [ @best_genes, @$children, @$mutants];

  # output status for user
  my $b_pop = scalar @best_genes;
  my $m_pop = scalar @$mutants;
  my $c_pop = scalar @$children;
  my $best_distance = &get_best_distance();
  print "Round $i:\tSurvivors($b_pop) Children($c_pop) Mutants($m_pop)\n";
  print "Best distance from this round: $best_distance\n";


  my $best_image_so_far = $images->{$best_indices->[0]};
  &save_image($best_image_so_far, "image_$i.png");
  &save_gene(
    { distance => $best_distance, gene => \@{$best_genes[0]} },
    "gene_$i.txt");
}

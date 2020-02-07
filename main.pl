#!/usr/bin/perl
# --------------------------------------------------
# This script generates an image.. blah blah
#
# Mattias Jansson <fimblo@yanson.org>
# --------------------------------------------------

use v5.28.1;
use warnings;
use strict;
use Getopt::Long;
use File::Basename;

BEGIN { push @INC, 'lib/'}

use Genes qw/
  &set_max_population
  &set_survival_percent
  &set_mate_percent
  &set_mutate_percent
  &generate_genes
  &create_images
  &get_comparisons_to_target
  &get_best_gene_indices
  &set_best_distance
  &mutate_population
  &mate_population
  &save_image
  &save_gene
  /;

# --------------------------------------------------
# Help message
my $basename = basename($0);
my $helptext = << "EOM";
Generate an image which, over generations, approximates target image.

Usage: $basename -t <target-file> [-h -s <seed> -i <iter> -p <pool>]

       -t <target-file>  # image to approximate

Optional params
       -s <seed>         # start first iteration with this seed file.
       -i <iter>         # number of iterations. (default 10)
       -p <pool>         # size of gene pool. (default 10)
       -h                # This help message
EOM

# --------------------------------------------------
# Go through commandline options
my $target_image_filename = undef;
my $seed_file = undef;
my $iterations = 10;
my $pool = 10;
my $help;

GetOptions(
  "target-file=s" => \$target_image_filename,
  "seed=s"       => \$seed_file,
  "iterations=i" => \$iterations,
  "pool=i"       => \$pool,
  "help"         => \$help,
  ) or die ("bad commandline args\n");

if (! $target_image_filename or $help ) {
  print $helptext;
  exit 0;
}
# --------------------------------------------------

# Create an array of genes
&set_max_population($pool);
&set_survival_percent(0.2);
&set_mate_percent(0.4);
&set_mutate_percent(0.4);
my $population = &generate_genes($seed_file); # if undef, starts from scratch.

my $prev_best_distance = 1;
for (my $i = 0; $i < $iterations; $i++) {

  # Create images from population
  # returns a map of images, key is index in $population
  my $images = &create_images($population);

  # get indices of best genes in population arref
  my $best_indices = &get_best_gene_indices($images, $target_image_filename);

  # Prep the next generation of genes
  my @best_genes = @{$population}[@$best_indices];
  my $mutants = &mutate_population(\@best_genes);
  my $children = &mate_population(\@best_genes);
  $population = [ @best_genes, @$children, @$mutants];




  # --------------------------------------------------
  # Output status for user
  my $b_pop = scalar @best_genes;
  my $m_pop = scalar @$mutants;
  my $c_pop = scalar @$children;
  my $best_distance = &set_best_distance();
  my $distance_diff = $prev_best_distance - $best_distance;
  print "Round $i:\tSurvivors($b_pop) Children($c_pop) Mutants($m_pop)\n";
  print "Best distance: $best_distance\t(diff: $distance_diff)\n";
  $prev_best_distance = $best_distance;


  # --------------------------------------------------
  # Save the best image and corresponding gene
  my $best_image_so_far = $images->{$best_indices->[0]};
  mkdir "$$" unless ( -d "$$" );
  &save_image($best_image_so_far, "$$/image_$i.png");
  &save_gene(
    { distance => $best_distance,
      gene => \@{$best_genes[0]},
    },
    "$$/gene_$i.txt");
}

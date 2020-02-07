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
  -r <ratio>        # population ratio for next generation.
  # Survivor:Children:Mutants (default 2:4:4)
  -p <pool>         # size of gene pool. (default 10)
  -h                # This help message
EOM

  # --------------------------------------------------
  # Go through commandline options
my $target_image_filename = undef;
my $seed_file = undef;
my $iterations = 10;
my $pool = 10;
my $ratio = "2:4:4";
my $help;

GetOptions(
  "target-file=s" => \$target_image_filename,
  "seed=s"       => \$seed_file,
  "iterations=i" => \$iterations,
  "pool=i"       => \$pool,
  "ratio=s"      => \$ratio,
  "help"         => \$help,
  ) or die ("bad commandline args\n");

if (! $target_image_filename or $help ) {
  print $helptext;
  exit 0;
}
# --------------------------------------------------

&set_max_population($pool);

unless ($ratio =~ m/^(\d+):(\d+):(\d+)$/) {
  print << "EOM";
  Ratio should be specified as three integers separated by colons.

  For example, in the command below the -r param tells the program that
  for every two survivors, you want four children and five mutants in
  the next generation.

  $basename -t $target_image_filename -r 2:4:5
EOM
  exit 1;
}
my ($s,$c,$m) = ($1, $2, $3); # capture digits from regex above
my $tot = $s+$c+$m;
&set_survival_percent($s/$tot);
&set_mate_percent($c/$tot);
&set_mutate_percent($m/$tot);


# Create an array of genes
my $population = &generate_genes($seed_file); # if undef, starts from scratch.

my $prev_best_distance = 1;
my $prev_distance_diff = 1;
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




  # --------------------------------------------------
  # Output status for user
  my $best_distance = &set_best_distance();
  my $distance_diff = $prev_best_distance - $best_distance;
  my $b_pop = scalar @best_genes;
  my $m_pop = scalar @$mutants;
  my $c_pop = scalar @$children;
  my ($max, $avg, $stdev) = &get_gene_len_stats(\@best_genes);
  print "Round $i: (S:$b_pop C:$c_pop M:$m_pop) (Gene length Max:$max Avg:$avg StdDev:$stdev)\n";
  print "Best distance: $best_distance\t(diff: $distance_diff)\n";


  # --------------------------------------------------
  # If we have no real progress for two rounds, then repopulate
  # population using the best 5 genes, all mutants
  if (($prev_distance_diff + $distance_diff) < 0.0001) {
    print "There was no real change for two cycles. Shaking things up a bit.\n";
    my $prev = $i-1;
    $population = &generate_genes("$$/gene_$prev.txt");
  }
  else {
    $population = [ @best_genes, @$children, @$mutants];
  }
  $prev_best_distance = $best_distance;
  $prev_distance_diff = $distance_diff;


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

sub get_gene_len_stats() {
  my $genes = shift;

  my ($avg, $stdev, $max) = (0,0,0);
  my @data;

  for my $g (@$genes) {
    my $d = scalar @$g;
    push @data, $d;

    if ($d > $max) { $max = $d };
  }

  $avg = sprintf("%.2f", &average(@data));
  $stdev = sprintf("%.2f", &stdev(@data));

  return ($max, $avg, $stdev);
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

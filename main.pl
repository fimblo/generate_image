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
  &set_bgimage
  &set_gene_start_length
  &set_max_population
  &set_max_radius
  &set_min_radius
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

 Usage: $basename -t <target-file> [optional params]

  -t <target-file>  # image to approximate

  Optional params
  -s <seed>         # start first iteration with this seed file.
  -i <iter>         # number of iterations. (default 10)
  -r <ratio>        # population ratio for next generation.
                    # Survivor:Children:Mutants (default 1:2:1)
  -p <pool>         # size of gene pool. (default 10)
  -b <bgimage>      # Start with this image as background (default: white)
  -h                # This help message
EOM

  # --------------------------------------------------
  # Go through commandline options
my $target_image_filename = undef;
my $seed_file = undef;
my $iterations = 10;
my $pool = 10;
my $bgimage = 'canvas:white';
my $ratio = "1:2:1";
my $help;

GetOptions(
  "target-file=s" => \$target_image_filename,
  "seed=s"       => \$seed_file,
  "iterations=i" => \$iterations,
  "pool=i"       => \$pool,
  "bgimage=s"    => \$bgimage,
  "ratio=s"      => \$ratio,
  "help"         => \$help,
  ) or die ("bad commandline args\n");

if (! $target_image_filename or $help ) {
  print $helptext;
  exit 0;
}
# --------------------------------------------------

&set_bgimage($bgimage);

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
&set_max_population($pool);
&set_min_radius(300);
&set_max_radius(500);
&set_gene_start_length(10);

# Create an array of genes
my $population = &generate_genes($seed_file); # if undef, starts from scratch.

my $prev_best_distance = 1;
my @distance_history = qw/1 1 1 1 1/;
my $radius_counter = 0;
my $zombie = 0;
my $DISTANCE_DIFF_THRESHOLD_XL    = 0.001;
my $DISTANCE_DIFF_THRESHOLD_L     = 0.0001;
my $DISTANCE_DIFF_THRESHOLD_M     = 0.00001;
my $DISTANCE_DIFF_THRESHOLD_S     = 0.000001;
my $DISTANCE_DIFF_THRESHOLD_TINY  = 0.0000001;
my $distance_threshold = $DISTANCE_DIFF_THRESHOLD_XL;

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
  my $best_distance = &set_best_distance();
  my $min_rad = &set_min_radius();
  my $max_rad = &set_max_radius();
  my $distance_diff = $prev_best_distance - $best_distance;
  my $b_pop = scalar @best_genes;
  my $m_pop = scalar @$mutants;
  my $c_pop = scalar @$children;
  my ($max, $avg, $stdev) = &get_gene_len_stats(\@best_genes);
  print "Round $i: (S:$b_pop C:$c_pop M:$m_pop) (Gene length Max:$max Avg:$avg StdDev:$stdev)\n";
  print "Circle Radius (Min: $min_rad) (Max: $max_rad)\n";
  print "Best distance: $best_distance\t(diff: $distance_diff)\n";


  # --------------------------------------------------
  # If we have no real progress for five rounds, then apply
  # one of the following strategies for the next generation.
  #   - Change radius smaller (looping to big over time)
  #
  #
  # Exception: if there is a total of less than six rounds
  #            we make no changes to strategy.
  push @distance_history, $distance_diff;
  shift @distance_history if (@distance_history > 5);
  my $sum = 0; $sum += $_ for @distance_history;
   

  # If zombie mode is on, turn it off after resetting original
  # survivor/mate/mutate ratios.
  if ($zombie == 1) {
    print "====== Zombie mode OFF ======\n";
    &set_survival_percent($s/$tot);
    &set_mate_percent($c/$tot);
    &set_mutate_percent($m/$tot);
    $zombie = 0;
  }

  # Check if we want to shake stuff up a bit.
  if ($iterations > 5 and $sum < $distance_threshold) {
    print "There was no real change for 5 cycles. Shaking things up a bit.\n";

    if ($radius_counter == 0) { # x-large. Go to large
      print "Changing circle size XL->L\n";
      &set_min_radius(150);
      &set_max_radius(300);
      $distance_threshold = $DISTANCE_DIFF_THRESHOLD_L;
    }
    elsif ($radius_counter == 1) { # large. go to medium
      print "Changing circle size L->M\n";
      &set_min_radius(50);
      &set_max_radius(200);
      $distance_threshold = $DISTANCE_DIFF_THRESHOLD_M;
    }
    elsif ($radius_counter == 2) { # medium. go to small
      print "Changing circle size M->S\n";
      &set_min_radius(5);
      &set_max_radius(50);
      $distance_threshold = $DISTANCE_DIFF_THRESHOLD_S;
    }
    elsif ($radius_counter == 3) { # small. go to tiny
      print "Changing circle size S->tiny\n";
      &set_min_radius(2);
      &set_max_radius(25);
      $distance_threshold = $DISTANCE_DIFF_THRESHOLD_TINY;
    }
    elsif ($radius_counter == 3) { # tiny. go to XL
      print "Changing circle size tiny->XL\n";
      &set_min_radius(300);
      &set_max_radius(500);
      $distance_threshold = $DISTANCE_DIFF_THRESHOLD_XL;
    }
    else {
      die "wtf you shouldn't come here.";
    }


    print "====== Zombie mode ON ======\n";
    &set_survival_percent(0.1);
    &set_mate_percent(0.01);
    &set_mutate_percent(0.9);
    $zombie = 1;
    

    $radius_counter = ($radius_counter + 1) % 4;
    @distance_history = (1);
  }

  $prev_best_distance = $best_distance;



  # --------------------------------------------------
  # Save the best image and corresponding gene
  my $pad_size = 6;
  my $padding = '0'x ($pad_size - length($i));
  my $best_image_so_far = $images->{$best_indices->[0]};
  mkdir "output" unless ( -d "output" );
  mkdir "output/$$" unless ( -d "output/$$" );
  &save_image($best_image_so_far, "output/$$/image_${padding}${i}.png");
  &save_gene(
    { distance => $best_distance,
      gene => \@best_genes },
    "output/$$/gene_${padding}${i}.txt");
}
print "\nOutput saved to output/$$\n";


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

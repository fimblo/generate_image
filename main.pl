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
  &bgimage
  &gene_start_length
  &max_population
  &max_radius
  &min_radius
  &best_distance
  &survival_percent
  &mate_percent
  &mutate_percent
  &recursive_mutation_percent
  &generate_genes
  &create_images
  &get_comparisons_to_target
  &get_best_gene_indices
  &mutate_population
  &mate_population
  &save_image
  &save_gene
  &diversify_population
  /;

# --------------------------------------------------
# Constants and such

# Strategy stuff.
my $strategies = { X => [200, 400],
                   L => [100, 200],
                   M => [50, 100],
                   S => [25, 50],
                   T => [2, 25],
};
my $l_map  = {L=>'0', M=>'1', S=>'2', T=>'3', X=>'4'};
my $s_map  = {0=>'L', 1=>'M', 2=>'S', 3=>'T', 4=>'X'};
my $s_name = {0=>'Large', 1=>'Medium', 2=>'Small', 3=>'Tiny', 4=>'eXtra large'};

my $DISTANCE_DIFF_THRESHOLD = { X => 0.001,
                                L => 0.0001,
                                M => 0.00001,
                                S => 0.000001,
                                T => 0.0000001,
};
my $distance_threshold = 0;         # not a constant. oh well.

my $DEFAULT_BGIMAGE  = 'canvas:white';
my $DEFAULT_STRATEGY = 'X';




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
  -S <strategy>     # Size of circles. Can be X,L,M,S,T. (default: X)
  -h                # This help message
EOM

# --------------------------------------------------
# Go through commandline options
my $target_image_filename = undef;
my $seed_file = undef;
my $iterations = 10;
my $pool = 10;
my $bgimage = undef;
my $strategy = undef;
my $ratio = "1:2:1";
my $help;

GetOptions(
  "target-file=s" => \$target_image_filename,
  "seed=s"        => \$seed_file,
  "iterations=i"  => \$iterations,
  "pool=i"        => \$pool,
  "bgimage=s"     => \$bgimage,
  "Strategy=s"    => \$strategy,
  "ratio=s"       => \$ratio,
  "help"          => \$help,
  ) or die ("bad commandline args\n");

# target image is mandatory
if (! $target_image_filename or $help ) {
  print $helptext;
  exit 0;
}

# deal with background option
$bgimage = $DEFAULT_BGIMAGE unless $bgimage;
&bgimage($bgimage);

# do we want to have another start strategy?
if ($strategy) {
  die "Legal strategies is one of X, L, M, S, or T."
    unless (exists $strategies->{$strategy});
}
else {
  $strategy = $DEFAULT_STRATEGY;
}
$distance_threshold = &radius_strategy($strategy);
my $ui_radius = $strategy . ' ';



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
&survival_percent($s/$tot);
&mate_percent($c/$tot);
&mutate_percent($m/$tot);
&max_population($pool);


# ==================================================
# MAIN PROGRAM STARTS HERE

# Giving the main loop a sense of history
my $prev_best_distance = 1;     
my @short_distance_history = qw/1 1 1 1 1/;
my @long_distance_history = qw/1 1 1 1 1 1 1 1 1/;
my $radius_counter = $l_map->{$strategy};
my $zombie = 0;


# Initial settings for the genes
&gene_start_length(10);

# Let's seed the population and get started.
my $population = &generate_genes($seed_file); # if undef, starts from scratch.


# --------------------------------------------------
# Main loop.

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
  my $best_distance = &best_distance();
  my $min_rad = &min_radius();
  my $max_rad = &max_radius();
  my $distance_diff = $prev_best_distance - $best_distance;
  my $b_pop = scalar @best_genes;
  my $m_pop = scalar @$mutants;
  my $c_pop = scalar @$children;
  my ($max, $avg, $stdev) = &get_gene_len_stats(\@best_genes);
  print $ui_radius . "Round $i: (S:$b_pop C:$c_pop M:$m_pop) (Gene length Max:$max Avg:$avg StdDev:$stdev)\n";
  print $ui_radius . "Circle Radius (Min: $min_rad) (Max: $max_rad)\n";
  print $ui_radius . "Best distance: $best_distance\t(diff: $distance_diff)\n";



  # If zombie mode is on, turn it off after resetting original
  # survivor/mate/mutate ratios.
  if ($zombie == 1) {
    print "   ====== Turning Zombie mode OFF ======\n";
    &mate_percent($c/$tot);
    &mutate_percent($m/$tot);
    &recursive_mutation_percent(0.1);
    $zombie = 0;
  }


  # --------------------------------------------------

  # If we have no real progress for five rounds, then change
  # strategies (assuming there are enough rounds total).
  #
  # Currently the change in strategy available is to change the radius
  # of the circles. If they are large, make them smaller. If they are
  # tiny, make them huge.
  #
   
  push @long_distance_history, $distance_diff;
  shift @long_distance_history if (@long_distance_history > 9);
  my $lsum = 0; $lsum += $_ for @long_distance_history;

  if ($iterations > 5 and $lsum < $DISTANCE_DIFF_THRESHOLD->{'S'}) {
    print "\nThere was no real change for 11 cycles. Time to diversify the population.\n";
    &min_radius(2);
    &max_radius(100);

    my $new_pop = &diversify_population(\@best_genes, $target_image_filename);
    my $mutants = &mutate_population($new_pop);
    my $children = &mate_population($new_pop);
    $population = [ @$new_pop, @$children, @$mutants];

    $distance_threshold = &radius_strategy('S');
    $radius_counter = $l_map->{'S'};
    $ui_radius = $s_map->{$radius_counter} . ' ';

    @long_distance_history = (1);
    @short_distance_history = (1);
  }


  push @short_distance_history, $distance_diff;
  shift @short_distance_history if (@short_distance_history > 5);
  my $ssum = 0; $ssum += $_ for @short_distance_history;

  if ($iterations > 5 and $ssum < $distance_threshold) {
    print "\nThere was no real change for 5 cycles. Shaking things up a bit.\n";

    $ui_radius = $s_map->{$radius_counter} . ' ';
    $distance_threshold = &radius_strategy($s_map->{$radius_counter});
    print "Radius is now ". $s_name->{$radius_counter} . "\n";
    $radius_counter = ($radius_counter + 1) % 4;

    print "   ====== Turning zombie mode ON ======\n";
    &mate_percent(0.01);
    &mutate_percent(0.9);
    &recursive_mutation_percent(0.4);
    $zombie = 1;

    @short_distance_history = (1);
  }
  $prev_best_distance = $best_distance;



  # --------------------------------------------------
  # Save the best image and corresponding gene
  my $pad_size = 6;
  my $padding = '0'x ($pad_size - length($i));
  my $best_image_so_far = $images->{$best_indices->[0]};
  mkdir "output" unless ( -d "output" );
  mkdir "output/$$" unless ( -d "output/$$" );

  if ($distance_diff != 0) {
    &save_image($best_image_so_far, "output/$$/image_${padding}${i}.png");
  }
  &save_gene(
    { distance => $best_distance,
      gene => \@best_genes },
    "output/$$/gene_${padding}${i}.txt");
}
print "\nOutput saved to output/$$\n";



# --------------------------------------------------
# extra subs


sub radius_strategy() {
  my $new_strategy = shift ; # L,M,S,T,X
  my $r = $strategies->{$new_strategy};
  &min_radius($r->[0]);
  &max_radius($r->[1]);
  return $DISTANCE_DIFF_THRESHOLD->{$new_strategy};
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

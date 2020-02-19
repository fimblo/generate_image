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
use sigtrap qw(handler my_signal_handler normal-signals
               stack-trace error-signals);



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
  &scrub_gene
  &datetime
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
my $radius_strategy_limit = 4;
my $l_map  = {M=>'0', S=>'1', T=>'2', X=>'3', L=>'4'};
my $s_map  = {0=>'M', 1=>'S', 2=>'T', 3=>'X', 4=>'L'};
my $s_name = {0=>'Medium', 1=>'Small', 2=>'Tiny', 3=>'eXtra large', 4=>'Large'};

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
  -h                # This help message
EOM

# --------------------------------------------------
# Go through commandline options
my $target_image_filename = undef;
my $seed_file = undef;
my $iterations = 10;
my $pool = 10;
my $bgimage = undef;
my $ratio = "1:2:1";
my $help;

GetOptions(
  "target-file=s" => \$target_image_filename,
  "seed=s"        => \$seed_file,
  "iterations=i"  => \$iterations,
  "pool=i"        => \$pool,
  "bgimage=s"     => \$bgimage,
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

# Set initial strategy
my $strategy = $DEFAULT_STRATEGY;
$distance_threshold = &radius_strategy($strategy);
my $radius_counter = $l_map->{$strategy};
my $ui_radius = $strategy;

# Initial settings for the genes
&gene_start_length(10);

# Let's seed the population and get started.
my $population = &generate_genes($seed_file); # if undef, starts from scratch.

# Giving the main loop a sense of history
my $prev_best_distance = &best_distance;
my $prev_best_image;
my @distance_history = qw/1/;
my $inner_cnt = 0;
my $outer_cnt = 0;
my $lsum = 1;
my $has_changed = 0;

# --------------------------------------------------
# Outer loop
print &datetime . " Starting...\n";
while (1) {

  my @best_genes;

  # loop till little diff for some rounds (number depends on strategy level)
  until ($lsum < $distance_threshold) {

    # returns a map of images, key is index in $population
    my $images = &create_images($population);

    # get indices of best genes in population arref
    my $best_indices = &get_best_gene_indices($images, $target_image_filename);

    # Prep the next generation of genes
    @best_genes = @{$population}[@$best_indices];
    my $mutants = &mutate_population(\@best_genes);
    my $children = &mate_population(\@best_genes);
    $population = [ @best_genes, @$children, @$mutants];

    # --------------------------------------------------
    # Output status for user
    my $best_distance = &best_distance();
    my $distance_diff = $prev_best_distance - $best_distance;
    $distance_diff = 0 if (abs($distance_diff) < 0.0000000000000002);
    &status_to_user({ distance_diff  => $distance_diff,
                      best_genes  => \@best_genes,
                      mutant_population  => scalar @$mutants,
                      child_population  => scalar @$children });


    # --------------------------------------------------
    # Save the best image and corresponding gene
    my $pad_size = 6;
    my $padding = '0'x ($pad_size - length($inner_cnt));
    my $best_image_so_far = $images->{$best_indices->[0]};
    mkdir "output" unless ( -d "output" );
    mkdir "output/$$" unless ( -d "output/$$" );


    # Save image and genes as files
    if ($distance_diff != 0) { # save only if there is progress
      &save_image($best_image_so_far, "output/$$/image_${padding}${inner_cnt}.png");
      if ($prev_best_image) {
        my $comparison = $best_image_so_far->Compare(image=>$prev_best_image, metric=>'mae');
        &save_image($comparison, "output/$$/z_comparison.png");
      }
      $prev_best_image = $best_image_so_far;
      $has_changed = 1;         # mark that a change has happened
    }
    &save_gene(
               { distance => $best_distance,
                 gene => \@best_genes },
               "output/$$/gene_${padding}${inner_cnt}.txt");


    # --------------------------------------------------
    # Prep for next cycle

    # update history
    push @distance_history, $distance_diff;
    shift @distance_history if (@distance_history > 15);
    $lsum = 0; $lsum += $_ for @distance_history;
    $prev_best_distance = $best_distance;
    $inner_cnt++;
  }

  # scrub
  if ($has_changed) {
    print &datetime . " Scrubbing dead alleles from population.\n";
    my @scrubbed_genes;
    for my $g (@best_genes) {
      my $scrubbed = &scrub_gene($g, $target_image_filename);
      push @scrubbed_genes, $scrubbed;
    }
    $population = \@scrubbed_genes;
    $has_changed = 0;         # reset the flag
  }


  # diversify once every 20 outer cycles
  if ($outer_cnt > 20) {
    print &datetime . " Diversifying population.\n";
    $population = &diversify_population($population, $target_image_filename, 3);
    $outer_cnt = -1;            # since it's incremented at the end of loop
  }

  # change to next radius (X->L->(M->S->T))
  $radius_counter++;
  if ($radius_counter > $radius_strategy_limit) {
    $radius_counter = 0;
    $radius_strategy_limit = 2;
  }
  print &datetime . " Changing radius to " .  $s_name->{$radius_counter} . "\n";
  $distance_threshold =  &radius_strategy( $s_map->{$radius_counter} );
  $ui_radius = $s_map->{$radius_counter};

  # prep for next cycle
  @distance_history = qw/1/;
  $lsum = 1;
  $outer_cnt++;
}



# --------------------------------------------------
# extra subs

sub status_to_user {
  my $arg = shift;
  my @best_genes = @{$arg->{best_genes}};
  my $best_distance = &best_distance();
  my $distance_diff = $arg->{distance_diff};
  my $b_pop = scalar @best_genes;
  my $m_pop = $arg->{mutant_population};
  my $c_pop = $arg->{child_population};
  my ($max, $avg, $stdev) = &get_gene_len_stats(\@best_genes);
  print &datetime . ' ' . $ui_radius . " Round $inner_cnt: (S:$b_pop C:$c_pop M:$m_pop) (Gene length Max:$max Avg:$avg StdDev:$stdev)\n";
  print &datetime . ' ' . $ui_radius . " Best distance: $best_distance\t(diff: $distance_diff)\n";
}


sub radius_strategy() {
  my $new_strategy = shift ; # X,L,M,S,T
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

sub my_signal_handler {
  print "\n\nOutput saved to 'output/$$'.\n";
  die "Signal caught: '$!'" if $!;
  exit 0;
}

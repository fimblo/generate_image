#!/usr/bin/perl
use v5.18;
use warnings;
use strict;
use diagnostics;
use Term::ANSIColor;

BEGIN { push @INC, qw| lib/ .|}
use Population;
use Individual;

# --------------------------------------------------
# Handle commandline arguments
my $target_filename = $ARGV[0];
die "file '$target_filename' not found" unless -e $target_filename;
my $project_name = $ARGV[1] || $$;


# --------------------------------------------------
# Set things up
Individual->init_num_objects(20);
Individual->max_num_objects(800);


# --------------------------------------------------
# Create a population and generate the individuals
my $population = Population->new({
                                  target_image_filename => $target_filename,
                                  population_size => 60,
                                  bcm_ratio => '1:4:1'
                                 });
$population->generate_individuals();


# --------------------------------------------------
# Repeat the below until the population has an individual which is
# "good enough"
my ($i, $prev_best, $curr_best) = (1,1,1);
while ($curr_best > 0.01) {

  # --------------------------------------------------
  # Create images which reflect the individuals
  $population->create_images();

  # --------------------------------------------------
  # Prepare the next generation
  # - Mate the best individuals
  # - Mutate the best individuals
  #
  # Create a new population with the best survivors, children and
  # mutants.
  my $retval = $population->prep_next_generation();
  my @best_indivs = @{$retval->{best}};

  # --------------------------------------------------
  # Update the user with status
  $curr_best = &show_status_update($retval);

  # --------------------------------------------------
  # Save the current state to disk
  if ($curr_best < $prev_best) {
    $best_indivs[0]->save_to_disk( { serial => sprintf("%06d", $i),
                                     project => $project_name } );
    $prev_best = $curr_best;
  }

  $i++;
}


# --------------------------------------------------
# Subs

# my $size_colors = {"Extra large" => 'cyan on_black',
#                    Large         => 'blue on_black',
#                    Medium        => 'red on_black',
#                    Small         => 'yellow on_black',
#                    Tiny          => 'magenta on_black'};
my $prev_top_id = {};
sub show_status_update {
  my $arg = shift;
  my @best_indivs = @{$arg->{best}};
  my $size = $arg->{radius_strategy};

  my (@fitness, @object_count, $operations);
  for my $bi (@best_indivs) {
    push @fitness, $bi->fitness();
    push @object_count, $bi->number_of_objects();
    $operations .= $bi->previous_operation();
  }
  my $gen_i = sprintf "%4d", $i;
  my $best_f = sprintf "%.8f", $fitness[0];
  my $avg_f = sprintf "%.8f", average(@fitness);
  my $stdev_f = sprintf "%.8f", stdev(@fitness);
  my $best_a = sprintf "%5d", $object_count[0];
  my $avg_a = sprintf "%8.2f", average(@object_count);
  my $stdev_a = sprintf "%8.2f", stdev(@object_count);

  my $prev_f;
  if ($prev_best - $fitness[0] < 0.000000000001) {
    $prev_f = 0;
  } else {
    $prev_f = colored(sprintf("%.8f", $fitness[0] - $prev_best), 'yellow on_black');
  }

  my @top_ids = map {$_->id()} @best_indivs[0..2];
  my @colored_top_ids;
  for my $id (@top_ids) {
    if (exists $prev_top_id->{$id}) {
      push @colored_top_ids, $id;
    } else {
      push @colored_top_ids, colored($id, 'red on_black');
    }
  }
  $prev_top_id = {};
  for my $id (@top_ids) { $prev_top_id->{$id} = 1; }

  my $top_id_str = join ', ', @colored_top_ids;

  say "Gen $gen_i: Top three individuals ($top_id_str) Map of Operations: ($operations) ";
  say "          Object count (B:$best_a A:$avg_a S:$stdev_a)";
  say "          Fitness (B:$best_f A:$avg_f S:$stdev_f)";
  say "          Fitness diff for best individual: $prev_f";
  say "          Radius size for new circles: $size";

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

#!/usr/bin/perl
use v5.18;
use warnings;
use strict;
use diagnostics;
use Term::ANSIColor;

BEGIN { push @INC, qw| lib/ .|}
use Population;
use Individual;
$| = 1;

# --------------------------------------------------
# Handle commandline arguments
my $target_filename = $ARGV[0];
die "file '$target_filename' not found" unless -e $target_filename;
my $project_name = $ARGV[1] || $$;


# --------------------------------------------------
# Set things up
Individual->init_num_objects(20);
Individual->max_num_objects(800);

# Create a population and generate the individuals
my $population = Population->new({
                                  target_image_filename => $target_filename,
                                  population_size => 100,
                                  bcm_ratio => '1:4:2'
                                 });
$population->generate_individuals();




# --------------------------------------------------
# Repeat the below until the population has an individual which is
# "good enough"
my ($i, $prev_best, $curr_best) = (1,1,1);
my $status_update = &setup_status_update();

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
  $curr_best = &$status_update($retval);

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

sub setup_status_update {
  my $prev_top_id = {};
  my $op_stats = {};
  my $op_total;
  my @op_history;

  return sub  {
    my $arg = shift;
    my @best_indivs = @{$arg->{best}};

    my (@fitness, @object_count, @op_history_local);
    my $operations = '';
    for my $bi (@best_indivs) {
      push @fitness, $bi->fitness();
      push @object_count, $bi->number_of_objects();

      my $po = $bi->previous_operation();
      unless ($po eq 'G') {     # skip stats for first generation
        push @op_history_local, $po;
        $operations .= $po;   # for displaying this round's operations
        $op_stats->{$po}++;   # for displaying all-time statistics
        $op_total++;          # for displaying all-time statistics
      }
    }
    # for keeping track of the operations for the last 100 rounds
    push @op_history, [ @op_history_local ];
    shift @op_history if scalar(@op_history) > 100;

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
    for my $id (@top_ids) {
      $prev_top_id->{$id} = 1;
    }
    my $top_id_str = join ', ', @colored_top_ids;


    # $i & 1 is a bitwise operator, in this context checking if $i is odd.
    my $csize = colored(sprintf("% 6s", $arg->{strategy_name}),
                        $arg->{strategy_id} & 1 ? 'yellow on_black' : 'cyan on_black' );
    say "Gen $gen_i: Top three individuals ($top_id_str) Map of Operations: ($operations) ";
    say " ($csize) Object count (B:$best_a A:$avg_a S:$stdev_a)";
    say "          Fitness (B:$best_f A:$avg_f S:$stdev_f)";
    say "          Fitness diff for best individual: $prev_f";


    # Operations statistics - all time
    print ' 'x19 .
      'Survi ' . 'Child ' .
      'Mut 0 ' . 'Mut 1 ' .
      'Mut 2 ' . 'Mut 3 ' .
      'Mut 4 ' . 'Mut 5 ' . "\n";
    print ' 'x10 . 'All-time ';
    unless ($i > 10) {
      say "----% ----% ----% ----% ----% ----% ----% ----%";
    } else {
      for my $o (qw/. c 0 1 2 3 4 5/) {
        my $v = $op_stats->{$o} // 0;
        my $pc = sprintf("%4s", sprintf('%2.1f', 100*$v/$op_total));
        print "$pc% ";
      }
      print "\n";
    }

    # Operations statistics - last 100
    print ' 'x10 . 'Last 100 ';
    unless ($i > 100) {
      say "----% ----% ----% ----% ----% ----% ----% ----%";
    } else {
      # last 100
      my @hist_ops = flatten(@op_history);
      my $hist_reg;
      $hist_reg->{$_}++ for (@hist_ops);

      for my $o (qw/. c 0 1 2 3 4 5/) {
        my $v = $hist_reg->{$o} // 0;
        my $pc = sprintf("%4s", sprintf('%2.1f', 100*$v/scalar(@hist_ops)));
        print "$pc% ";
      }
      print "\n";
    }

    # Operations statistics - last 10
    print ' 'x10 . 'Last 10  ';
    unless ($i > 10) {
      say "----% ----% ----% ----% ----% ----% ----% ----%";
    } else {
      # last 10
      my $hist_reg = {};
      my @rev_history = reverse @op_history;
      my @hist_ops = flatten(@rev_history[0..10]);
      $hist_reg->{$_}++ for (@hist_ops);

      for my $o (qw/. c 0 1 2 3 4 5/) {
        my $v = $hist_reg->{$o} // 0;
        my $pc = sprintf("%4s", sprintf('%2.1f', 100*$v/scalar(@hist_ops)));
        print "$pc% ";
      }
      print "\n";
    }
    return $fitness[0];
  }
}

sub flatten {
  map { ref $_ ? flatten(@{$_}) : $_ } @_;
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

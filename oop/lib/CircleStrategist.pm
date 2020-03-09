use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;

package CircleStrategist;


# --------------------------------------------------
# CLASS VARIABLES
#

my $radii = { 3 => [200, 400],
              4 => [100, 200],
              0 => [50, 100],
              1 => [25, 50],
              2 => [2, 25],
            };
my $radius_strategy_limit = 4;
my $name_map = {0=>'Medium', 1=>'Small', 2=>'Tiny', 3=>'Giant', 4=>'Large'};

my $DISTANCE_DIFF_THRESHOLD = { 3 => 0.001,
                                4 => 0.0001,
                                0 => 0.00001,
                                1 => 0.000001,
                                2 => 0.0000001,
                              };


# --------------------------------------------------
# CLASS METHODS
#

sub new {
  my $class = shift;
  my $args = shift;

  my $self = {
              strategy => 3, # default to large circles
              distance_history => [ 1 ],
             };
  bless $self, $class;

  if (exists $args->{strategy}) {
    $self->{strategy} = $args->{strategy};
  }

  return $self;
}

# --------------------------------------------------
# INSTANCE METHODS

sub strategy {
  my $self = shift; my $arg = shift;
  $self->{strategy} = $arg // return $self->{strategy};
}

sub lookup {
  my $self = shift;
  my $args = shift;
  my $s = $args->{strategy} // die "must supply strategy\n";
  return $name_map->{$s};
}

sub inform {
  my $self = shift;
  my $args = shift;
  my $d = $args->{distance} // die "must supply distance diff\n";

  my @distance_history = @{$self->{distance_history}};
  push @distance_history, $d;
  shift @distance_history if (@distance_history > 5);
  $self->{distance_history} = \@distance_history;

  my $sum = 0; $sum += $_ for @distance_history;

  my $next = $self->strategy();
  if ($sum < $DISTANCE_DIFF_THRESHOLD->{$next}) {
    # change to next radius (X->L->(M->S->T))
    $next += 1;
    if ($next > $radius_strategy_limit) {
      $next = 0;
      $radius_strategy_limit = 2;
    }
    $self->strategy($next);
    $self->{distance_history} = [ 1 ];
  }
  return {strategy_id => $next, strategy_name => $name_map->{$next}};
}

sub get_radii_range {
  my $self = shift;
  my $s = $self->strategy();
  return $radii->{$s};
}



sub to_string { ... }

1;

__END__


  # --------------------------------------------------
  # For dynamic radius strategy in constructor

  # Class variables
  # my $w   = undef;
  # my $h   = undef;
  # my $max_radius = 400;

  # Constructor
  # if (exists $args->{wxh}) {
  #   my $wxh = $args->{wxh};
  #   $w = $wxh->{width} // 400;
  #   $h = $wxh->{height} // 400;
  #   $max_radius = $w>$h ? $w : $h;

  #   my $rf = $max_radius;
  #   my $rh = int ($max_radius / 2);
  #   for my $k (3, 4, 0, 1) {
  #     my $letter = $s_map->{$k};
  #     $radii->{$letter} = [ $rh, $rf ];
  #     $rf = int($rf/2);
  #     $rh = int($rf/2);
  #   }
  #   $radii->{$s_map->{2}} = [$rh, $rf];
  # }

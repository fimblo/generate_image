use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;

BEGIN { push @INC, qw| lib/ .|}
use Individual;
use CircleStrategist;

package Population;


# --------------------------------------------------
# CLASS VARIABLES
#
# number of individuals in population
my $pop_size     = 100;

# When creating the next generation of the population, this variable
# describes how many children and mutants should be made for each
# individual who is fit.
my $bcm_ratio = '1:3:1';
my ($bnr, $cnr, $mnr) = (undef, undef, undef);


# filename of target image to approximate
my $target_image_filename = undef;

# width and height of target image, stored like so:
# {width => $width, height => $height};
my $wxh = {};

# --------------------------------------------------
# CLASS METHODS
#
sub pop_size {
  my $class = shift; my $arg = shift;
  $pop_size = $arg // return $pop_size;
}
sub bcm_ratio {
  my $class = shift; my $arg = shift;
  $bcm_ratio = $arg // return $bcm_ratio;
}
sub wxh {
  my $class = shift; my $arg = shift;
  $wxh = $arg // return $wxh;
}


sub new {
  my $class = shift;
  my $args = shift;

  my $self = {
              population => [],
              prev_best_ops => {},
              prev_best_fitness => 1,
              best => [],
              circle_strategist => undef,
             };
  bless $self, $class;

  my $str = CircleStrategist->new();
  $self->{circle_strategist} = $str;
  Individual->strategist($str);

  die "Target image filename required"
    unless exists $args->{target_image_filename};
  $target_image_filename = $args->{target_image_filename};
  $wxh = Drawing->setup({target_image_filename => $args->{target_image_filename}});

  $pop_size = $args->{population_size}
    if exists $args->{population_size};

  $bcm_ratio = $args->{bcm_ratio}
    if exists $args->{bcm_ratio};

  die "bcm_ratio needs to look like: b:c:m\n"
    unless ($bcm_ratio =~ m/^(\d+):(\d+):(\d+)$/);
  my ($b,$c,$m) = ($1, $2, $3); # capture digits from regex above
  my $tot = $b + $c + $m;
  $bnr = int($pop_size * $b / $tot);
  $cnr = int($pop_size * $c / $tot);
  $mnr = int($pop_size * $m / $tot);

  return $self;
}

# --------------------------------------------------
# Instance methods

sub best {
  my $self = shift; my $arg = shift;
  $self->{best} = $arg // return $self->{best};
}

sub generate_individuals {
  my $self = shift;

  my (@pop, $i);
  for $i (0 .. ($pop_size - 1)) {
    $pop[$i] = Individual->new();
  }

  $self->{population} = [ @pop ];
}

sub create_images {
  my $self = shift;

  my @pop = @{$self->{population}};
  for (my $i = 0; $i < @pop; $i++)   {
    $pop[$i]->draw() if (exists $pop[$i] and defined $pop[$i]);
  }
}


sub prep_next_generation {
  my $self = shift;

  my ($individual, $pop_by_fitness);
  for my $individual (@{$self->{population}}) {
    my $f = $individual->fitness();
    $pop_by_fitness->{$f} = $individual;
  }

  my ($best_ops, @sorted_keys, @best, @children, @mutants);

  # get the best
  @sorted_keys = sort {$a<=>$b} keys %$pop_by_fitness;
  for my $k (@sorted_keys[0 .. $bnr]) {
    $individual = $pop_by_fitness->{$k};

    my $id = $individual->id();
    if (exists $self->{prev_best_ops}->{$id} and
        $self->{prev_best_ops}->{$id} eq $individual->previous_operation() ) {
      $individual->previous_operation('.');
    }
    $best_ops->{$id} = $individual->previous_operation();
    push @best, $individual;
  }
  $self->best( [ @best ] );
  $self->{prev_best_ops} = $best_ops;
  my $distance = $self->{prev_best_fitness} - $sorted_keys[0];
  $self->{prev_best_fitness} = $sorted_keys[0];

  # inform/update strategist with newest fitness value
  my $next = $self->{circle_strategist}->inform({distance => $distance});


  # create children
  for (my $i = 0; $i < $cnr; $i++) {
    my $ind1 = @best[ int rand scalar @best ];
    my $ind2 = @best[ int rand scalar @best ];
    push @children, $ind1->mate($ind2);
  }

  # create mutants
  for (my $i = 0; $i < $mnr; $i++) {
    my $ind = @best[int rand scalar @best ];
    push @mutants, $ind->mutate();
  }

  $self->{population} = [ @best, @children, @mutants ];

  return { best => [ @best ],
           radius_strategy => $next };
}

1;

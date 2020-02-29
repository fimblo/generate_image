use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;
use Storable 'retrieve';
use Scalar::Util 'blessed';

package Individual;
use parent 'Storable';



# --------------------------------------------------
# CLASS VARIABLES
#
my $max_val      = 2048;        # maximum value of individual allele
my $init_alleles = 100;         # initial number of alleles

# --------------------------------------------------
# CLASS METHODS
#
sub new {
  my $class = shift;
  my $args = shift;

  my $self = {};
  bless $self, $class;

  if (exists $args->{filename}) {
    return $self->load_from_disk($args->{filename});
  }
  if (exists $args->{alleles}) {
    $self->{alleles} = [ @{$args->{alleles}} ];
  } else {
    $self->{alleles} = [];
    for (my $i = 0; $i < Individual->init_alleles(); $i++) {
      push @{$self->{alleles}}, int rand Individual->max_val();
    }
  }

  $self->{size_of} = @{$self->{alleles}};

  return $self;
}

sub max_val {
  my $class = shift;
  my $arg = shift;
  $max_val = $arg // return $max_val;
}

sub init_alleles {
  my $class = shift;
  my $arg = shift;
  $init_alleles = $arg // return $init_alleles;
}

# --------------------------------------------------
# INSTANCE METHODS
sub size_of {
  my $self = shift;
  $self->{size_of} = shift || return $self->{size_of};
}

sub alleles {
  my $self = shift;
  my $arg = shift;
  if ($arg) {
    $self->{alleles} = $arg;
    $self->{size_of} = scalar @$arg;
  } else {
    return $self->{alleles};
  }
}

# Select two alleles at random (a1, a2). Insert a2 after a1, shifting the rest upwards
sub insert_mutation {
  my $self = shift;
  my ($r1, $r2) = sort { $a <=> $b } (rand $self->size_of(), rand $self->size_of());
  my @alleles = @{$self->alleles()};

  my $removed = splice @alleles, $r2, 1;
  splice @alleles, $r1, 0, $removed;

  return Individual->new({ alleles => \@alleles });
}

# Select two alleles at random, then invert the alleles values between them
sub inversion_mutation {
  my $self = shift;
  my ($r1, $r2) = sort { $a <=> $b } (rand $self->size_of(), rand $self->size_of());

  my @alleles = @{$self->alleles()};
  my $m = Individual->max_val();

  my @first;
  if ($r1 < 1) {
    @first = ();
  } else {
    @first = @alleles[0   .. $r1 - 1];
  }

  my @mid   = map { $m - $_ } @alleles[$r1 .. $r2 - 1];
  my @last  = @alleles[$r2 .. $#alleles];

  return Individual->new( {alleles => [@first, @mid, @last] } );
}

# Select subset of alleles, and move them to each others' locations without changing them
sub scramble_mutation {
  my $self = shift;
  my $pair_count = 5;           # change this later
  my $mutant;
  my @alleles = @{ $self->alleles() };

  while ($pair_count-- > 0) {
    $mutant = Individual->new( { alleles => [ @alleles ] } );
    $mutant = $mutant->swap_mutation();
    @alleles = @{ $mutant->alleles() };
  }

  return Individual->new( {alleles => [ @alleles ] } );
}

# Select two alleles and swap their locations
sub swap_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $mutant = Individual->new( { alleles => [ @alleles ] } );
  my ($i1, $i2) = (rand $mutant->size_of(), rand $mutant->size_of());
  my ($a1, $a2) = ($mutant->{alleles}[$i1], $mutant->{alleles}[$i2]);
  $mutant->{alleles}[$i1] = $a2;
  $mutant->{alleles}[$i2] = $a1;

  return $mutant;
}

# Select two alleles at random, then reverse the location order of the alleles between them
sub reversing_mutation {
  my $self = shift;
  my $mutant = Individual->new( { alleles => $self->alleles() } );
  my ($i1, $i2) = sort (rand $mutant->size_of(), rand $mutant->size_of());
  my $diff = $i2 - $i1;

  my @alleles = @{ $mutant->alleles() };
  my @reversed = reverse splice @alleles, $i1, $diff;
  splice @alleles, $i1, 0, @reversed;
  $mutant->alleles(\@alleles);

  return $mutant;
}

# Select an allele and replace it with a random value
sub creep_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $mutant = Individual->new( { alleles => [ @alleles ] } );
  my $i = rand $self->size_of();

  $mutant->{alleles}[$i] = int rand Individual->max_val();

  return $mutant;
}

sub mate {
  my $self = shift;
  my $mate = shift or die "must supply a mate!";
  my $r = int rand $mate->size_of();
  my @s_all = @{$self->alleles()};
  my @m_all = @{$mate->alleles()};

  my @first;
  if ($r < 1) {
    @first = ();
  } else {
    @first = @s_all[0   .. $r-1];
  }
  my @last  = @m_all[$r ..  $#m_all];

  return Individual->new( { alleles => [ @first, @last ] } );
}

sub mutate {
  my $self = shift;

  my $no_of_mutations = 6;
  my $mutation_type = shift || rand $no_of_mutations;
  return undef if ($mutation_type > $no_of_mutations or $mutation_type < 1);

  EXPERIMENTAL: {
    no warnings;
    my $retval;
    for ($mutation_type) {
      when ($_ == 1) { $retval = $self->insert_mutation()     }
      when ($_ == 2) { $retval = $self->inversion_mutation()  }
      when ($_ == 3) { $retval = $self->scramble_mutation()   }
      when ($_ == 4) { $retval = $self->swap_mutation()       }
      when ($_ == 5) { $retval = $self->reversing_mutation()  }
      when ($_ == 6) { $retval = $self->creep_mutation()      }
      default        { die "Invalid option\n" }
    }
    return $retval;
  }
}

sub save_to_disk {
  my $self = shift;
  my $name = shift // 'individual.txt';

  my $err = $self->store($name);
  die $err unless $err;
}

sub load_from_disk {
  my $self = shift;
  my $name = shift // 'individual.txt';

  my $data = Storable::retrieve($name);

  die "Error in reading data from '$name'.\n"
    unless $data;
  die "Object from '$name' is not blessed as a 'Individual'.\n"
    unless 'Individual' eq Scalar::Util::blessed($data);
  die "Object from '$name' is not a 'Individual'\n"
    unless $data->UNIVERSAL::isa('Individual');
  die "Object from '$name' does not have all the methods it should\n"
    unless $data->UNIVERSAL::can('to_string');
  die "No allele key exists in '$name' hash.\n"
    unless exists $data->{alleles};
  die "No allele arrayref exists in '$name'.\n"
    unless ref $data->{alleles} eq 'ARRAY';
  my $stringified = join '', @{ $data->{alleles} };
  die "There are non-digits in the allele array.\n"
    if $stringified =~ /\D/;

  return $data;
}

sub to_string {
  my $self = shift;
  my $arg = shift;

  my $all_no = $self->{size_of};
  my $cir_no = int($all_no / 7);

  return "Individual (len:$all_no) (cir:$cir_no) (@{$self->alleles()})";
}

1;

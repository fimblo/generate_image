use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;
use Storable 'retrieve';
use Scalar::Util 'blessed';
use Drawing;

package Individual;
use parent 'Storable';



# --------------------------------------------------
# CLASS VARIABLES
#
my $max_val      = 2048;  # maximum value of individual allele
my $init_alleles = 1000;  # initial number of alleles
my $max_alleles  = 2000;  # maximum number of alleles

# --------------------------------------------------
# CLASS METHODS
#
sub new {
  my $class = shift;
  my $args = shift;

  my $self = {
              previous_operation => 'G'
             };
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

  $self->{number_of_alleles} = @{$self->{alleles}};

  return $self;
}

sub max_val {
  my $class = shift; my $arg = shift;
  $max_val = $arg // return $max_val;
}

sub init_alleles {
  my $class = shift; my $arg = shift;
  $init_alleles = $arg // return $init_alleles;
}

sub max_alleles {
  my $class = shift; my $arg = shift;
  $max_alleles = $arg // return $max_alleles;
}

# --------------------------------------------------
# INSTANCE METHODS
sub number_of_alleles {
  my $self = shift;
  $self->{number_of_alleles} = shift || return $self->{number_of_alleles};
}
sub previous_operation {
  my $self = shift;
  $self->{previous_operation} = shift || return $self->{previous_operation};
}

sub alleles {
  my $self = shift;
  my $arg = shift;
  if ($arg) {
    $self->{alleles} = $arg;
    $self->{number_of_alleles} = scalar @$arg;
  } else {
    return $self->{alleles};
  }
}

sub draw {
  my $self = shift;

  my $d = Drawing->new();
  $d->image({ alleles => $self->alleles() });

  $self->{drawing} = $d;
  return $d;
}

sub fitness {
  my $self = shift;
  return $self->{drawing}->fitness();
}


sub mate {
  my $self = shift;
  my $mate = shift or die "must supply a mate!";
  my $r1 = int rand $self->number_of_alleles();
  my $r2 = int rand $mate->number_of_alleles();
  my @s_all = @{$self->alleles()};
  my @m_all = @{$mate->alleles()};

  my @first;
  if ($r1 < 1) {
    @first = ();
  } else {
    @first = @s_all[0   .. $r1-1];
  }
  my @last  = @m_all[$r2 ..  $#m_all];

  $self->previous_operation('M');
  return Individual->new( { alleles => [ @first, @last ] } );
}

sub mutate {
  my $self = shift;

  my $no_of_mutations = 8;
  my $mutation_type = shift // int rand $no_of_mutations;
  die "Invalid mutation type\n" if ($mutation_type > $no_of_mutations);

  EXPERIMENTAL: {
    no warnings;
    my $mutant;
    for ($mutation_type) {
      when ($_ == 0) { $mutant = $self->insert_mutation()     }
      when ($_ == 1) { $mutant = $self->inversion_mutation()  }
      when ($_ == 2) { $mutant = $self->scramble_mutation()   }
      when ($_ == 3) { $mutant = $self->swap_mutation()       }
      when ($_ == 4) { $mutant = $self->reversing_mutation()  }
      when ($_ == 5) { $mutant = $self->creep_mutation()      }
      when ($_ == 6) { $mutant = $self->grow_mutation()       }
      when ($_ == 7) { $mutant = $self->shrink_mutation()     }
      default        { die "Invalid option\n" }
    }

    my @m_alleles = @{$mutant->alleles()};
    if (scalar(@m_alleles) > Individual->max_alleles()) {
      splice @m_alleles, Individual->max_alleles();
      $mutant = Individual->new({ alleles => [ @m_alleles ]});
    }
    return $mutant;
  }
}

# Select two alleles at random (a1, a2). Insert a2 after a1, shifting the rest upwards
sub insert_mutation {
  my $self = shift;
  my ($r1, $r2) = sort { $a <=> $b } (rand $self->number_of_alleles(), rand $self->number_of_alleles());
  my @alleles = @{$self->alleles()};

  my $removed = splice @alleles, $r2, 1;
  splice @alleles, $r1, 0, $removed;

  $self->previous_operation(1);
  return Individual->new({ alleles => \@alleles });
}

# Select two alleles at random, then invert the alleles values between them
sub inversion_mutation {
  my $self = shift;
  my ($r1, $r2) = sort { $a <=> $b } (rand $self->number_of_alleles(), rand $self->number_of_alleles());

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

  $self->previous_operation(2);
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

  $self->previous_operation(3);
  return Individual->new( {alleles => [ @alleles ] } );
}

# Select two alleles and swap their locations
sub swap_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $mutant = Individual->new( { alleles => [ @alleles ] } );
  my ($i1, $i2) = (rand $mutant->number_of_alleles(), rand $mutant->number_of_alleles());
  my ($a1, $a2) = ($mutant->{alleles}[$i1], $mutant->{alleles}[$i2]);
  $mutant->{alleles}[$i1] = $a2;
  $mutant->{alleles}[$i2] = $a1;

  $self->previous_operation(4);
  return $mutant;
}

# Select two alleles at random, then reverse the location order of the alleles between them
sub reversing_mutation {
  my $self = shift;
  my $mutant = Individual->new( { alleles => $self->alleles() } );
  my ($i1, $i2) = sort (rand $mutant->number_of_alleles(), rand $mutant->number_of_alleles());
  my $diff = $i2 - $i1;

  my @alleles = @{ $mutant->alleles() };
  my @reversed = reverse splice @alleles, $i1, $diff;
  splice @alleles, $i1, 0, @reversed;
  $mutant->alleles(\@alleles);

  $self->previous_operation(5);
  return $mutant;
}

# Select an allele and replace it with a random value
sub creep_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $mutant = Individual->new( { alleles => [ @alleles ] } );
  my $i = rand $self->number_of_alleles();

  $mutant->{alleles}[$i] = int rand Individual->max_val();

  $self->previous_operation(6);
  return $mutant;
}

# Grow allele string
sub grow_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $new_allele = int rand Individual->max_val();
  my $pos = int rand scalar @alleles;
  splice @alleles, $pos, 0, $new_allele;

  $self->previous_operation(7);
  return Individual->new( { alleles => [ @alleles ]} );
}

# Shrink allele string
sub shrink_mutation {
  my $self = shift;
  my @alleles = @{ $self->alleles() };
  my $pos = int rand scalar @alleles;
  splice @alleles, $pos, 1;

  $self->previous_operation(8);
  return Individual->new( { alleles => [ @alleles ]} );
}

sub save_to_disk {
  my $self = shift;
  my $name = shift // 'individual.txt';

  $self->{drawing}->save_image({filename => "$$-${name}.png"});
  unlink "latest.png";
  symlink "$$-${name}.png", "latest.png";
  my $err = $self->store("$$-${name}.txt");
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

  my $all_no = $self->{number_of_alleles};
  my $cir_no = int($all_no / 7);

  return "Individual (len:$all_no) (cir:$cir_no) (@{$self->alleles()})";
}

1;

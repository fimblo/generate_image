use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;
use Storable 'retrieve';
use Scalar::Util 'blessed';
BEGIN { push @INC, qw| lib/ .|}
use Drawing;

package Individual;
use parent 'Storable';



# --------------------------------------------------
# CLASS VARIABLES
#
my $init_num_objects = 20;   # initial number of geometric objects
my $max_num_objects  = 2000; # maximum number of geometric objects
my $id               = 'a';  # start id for each Individual created
my $wxh = { width  => 400,   # width and height of target image
            height => 400 };

# --------------------------------------------------
# CLASS METHODS
#
sub new {
  my $class = shift;
  my $args = shift;

  my $self = {
              objects => [],
              previous_operation => 'G',
              id => $id++
             };
  bless $self, $class;

  if (exists $args->{filename}) {
    return $self->load_from_disk($args->{filename});
  }
  if (exists $args->{objects}) {
    $self->{objects} = [ @{$args->{objects}} ];
  } else {
    my @objects;
    my $i = 0;
    while ($i++ < Individual->init_num_objects()) {
      push @objects, Individual->generate_object();
    }
    $self->{objects} = \@objects;
  }

  $self->{number_of_objects} = scalar @{$self->{objects}};

  return $self;
}

sub init_num_objects {
  my $class = shift; my $arg = shift;
  $init_num_objects = $arg // return $init_num_objects;
}

sub max_num_objects {
  my $class = shift; my $arg = shift;
  $max_num_objects = $arg // return $max_num_objects;
}

sub wxh {
  my $class = shift; my $arg = shift;
  $wxh = $arg // return $wxh;
}

sub generate_object {
  my $class = shift;
  my ($w, $h) = ($wxh->{width}, $wxh->{height});
  return [ int rand $w,
           int rand $h,
           int rand ($w<$h ? $w : $h),
           int rand 256,
           int rand 256,
           int rand 256 ];
}


# --------------------------------------------------
# INSTANCE METHODS

sub id {
  my $self = shift; my $arg = shift;
  $self->{id} = shift // return $self->{id};
}
sub number_of_objects {
  my $self = shift;
  $self->{number_of_objects} = shift // return $self->{number_of_objects};
}
sub previous_operation {
  my $self = shift;
  $self->{previous_operation} = shift // return $self->{previous_operation};
}

sub objects {
  my $self = shift;
  my $arg = shift;
  if ($arg) {
    $self->{objects} = $arg;
    $self->{number_of_objects} = scalar @$arg;
  } else {
    return $self->{objects};
  }
}

sub draw {
  my $self = shift;

  my $d = Drawing->new();
  $d->image({ objects => $self->objects() });

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
  my $r1 = int rand $self->number_of_objects();
  my $r2 = int rand $mate->number_of_objects();
  my @s_all = @{$self->objects()};
  my @m_all = @{$mate->objects()};

  my @first = @s_all[0 .. $r1];
  my @last = @m_all[$r2 .. -1];

  # Limit size if it's larger than max_num_objects
  my @objects = (@first, @last);
  if (scalar(@first) + scalar (@last) > Individual->max_num_objects()) {
    splice @objects, Individual->max_num_objects();
  }
  my $child = Individual->new({ objects => [ @objects ]});

  $child->previous_operation('c');
  return $child;
}

sub mutate {
  my $self = shift;

  my $no_of_mutations = 2;
  my $mutation_type = shift // int rand $no_of_mutations;
  die "Invalid mutation type\n" if ($mutation_type > $no_of_mutations);


  my $mutant;
  if    ($mutation_type == 0) { $mutant = $self->grow_mutation()    }
  elsif ($mutation_type == 1) { $mutant = $self->insert_mutation()  }
  elsif ($mutation_type == 2) { $mutant = $self->shrink_mutation()  }
  elsif ($mutation_type == 3) { $mutant = $self->replace_mutation() }
  else { die "Invalid option\n" }


  # Limit size if it's larger than max_num_objects
  my @objects = @{$mutant->objects()};
  if (scalar(@objects) > Individual->max_num_objects()) {
    splice @objects, Individual->max_num_objects();
    my $po = $mutant->previous_operation();
    $mutant = Individual->new({ objects => [ @objects ]});
    $mutant->previous_operation($po);
  }
  return $mutant;
}

sub grow_mutation {
  my $self = shift;
  my @objects = @{ $self->objects() };
  my $new_object = Individual->generate_object();
  my $mutant = Individual->new( { objects => [ @objects, $new_object ]} );
  $mutant->previous_operation(0);
  return $mutant;
}
sub insert_mutation {
  my $self = shift;
  my @objects = @{ $self->objects() };
  my $new_object = Individual->generate_object();
  my $pos = int rand scalar @objects;
  splice @objects, $pos, 0, $new_object;
  my $mutant = Individual->new( { objects => [ @objects, $new_object ]} );
  $mutant->previous_operation(1);
  return $mutant;
}
sub shrink_mutation {
  my $self = shift;
  my @objects = @{ $self->objects() };
  my $pos = int rand scalar @objects;
  splice @objects, $pos, 1;

  my $mutant = Individual->new( { objects => [ @objects ]} );
  $mutant->previous_operation(2);
  return $mutant;
}
sub replace_mutation {
  my $self = shift;
  my @objects = @{ $self->objects() };
  my $new_object = Individual->generate_object();
  my $pos = int rand scalar @objects;
  splice(@objects, $pos, 1, $new_object);

  my $mutant = Individual->new( { objects => [ @objects ]} );
  $mutant->previous_operation(3);
  return $mutant;
}


sub save_to_disk {
  my $self = shift;
  my $args = shift // { serial => 'XYZ', project => $$};
  my $project = $args->{project};
  my $serial = $args->{serial};

  for ("output", "output/$project") { mkdir unless -d }
  my $dirname = $args->{dirname} = "output/$project";

  my $abs_filename = $self->{drawing}->save_image($args);
  my $abs_diffname = $self->{drawing}->save_diff_image($args);

  my @parts = split '/', $abs_filename;
  my $fname = $parts[-1];
  rename "$dirname/latest.png", "$dirname/previous.png";
  symlink $fname, "$dirname/latest.png";

  my $saved_drawing = $self->{drawing};
  delete $self->{drawing};
  my $err = $self->store("$dirname/individual-${serial}.txt");
  die $err unless $err;
  $self->{drawing} = $saved_drawing;
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
  die "No 'object' key exists in '$name' hash.\n"
    unless exists $data->{objects};
  die "No 'object' arrayref exists in '$name'.\n"
    unless ref $data->{objects} eq 'ARRAY';

  my $stringified = join '', $self->flatten($data->{objects});
  die "There are non-digits in the allele array.\n"
    if $stringified =~ /\D/;

  return $data;
}

sub to_string {
  my $self = shift;
  my $arg = shift;

  my $id = $self->{id};
  my $all_no = $self->{number_of_objects};

  return "Individual (id: $id) (cir:$all_no) (@{$self->objects()})";
}

sub flatten {
  my $self = shift;
  map { ref $_ ? $self->flatten(@{$_}) : $_ } @_;
}


1;
__END__
# --------------------------------------------------
# End of script
# --------------------------------------------------

# Possible mutation types I could use
# Select two alleles at random (a1, a2). Insert a2 after a1, shifting the rest upwards
# Select two alleles at random, then invert the alleles values between them
# Select subset of alleles, and move them to each others' locations without changing them
# Select two alleles and swap their locations
# Select two alleles at random, then reverse the location order of the alleles between them
# Select an allele and replace it with a random value
# Grow allele string
# Shrink allele string

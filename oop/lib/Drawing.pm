use v5.18; # for 'when' and 'say' etc.
use warnings;
use strict;
use diagnostics;
use Image::Magick;

package Drawing;


# --------------------------------------------------
# CLASS VARIABLES
#
my $target_image_filename = undef; # filename where target image can be found
my $target_image          = undef; # an Image::Magick image
my $width                 = undef; # width of target image
my $height                = undef; # height of target image
my $wxh                   = undef; # string: geometry of target image eg '600x300'

# --------------------------------------------------
# CLASS METHODS
#
sub setup {
  my $class = shift;
  my $args = shift;

  # return if setup has already been done.
  return if defined $wxh;

  die "Target image filename required\n"
    unless exists $args->{target_image_filename};
  $target_image_filename = $args->{target_image_filename};

  $target_image = Image::Magick->new();
  $target_image->ReadImage($target_image_filename);
  $width = $target_image->Get('width');
  $height = $target_image->Get('height');
  $wxh = $width . 'x' . $height;
}

sub new {
  my $class = shift;
  my $args = shift;

  my $self = {};
  bless $self, $class;


  return $self;
}

# --------------------------------------------------
# INSTANCE METHODS

sub fitness {
  my $self = shift;
  return $self->{fitness} if exists $self->{fitness};

  die "Can't run fitness function yet."
    unless ($target_image);
  die "Can't run fitness function yet."
    unless (exists $self->{image});

  my $im = $self->{image};

  my $result = $target_image->Compare(image=>$im, metric=>'mae');
  my $diff = $result->Get('error');

  $self->{diff_image} = $result;
  $self->{fitness} = $diff;
  return $diff;
}

sub image {
  my $self = shift;
  my $args = shift;
  return $self->{image} if exists $self->{image};

  die "Supply alleles as arg" unless exists $args->{alleles};

  my $im = Image::Magick->new();
  $im->Set(size=>${wxh});
  $im->Set(magick=>'PNG32');
  $im->Read('canvas:white');

  my @alleles = ( @{$args->{alleles}} );
  my $circles;

  while (@alleles) {
    last if @alleles < 7;
    my ($index, $xl, $yl, $radl, $rl, $gl, $bl, @remains) = @alleles;
    my $x = $xl % $width;       # gotta fix numbers since range there
    my $y = $yl % $height;      # is much bigger than here
    my $yr = $y + ($radl % $height);
    my $r = $rl % 256;
    my $g = $gl % 256;
    my $b = $bl % 256;
    $circles->{$index} = [$x, $y, $yr, $r, $g, $b];

    last if @remains < 7;
    @alleles = @remains;
  }

  for my $i (sort {$a<=>$b} keys %$circles) {
    my ($x, $y, $yr, $r, $g, $b) = @{$circles->{$i}};

    $im->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $x,$yr");
  }

  $self->{image} = $im;
  return $im;
}

sub save_image {
  my $self = shift;
  my $args = shift // { filename => 'image.png'};

  my $err = $self->{image}->Write($args->{filename});
  die "$err" if "$err";
}

sub save_diff_image {
  my $self = shift;
  my $args = shift // { filename => 'comparison.png'};

  my $err = $self->{diff_image}->Write($args->{filename});
  die "$err" if "$err";
}

sub to_string { ... }

1;

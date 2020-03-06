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
  return {width => $width, height => $height};
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

  die "Supply allele objects as arg" unless exists $args->{objects};

  my $im = Image::Magick->new();
  $im->Set(size=>${wxh});
  $im->Set(magick=>'PNG32');
  $im->Read('canvas:white');

  my @objects = ( @{$args->{objects}} );

  for (@objects) {
    my ($x, $y, $yr, $r, $g, $b) = @{$_};
    $im->Draw(fill=>"rgb($r,$g,$b)", primitive=>'circle', points=>"$x,$y $x,$yr");
  }

  $self->{image} = $im;
  return $im;
}

sub save_image {
  my $self = shift;
  my $args = shift // { serial => 'XYZ', dirname => '.'};

  my $fname = join '',  ($args->{dirname}, '/image-', $args->{serial}, '.png');
  my $err = $self->{image}->Write($fname);
  die "$err" if "$err";
  return $fname;
}

sub save_diff_image {
  my $self = shift;
  my $args = shift // { dirname => '.'};

  my $fname = "$args->{dirname}/comparison.png";
  my $err = $self->{diff_image}->Write($fname);
  die "$err" if "$err";
  return $fname;
}

sub to_string { ... }

1;

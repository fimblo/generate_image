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

sub fitness { ... }
sub image { ... }


sub to_string { ... }

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part.pm $ $Author: autrijus $
# $Revision: #11 $ $Change: 8075 $ $DateTime: 2003/09/12 17:31:20 $

package DBIx::ReportBuilder::Part;

use strict;
use DBIx::ReportBuilder ':all';
use base 'XML::Twig::Elt';

use constant ElementClass   => __PACKAGE__;

=head2 new

The extremely flexible constructor method:

    DBIx::ReportBuilder::Part::P->new;			# p object
    DBIx::ReportBuilder::Part->new('p');		# ditto
    $part = DBIx::ReportBuilder::Part->new($elt);	# rebless $elt into $elt->tag
    $part->new;						# another p object
    $part->new('img');					# an img object

=cut

sub new {
    my $class = shift;
    my $self  = shift;
    $class = ref($class) || $class;

    my $ElementClass = eval { $self->ElementClass } || $class->ElementClass;

    if (!ref($self) or $class eq $ElementClass) {
	my $tag = (ref($self) ? $self->tag : $self);
	$class = $ElementClass;
	$class .= "::\u$tag" if $tag;
	my $pkg = $class;
	$pkg =~ s{::}{/}g;
	require "$pkg.pm";
    }

    if (!ref($self) and $class =~ /::(\w+)$/) {
	$self = $class->SUPER::new(lc($1));
	$self->init(@_);
    }

    bless $self, $class;
    return $self;
}

sub set_tag {
    my ($self, $tag) = @_;
    $self->SUPER::set_tag($tag);
    bless $self, $self->ElementClass . "::\u$tag";
    return $self;
}

sub init {}

sub Insert {
    my ($self, %args) = @_;
    my $tag = $args{tag} or die("Can't insert a tagless part");
    my $part = $self->new($tag, %args);
    $part->paste(after => $self);
    $part->Change(%args);
    return $part;
}

sub Up {
    my $self = shift;
    my $part = $self->prev_sibling or return;
    $self->move(before => $part);
    return -1;
}

sub Down {
    my $self = shift;
    my $part = $self->next_sibling or return;
    $self->move(after => $part);
    return 1;
}

sub Remove {
    my $self = shift;
    my $part = $self->prev_sibling || $self->next_sibling;
    $part ||= $self->new('p')->paste(before => $self);
    $self->delete;
    return $part;
}

sub Change {
    my ($self, %args) = @_;
    foreach my $key ( $self->Atts ) {
	defined $args{$key} or next;
	my $value = $args{$key};
	if ($key eq 'text') {
	    $self->set_text('');
	    foreach my $token (split(/(\$\{?\w+\}?)/, $value)) {
		next unless length($token);
		if ($token =~ /\$\{?(\w+)\}?/) {
		    $self->insert_new_elt(
			last_child => 'var',
			{ name => $self->lcase($1) },
		    );
		    next;
		}
		$self->insert_new_elt( last_child => '#PCDATA', $token);
	    }
	}
	elsif ($key eq 'src' and ref($value)) {
	    binmode($value);

	    my $stream = do { local $/; <$value> };

	    require Image::Size;
	    my ($x, $y, $type) = Image::Size::imgsize(\$stream);
	    return unless $x;

	    $self->_ConvertToPNG( \$stream ) unless $type eq 'PNG';

	    $self->set_att( width => $x, height => $y );
	    $self->set_att( $key => $self->encode_src($stream) );
	}
	else {
	    $self->set_att( $key => $value );
	}
    }
    return 0;
}

sub Id {
    my $self = shift;
    $self->att('id') =~ /(\d+)$/ or return;
    return $1;
}

sub _ConvertToPNG {
    my ($self, $ref) = @_;

    require File::Temp;

    my ($tmpfh, $tmpfile) = File::Temp::tempfile() or die $!;
    binmode($tmpfh);
    print $tmpfh $$ref;
    close $tmpfh;

    require Image::Magick;
    my $img = Image::Magick->new or die $!;
    $img->Read($tmpfile);
    $img->Write("$tmpfile.png");

    open $tmpfh, "$tmpfile.png" or die "Can't open $tmpfile.png: $!";
    binmode($tmpfh);
    $$ref = do { local $/; <$tmpfh> };
    close $tmpfh;

    unlink $tmpfile;
    unlink "$tmpfile.png";
}

1;

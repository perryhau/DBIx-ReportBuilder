# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 7981 $ $DateTime: 2003/09/08 16:27:28 $

package DBIx::ReportBuilder::Part;

use strict;
use DBIx::ReportBuilder ':all';
use base 'XML::Twig::Elt';

use constant ElementClass => __PACKAGE__;

=head2 new

The extremely flexible constructor method:

    DBIx::ReportBuilder::Part::P->new;			# p object
    DBIx::ReportBuilder::Part->new('p');			# ditto
    $part = DBIx::ReportBuilder::Part->new($elt);	# rebless $elt into $elt->tag
    $part->new;					# another p object
    $part->new('img');				# an img object

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
    my $part = $self->prev_sibling;
    $self->new('p')->paste(before => $self) unless $part;
    $self->delete;
    return( $part ? -1 : 0 );
}

sub Change {
    my ($self, %args) = @_;
    foreach my $key ( $self->Atts ) {
	defined $args{$key} or next;
	my $value = $args{$key};
	# $value = 1 if $value eq 'on';
	# $value = 0 if $value eq 'off';
	$self->set_att( $key => $value );
    }
    return 0;
}

1;

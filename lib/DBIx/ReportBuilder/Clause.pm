# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Clause.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 8713 $ $DateTime: 2003/11/06 15:12:20 $

package DBIx::ReportBuilder::Clause;

use strict;
use base 'DBIx::ReportBuilder::Part';
use constant ElementClass => __PACKAGE__;

sub Insert {
    my ($self, %args) = @_;
    my $tag = $args{tag} or die("Can't insert a tagless clause");
    return $self->SUPER::Insert(%args)
	if $self->parent and $self->parent->tag eq "${tag}s";

    # We don't have any siblings... paste into the collection object
    my $parent = $args{Object}->PartObj->first_child("${tag}s");
    if (!$parent) {
	$parent = $self->new("${tag}s");
	$parent->paste(last_child => $args{Object->PartObj});
    }
    my $part = $self->new($tag, %args);
    $part->paste(last_child => $parent);
    $part->Change(%args);
    return $part;
}

sub Remove {
    my $self = shift;
    $self->delete;
    return -1;
}

1;

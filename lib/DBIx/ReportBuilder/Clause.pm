# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Clause.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 7954 $ $DateTime: 2003/09/07 22:38:40 $

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
    my $part = $self->new($tag, %args);
    $part->paste($args{Object}->PartObj->first_child("${tag}s"));
    $part->Change(%args);
    return 1;
}

sub Remove {
    my $self = shift;
    $self->delete;
    return -1;
}

1;

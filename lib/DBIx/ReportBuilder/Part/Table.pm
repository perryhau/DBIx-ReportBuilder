# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part/Table.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 7980 $ $DateTime: 2003/09/08 15:37:26 $

package DBIx::ReportBuilder::Part::Table;
use base 'DBIx::ReportBuilder::Part';

sub init {
    my $self = shift;
    $self->insert_new_elt(last_child => $_) for map "${_}s", $self->Clauses;
    return $self;
}

1;

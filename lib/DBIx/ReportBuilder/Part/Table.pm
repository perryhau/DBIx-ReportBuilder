# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part/Table.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7953 $ $DateTime: 2003/09/07 22:05:43 $

package DBIx::ReportBuilder::Part::Table;
use base 'DBIx::ReportBuilder::Part';

sub init {
    my $self = shift;
    $self->insert_new_elt(last_child => $_) for 'caption', map "${_}s", $self->Clauses;
    return $self;
}

sub Change {
    my ($self, %args) = @_;
    $self->first_child('caption')->set_text( $args{text} ) if exists $args{text};
    $self->SUPER::Change( %args );
}

1;

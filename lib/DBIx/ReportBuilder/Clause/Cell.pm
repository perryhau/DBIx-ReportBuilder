# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Clause/Cell.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7953 $ $DateTime: 2003/09/07 22:05:43 $

package DBIx::ReportBuilder::Clause::Cell;
use base 'DBIx::ReportBuilder::Clause';

sub Change {
    my ($self, %args) = @_;
    $self->set_text( $args{text} ) if exists $args{text};
    $self->SUPER::Change( %args );
}

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part/P.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7952 $ $DateTime: 2003/09/07 20:09:05 $

package DBIx::ReportBuilder::Part::P;
use base 'DBIx::ReportBuilder::Part';

sub Insert {
    my $self = shift;
    my $rv = $self->SUPER::Insert(@_);
    return $rv if length($self->text);

    # special case: if we are empty, replace ourselves.
    $self->delete;
    return 0;
}

sub Change {
    my ($self, %args) = @_;
    $self->set_text( $args{text} ) if exists $args{text};
    $self->SUPER::Change( %args );
}

1;

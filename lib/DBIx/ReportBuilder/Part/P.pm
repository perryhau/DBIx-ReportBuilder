# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part/P.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 7980 $ $DateTime: 2003/09/08 15:37:26 $

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
    $self->set_text( delete $args{text} ) if exists $args{text};
    $self->SUPER::Change( %args );
}

use constant Inputs => (
    align	=> {
	type		=> 'radio',
	choices		=> [qw/left center right/],
	default		=> 'left',
    },
    font	=> {
    },
    align => [ qw( align font size border ) ],
);

1;

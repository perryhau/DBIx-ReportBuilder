# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Part/P.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 7993 $ $DateTime: 2003/09/08 23:40:50 $

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

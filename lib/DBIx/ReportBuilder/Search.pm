# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 8214 $ $DateTime: 2003/09/23 04:29:48 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

my $stub;
sub NewItem { bless(\$stub) }
sub LoadFromHash { bless($_[0] = $_[1]) }
sub Id { $_[0]->{id} }

sub Cell {
    my ($self, %args) = @_;
    my $table = $args{TABLE} || do {
	if ( my $alias = $args{ALIAS} ) {
	    $alias =~ s/_\d+$//;
	    $alias;
	}
	else {
	    $self->{table};
	}
    };

    push @{$self->{cells}},
	($args{ALIAS} || 'main') . '.' . $args{FIELD} .
	" AS ${table}_$args{FIELD}";
}

sub _ApplyLimits {
    my ($self, $ref) = @_;
    $self->SUPER::_ApplyLimits($ref);
    $$ref =~ s/main\.\*/join(', ', @{$self->{cells}})/eg if @{$self->{cells}||[]};
}

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 8274 $ $DateTime: 2003/09/28 10:51:26 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

if (!eval { require Encode; 1 }) {
    *Encode::decode = sub { $_[0] };
}


sub NewItem {
    my $encoding = eval { $_[0]->{DBIxHandle}->Encoding } || 'utf8';
    bless \$encoding, ref($_[0]);
}

sub LoadFromHash {
    my $encoding = ${$_[0]};
    bless($_[0] = $_[1]);

    foreach my $key (sort keys %{$_[0]}) {
	$_[0]{$key} = Encode::decode($encoding, $_[0]{$key});
	$_[0]{$key} =~ s/&#([1-9]\d\d+);/chr($1)/eg;  # anti-escapism
    }
    return $_[0];
}
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

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #8 $ $Change: 8439 $ $DateTime: 2003/10/17 00:25:51 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

if (!eval { require Encode; 1 }) {
    *Encode::decode = sub { $_[0] };
}


sub NewItem {
    my $encoding = eval { $_[0]->_Handle->Encoding };
    $encoding ||= 'big5'
	if eval { $_[0]->_Handle->dbh->{Driver}{Name} } eq 'ODBC';
    $encoding ||= 'utf8';
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

sub Fields {
    my ($self, $table) = @_;
    my $dbh = $self->_Handle->dbh;

    return map lc($_->[0]), @{
	eval { $dbh->column_info('', '', $table, '')->fetchall_arrayref([3]) }
	|| $dbh->selectall_arrayref("DESCRIBE $table;")
	|| []
    };
}

sub HasField {
    my ($self, %args) = @_;
    my $table = $args{TABLE} or die;
    my $field = $args{FIELD} or die;
    return grep { $_ eq $field } $self->Fields($table);
}

sub _ApplyLimits {
    my ($self, $ref) = @_;
    $self->SUPER::_ApplyLimits($ref);
    $$ref =~ s/main\.\*/join(', ', @{$self->{cells}})/eg if @{$self->{cells}||[]};
}

1;

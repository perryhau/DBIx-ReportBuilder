# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #15 $ $Change: 8717 $ $DateTime: 2003/11/06 15:55:51 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

=head1 NAME

DBIx::ReportBuilder::Search - Extended SearchBuilder

=head1 SYNOPSIS

    my $sb = DBIx::ReportBuilder::Search->new(
	Host	    => 'localhost',
	Port	    => '3306',
	User	    => 'root',
	Driver	    => 'mysql',
	Database    => 'rt3',
    );
    $sb->SetTable('Queues');
    $sb->GroupBy( FIELD => 'Disabled' );
    my $col1 = $sb->Column( FIELD => 'Disabled' );
    my $col2 = $sb->Column( FIELD => 'Id', FUNCTION => 'SUM' );
    my $col3 = $sb->Column( FIELD => 'Id', FUNCTION => 'COUNT' );
    $sb->UnLimit;
    print join("\t", qw(Disabled SUM(id) COUNT(id))), "\n";
    while (my $row = $sb->Next) {
	print join(
	    "\t",
	    $row->{$col1}, $row->{$col2}, $row->{$col3}
	), "\n";
    };

=head1 DESCRIPTION

This module implements a subclass of L<DBIx::SearchBuilder>.
The main difference is that it defines a default C<LoadFromHash>
and C<NewItem>, so is directly usable without needing to subclass
it first.

It also implements C<GroupBy>, C<GroupByCols>, C<Column> and an
assortment of other utility functions.

=cut

if (!eval { require Encode; 1 }) {
    *Encode::decode = sub { $_[0] };
}

sub new {
    my ($self, %args) = @_;
    if (!$args{Handle}) {
	require DBIx::SearchBuilder::Handle;
	my $handle = DBIx::SearchBuilder::Handle->new;
	$handle->Connect(%args, DisconnectHandleOnDestroy => 1);
	%args = (Handle => $handle);
    }
    return $self->SUPER::new(%args);
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

sub Column {
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

    my $name = ($args{ALIAS} || 'main') . '.' . $args{FIELD};
    if (my $func = $args{FUNCTION}) {
	if ($func =~ /^DISTINCT\s*COUNT$/i) {
	    $name = "COUNT(DISTINCT $name)";
	}
	else {
	    $name = "\U$func\E($name)";
	}
    }

    my $column = "col" .  @{$self->{columns}||=[]};
    push @{$self->{columns}}, "$name AS $column";
    return $column;
}

sub Fields {
    my ($self, $table) = @_;
    my $dbh = $self->_Handle->dbh;

    return map lc($_->[0]), @{
	eval { $dbh->column_info('', '', $table, '')->fetchall_arrayref([3]) }
	|| $dbh->selectall_arrayref("DESCRIBE $table;")
	|| $dbh->selectall_arrayref("DESCRIBE \u$table;")
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
    $$ref =~ s/main\.\*/join(', ', @{$self->{columns}})/eg
	if $self->{columns} and @{$self->{columns}};
    if (my $groupby = $self->_GroupClause) {
	$$ref =~ s/(LIMIT \d+)?$/$groupby $1/;
    }
}

sub SetTable {
    my $self = shift;
    $self->{table} = shift;
    return $self->{table};
}

sub Table { $_[0]->{table} }

sub GroupBy {
    my $self = shift;
    my %args = ( @_ );
    $self->GroupByCols( \%args );
}

sub GroupByCols {
    my $self = shift;
    my @args = @_;
    my $row;
    my $clause;

    foreach $row ( @args ) {
        my %rowhash = ( ALIAS => 'main',
			FIELD => undef,
			%$row
		      );

        if ( ($rowhash{'ALIAS'}) and
             ($rowhash{'FIELD'}) ) {

            $clause .= ($clause ? ", " : " ");
            $clause .= $rowhash{'ALIAS'} . ".";
            $clause .= $rowhash{'FIELD'};
        }
    }

    if ($clause) {
	$self->{'group_clause'} = "GROUP BY" . $clause;
    }
    else {
	$self->{'group_clause'} = "";
    }
    $self->RedoSearch();
}

sub _GroupClause {
    my $self = shift;

    unless ( defined $self->{'group_clause'} ) {
	return "";
    }
    return ($self->{'group_clause'});
}

1;

=head1 SEE ALSO

L<DBIx::ReportBuilder>, L<DBIx::SearchBuilder>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

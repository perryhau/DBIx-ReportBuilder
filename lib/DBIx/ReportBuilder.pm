# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7952 $ $DateTime: 2003/09/07 20:09:05 $

package DBIx::ReportBuilder;
$DBIx::ReportBuilder::VERSION = '0.00_01';

use strict;
no warnings 'redefine';

use base 'XML::Twig';
use base 'Exporter';

=head1 NAME

DBIx::ReportBuilder - Interactive SQL report generator

=head1 VERSION

This document describes version 0.00_01 of DBIx::ReportBuilder, released
September 8, 2003.

=head1 SYNOPSIS

    use DBIx::ReportBuilder;
    my $obj = DBIx::ReportBuilder->new(
	Driver	    => 'mysql',
	Host	    => 'localhost',
	User	    => 'rt_user',
	Password    => 'rt_pass',
	Database    => 'rt3',
    );
    $obj->Part('Insert',
	tag => 'table', table => 'users', rows => 10, text => 'User List'
    );
    $obj->Clause('Insert',
	tag => 'limit', field => 'id', operator => '<', value => 2000
    );
    $obj->Clause('Insert',
	tag => 'cell', field => 'id', text => 'Id'
    );
    $obj->Clause('Insert',
	tag => 'cell', field => 'name', text => 'Name'
    );
    $obj->ClauseObj->Up;	# move up; switch Name and Id
    $obj->ClauseObj->Down;	# move down; switch Name and Id back
    $obj->ClauseObj->Remove;	# delete the current clause
    print $obj->Render('HTML');	# prints a HTML rendered document
    print $obj->Render('Edit');	# prints an interactive Web UI
    print $obj->Render('PDF');	# prints PDF (not yet)

=head1 DESCRIPTION

This module is a subclass of B<XML::Twig>, specially tailored to render
SQL reports in various formats, based on B<DBIx::SearchBuilder>.

Its API is designed to interact with users via the I<RT Report Extension>'s
Web UI, which can incrementally construct complex reports.

=head1 NOTES

This is B<PRE-ALPHA> code.  Until the eventual release of the I<RT Report
Extenison>, using this module for anything (except for learning purporses)
is strongly discouraged.

=head1 METHODS

=cut

use constant Sections	=> qw( preamble header content footer postamble );
use constant Parts	=> qw( p img table graph include );
use constant Clauses	=> qw( join limit orderby cell );
use constant Parameters	=> qw( loc handle trigger handle clause_id part_id );
use constant BaseClass	=> __PACKAGE__;
use constant PartAttrs	=> {
    p           => [ qw( align font size border ) ],
    img         => [ qw( alt width height ) ],
    include     => [ qw( ) ],
    table       => [ qw( table width height ) ],
    graph       => [ qw( table type style legend threed threed_shading cumulate
			  show_values values_vertical rotate_chart title ) ],

    join	=> [ qw( alias alias1 alias2 field1 field2 table2 type ) ],
    limit	=> [ qw( alias field operator value table entryaggregator ) ],
    orderby	=> [ qw( alias field order ) ],
    cell	=> [ qw( field align font size ) ],
};

our @EXPORT_OK = qw( Sections Parts Clauses BaseClass Attrs );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

BEGIN { foreach my $item (Parameters) {
    no strict 'refs';
    my $accessor = ucfirst($item);
    $accessor =~ s/_(\w)/\u$1/g;
    *{"$accessor"} = sub { $_[0]->{$item} };
    *{"Set$accessor"} = sub { $_[0]->{$item} = $_[1] };
} }

=head2 new(%args)

Constructor.  Takes either a C<DBIx::SearchBuilder::Handle> object as the
named C<$Handle> parameter, or a set of parameters for
C<DBIx::SearchBuilder::Handle::new>.

Also takes an optional C<$Content> parameter to parse; if unspecified, use
the default blank content structure.

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new(
	twig_handlers => {
	    (map { $_ => sub { $_->set_id($_[0]->NextPart) } } $class->Parts),
	    (map { $_ => sub { $_->set_id($_[0]->NextClause) } } $class->Clauses),
	},
	pretty_print	=> 'indented_c',
    );
    $self->SetLoc( $args{Loc} );
    $self->SetHandle( $args{Handle} || $self->NewHandle( %args ) );
    $self->Parse( $args{Content} );
    $self->SetPartId( $args{PartId} || 0);
    $self->SetClauseId( $args{ClauseId} || 0 );
    $self->ResetCounts;
    return $self;
}

sub Parse {
    my $self = shift;
    $self->SUPER::parse( defined($_[0]) ? $_[0] : $self->NewContent );
}

sub NewContent {
    my $self = shift;

    my $obj = $self->BaseClass->SUPER::new( @_ );
    $obj->parse(
	'<?xml version="1.0" encoding="UTF-8"?>'.
	'<html xmlns="http://www.autrijus.org/ReportBuilder/1.0" />'
    );

    my $root = $obj->root;
    my $body = $root->insert_new_elt( 'body' );
    my $head = $root->insert_new_elt( 'head' );
    $body->insert_new_elt( last_child => $_ )->insert_new_elt( 'p' )
	foreach qw(preamble header content footer postamble);
    $head->set_att(orientation => 'portrait');
    $head->set_att(paper => 'a4paper');

    return $obj->sprint;
}

sub NewHandle {
    my $self = shift;

    require DBIx::SearchBuilder::Handle;
    my $obj = DBIx::SearchBuilder::Handle->new;
    $obj->Connect( @_ ) or die $! if @_;

    return $obj;
}

sub RenderObj {
    my $self = shift;
    my $type = shift || 'Edit';
    return $self->spawn("Render::$type" => ( Object => $self ) );
}

sub Render {
    my $self = shift;
    return $self->RenderObj(@_)->root->sprint;
}

sub Reload {
    my $self = shift;
    $self->Parse($self->sprint);
    $self->ResetCounts;
    return $self;
}

sub Recount {
    my $self = shift;
    my $root = $self->root;

    $_->set_id($self->NextPart) for sort { $a->cmp($b) }
	map { $root->descendants($_) } $self->Parts;
    $_->set_id($self->NextClause) for sort { $a->cmp($b) }
	map { $root->descendants($_) } $self->Clauses;
    $self->ResetCounts;

    return $self->PartId unless wantarray;
    return ($self->PartId, $self->ClauseId);
}

sub Part   { +shift->_do(Part => @_) }
sub Clause { +shift->_do(Clause => @_) }

sub PartObj   { +shift->_obj(Part => @_) }
sub ClauseObj { +shift->_obj(Clause => @_) }

sub NextPart   { 'Part' . ++$_[0]{next_part} }
sub NextClause { 'Clause' . ++$_[0]{next_clause} }
sub ResetCounts { $_[0]{next_part} = $_[0]{next_clause} = 0 }

sub SetPartId {
    my ($self, $id) = @_;
    $id ||= $self->root->first_child('body')
		 ->first_child('content')->first_child('p')->id;
    $id =~ s/^Part//;
    $self->{part_id} = $id;
}

sub Attrs {
    my ($self, $part) = @_;
    return @{PartAttrs->{lc($part)}};
}

sub _do {
    my $self  = shift;
    my $class = shift;
    my $Op    = shift or return;

    my $getObj = "${class}Obj";
    my $getId  = "${class}Id";
    my $setId  = "Set${class}Id";

    my $obj = $self->$getObj($self->$getId) || $self->spawn($class);
    $obj->can($Op) or return;

    my $modifier = $obj->$Op(@_, Object => $self);
    $self->Recount if defined($modifier);
    return $self->$setId($self->$getId + ($modifier || 0));
}

sub _obj {
    my $self   = shift;
    my $class  = shift;
    my $getId  = "${class}Id";
    my $elt    = $self->elt_id($class . (shift || $self->$getId)) or return;
    return $self->spawn($class => $elt);
}

sub spawn {
    my $class = shift;
    my $subclass = shift;
    my $pkg = $class = $class->BaseClass . "::$subclass";
    $pkg =~ s{::}{/}g;
    require "$pkg.pm";
    return $class->new(@_);
}

sub loc {
    my $self = shift;
    return $self->{loc}->(@_) if $self->{loc};
    return $_[0];
}

1;

=head1 SEE ALSO

L<XML::Twig>, L<DBIx::SearchBuilder>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

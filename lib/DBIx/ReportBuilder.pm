# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder.pm $ $Author: autrijus $
# $Revision: #42 $ $Change: 8942 $ $DateTime: 2003/11/18 18:08:05 $

package DBIx::ReportBuilder;
$DBIx::ReportBuilder::VERSION = '0.00_15';

use strict;
no warnings 'redefine';

use base 'XML::Twig';
use base 'Exporter';

=head1 NAME

DBIx::ReportBuilder - Interactive SQL report generator

=head1 VERSION

This document describes version 0.00_15 of DBIx::ReportBuilder, released
November 19, 2003.

=head1 SYNOPSIS

    use DBIx::ReportBuilder;
    my $obj = DBIx::ReportBuilder->new(
	Driver	    => 'mysql',
	Host	    => 'localhost',
	User	    => 'rt_user',
	Password    => 'rt_pass',
	Database    => 'rt3',
    );

    $obj->PartInsertP( text => "My Test Report" );
    $obj->PartInsertTable( table => 'users', text => 'User List' );

    $obj->ClauseInsertLimit( field => 'id', operator => '<', value => 20 );
    $obj->ClauseInsertCell( field => 'id', text => 'Id' );
    $obj->ClauseInsertCell( field => 'name', text => 'Name' );

    $obj->ClauseUp;		# move up; switch Name and Id
    $obj->ClauseDown;		# move down; switch Name and Id back
    $obj->ClauseRemove;		# delete the current clause

    print $obj->RenderHTML;	# prints a HTML rendered document
    print $obj->RenderEdit;	# prints an interactive Web UI
    print $obj->RenderPDF;	# prints PDF (not yet)

=head1 DESCRIPTION

This module is a subclass of B<XML::Twig>, specially tailored to render
SQL reports in various formats, based on B<DBIx::SearchBuilder>.

Its API is designed to interact with users via B<RTx::Report>'s
Web UI, which can incrementally construct complex reports.

=head1 NOTES

This is B<PRE-ALPHA> code.  Until the official release of B<RTx::Report>,
using this module for anything (except for learning purporses) is strongly
discouraged.

For more details on how to use this module, see the F<t/1-basic.t> file in
the source distribution.

=head1 METHODS

=cut

use constant Sections	=> qw( preamble header content footer postamble );
use constant Parts	=> qw( p img table graph include );
use constant Clauses	=> qw( join limit groupby orderby cell );
use constant Parameters	=> qw( name handle trigger clause_id part_id );
use constant Callbacks	=> qw( loc search_hook describe_report render_report );
use constant BaseClass	=> __PACKAGE__;

our $AUTOLOAD;
our @EXPORT_OK = qw( Sections Parts Clauses BaseClass Atts Att ucase lcase encode_src );
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub ucase {
    my $self = shift;
    return join('', map ucfirst, split(/_/, +shift));
}

sub lcase {
    my $self = shift;
    my $text = lcfirst(+shift);
    $text =~ s/([A-Z])/_\l$1/g;
    return $text;
}

BEGIN {
    no strict 'refs';
    foreach my $item (Parameters, Callbacks) {
	my $accessor = BaseClass->ucase($item);
	*{"$accessor"} = sub { $_[0]->{$item} };
	*{"Set$accessor"} = sub { $_[0]->{$item} = $_[1] };
	# alias for "HandleObj", etc
	*{"${accessor}Obj"} = sub { $_[0]->{$item} };
	*{"Set${accessor}Obj"} = sub { $_[0]->{$item} = $_[1] };
    }
    foreach my $item (Callbacks) {
	*{"$item"} = sub {
	    my $code = +shift->{$item} or return;
	    return $code->(@_);
	};
    }
}

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
	    (map { $_ => sub { $_->set_id($_[0]->NextSection) } } $class->Sections),
	    (map { $_ => sub { $_->set_id($_[0]->NextPart) } } $class->Parts),
	    (map { $_ => sub { $_->set_id($_[0]->NextClause) } } $class->Clauses),
	},
	pretty_print	=> 'indented_c',
    );
    $self->SetLoc( $args{Loc} || sub { $_[0] } );
    $self->SetDescribeReport( $args{DescribeReport} || sub { "#$_[0]" } );
    $self->SetRenderReport( $args{RenderReport} || sub { "<div>#$_[0]</div>" } );
    $self->SetHandle( $args{Handle} || $self->NewHandle( %args ) );
    $self->SetName( $args{Name} || $self->loc('(new)') );
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
    my $head = $root->insert_new_elt( last_child => 'head' );
    $head->insert_new_elt( last_child => 'meta', { name => $_, auto => 1 } )
	foreach $self->VarObj->Vars;

    my $body = $root->insert_new_elt( last_child => 'body' );
    $body->insert_new_elt( last_child => $_ )->insert_new_elt( 'p' )
	foreach $self->Sections;

    $head->set_att(orientation => 'portrait');
    $head->set_att(paper => 'A4');
    foreach my $key (map "margin_$_", qw/top bottom left right/) {
	$head->set_att($key => '200');
    }

    return $obj->sprint;
}

sub NewHandle {
    my $self = shift;

    require DBIx::SearchBuilder::Handle;
    my $obj = DBIx::SearchBuilder::Handle->new;
    $obj->Connect( DisconnectHandleOnDestroy => 1,  @_ ) or die $! if @_;

    return $obj;
}

sub GraphObj {
    my $self = shift;
    return eval { $self->spawn(Graph => @_) };
}

sub SearchObj {
    my ($self, %args) = @_;
    $args{Handle} ||= $self->Handle or return;
    return eval { $self->spawn(Search => %args) };
}

sub RenderObj {
    my $self = shift;
    my $type = shift || 'HTML';
    return $self->spawn("Render::$type" => ( Object => $self ) );
}

sub Render {
    my $self = shift;
    return $self->RenderObj(@_)->Render;
}

sub Reload {
    my $self = shift;
    $self->Parse($self->sprint);
    $self->ResetCounts;
    $self->VarObj->Reload;
    return $self;
}

sub Recount {
    my $self = shift;
    my $root = $self->root;

    $_->set_id($self->NextSection) for sort { $a->cmp($b) }
	map { $root->descendants($_) } $self->Sections;
    $_->set_id($self->NextPart) for sort { $a->cmp($b) }
	map { $root->descendants($_) } $self->Parts;
    $_->set_id($self->NextClause) for sort { $a->cmp($b) }
	map { $root->descendants($_) } $self->Clauses;

    $self->ResetCounts;

    return $self->PartId unless wantarray;
    return ($self->PartId, $self->ClauseId);
}

sub Section { +shift->_do(Section => @_) }
sub Part    { +shift->_do(Part => @_) }
sub Clause  { +shift->_do(Clause => @_) }

sub SectionObj { +shift->_obj(Section => @_) }
sub PartObj    { +shift->_obj(Part => @_) }
sub ClauseObj  { +shift->_obj(Clause => @_) }

sub NextSection { 'Section' . ++$_[0]{next_section} }
sub NextPart    { 'Part' . ++$_[0]{next_part} }
sub NextClause  { 'Clause' . ++$_[0]{next_clause} }
sub ResetCounts { @{$_[0]}{$_} = 0 for qw(next_section next_part next_clause) }

sub SectionId {
    my $self = shift;
    return $self->PartObj->parent->pos;
}

sub SetSectionId {
    my $self = shift;
    my $id   = shift;

    $self->SetPartId(
	$self->root->first_child('body')
		    ->first_child((Sections)[$id-1])
		    ->first_child->id
    ) unless ($self->SectionId == $id);

    return $id;
}

sub ClauseId {
    my $self = shift;
    $self->{clause_id} or return 0;
    my $obj = $self->ClauseObj($self->{clause_id}) or return 0;

    # if clause_id no longer belong into part, adjust it to 0
    $self->{clause_id} = 0
	if eval { $obj->parent->parent->id ne $self->PartObj->id };

    return $self->{clause_id};
}

sub SetPartId {
    my ($self, $id) = @_;
    $id ||= $self->root->first_child('body')
		 ->first_child('content')->first_child->id;
    $id =~ s/^Part//;
    $self->{part_id} = $id;
}

sub Atts {
    my ($self, $tag) = @_;
    $tag ||= $self->tag if $self->can('tag');
    return BaseClass->spawn('Attribute', Tag => $tag)->Attributes;
}

sub Att {
    my ($self, $att, $tag) = @_;
    $tag ||= $self->tag if $self->can('tag');
    return BaseClass->spawn(
	'Attribute',
	Object => $self, Att => $att, Tag => $tag,
    );
}

sub VarObj {
    my $self = shift;
    my $var  = $self->lcase(+shift);
    return BaseClass->spawn(
	'Variable',
	Object => $self, Var => $var,
    );
}

sub Vars {
    my $self = shift;
    return map $self->ucase($_), $self->VarObj->Vars;
}

sub Var		      { +shift->VarObj(+shift)->Value }
sub VarDefault	      { +shift->VarObj(+shift)->DefaultValue }
sub VarDescription    { +shift->VarObj(+shift)->Description }
sub RemoveVar	      { +shift->VarObj(+shift)->Remove(@_) } 
sub SetVar	      { +shift->VarObj(+shift)->SetValue(@_) }
sub SetVarDefault     { +shift->VarObj(+shift)->SetDefaultValue(@_) }
sub SetVarDescription { +shift->VarObj(+shift)->SetDescription(@_) }

sub VarInsert {
    my ($self, $var) = @_;
    my $obj = $self->ClauseObj || $self->PartObj or return;
    return unless $obj->Atts->[-1] eq 'text';
    $obj->insert_new_elt( last_child => 'var', { name => $self->lcase($var) } );
    return $obj->Id;
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

    my $rv = $obj->$Op(@_, Object => $self);
    $self->Recount if defined($rv);
    if (ref($rv)) {
	$rv = substr($rv->id, length($class));
    }
    else {
	$rv = $self->$getId + ($rv || 0);
    }
    return $self->$setId( $rv );
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

sub encode_src {
    require MIME::Base64;
    return "data:image/png;base64,".MIME::Base64::encode_base64($_[1]);
};

sub DESTROY {}

# PartInsertTable

sub AUTOLOAD {
    no warnings 'uninitialized';

    my $self = shift;
    $AUTOLOAD =~ /\b(VarInsert|Part|Clause|Render)(\w+?)(Obj)?$/
	or die "Undefined subroutine $AUTOLOAD";

    my $method = $1 . $3;
    my $op     = $2;
    my $tag    = $2 if ($method ne 'VarInsert')
		    and ($op =~ s/^([A-Z][a-z]+)((?:[A-Z][a-z]*)+)$/$1/);
    $self->$method($op => ($tag ? (tag => lc($tag)) : ()), @_);
}

1;

=head1 SEE ALSO

L<RTx::Report>, L<XML::Twig>, L<DBIx::SearchBuilder>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/Edit.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7952 $ $DateTime: 2003/09/07 20:09:05 $

package DBIx::ReportBuilder::Render::Edit;
use base 'DBIx::ReportBuilder::Render';
use strict;
use NEXT;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(
	%args,
	twig_handlers => {
	    html	=> \&html,
	    head	=> sub { $_->erase },
	    body	=> \&body,

	    preamble    => \&section,
	    header	=> \&section,
	    content	=> \&section,
	    footer	=> \&section,
	    postamble   => \&section,
	    part	=> \&part,  # called indirectly

	    graph	=> \&graph,
	    table	=> \&table,
	    p		=> \&p,
	    include	=> \&include,
	    img		=> \&img,

	    var		=> \&var,
	    %{$args{twig_handlers}||{}},
	},
	start_tag_handlers => {
	    content	=> \&enterContent,
	    %{$args{start_tag_handlers}||{}},
	},
	end_tag_handlers => {
	    content	=> \&leaveContent,
	    %{$args{end_tag_handlers}||{}},
	},
	twig_roots	=> {
	    'html'	=> 1,
	    %{$args{twig_roots}||{}},
	},
	pretty_print	=> ($args{pretty_print} || 'indented_c'),
    );

    return $self;
}

sub html {
    $_->del_att('xmlns');
    $_->set_tag('div');
    $_->set_att( align => 'center' );
}

sub body {
    $_->set_tag('table');
    $_->set_att(
	border	=> 0,
	style	=> 'border-bottom: 2px ridge',
	width	=> 870,
	name	=> 'ContentTable',
	bgcolor	=> '#a0a0a0',
	cellspacing => 0,
	cellpadding => 0,
    );
}

sub section {
    my $self = shift;
    my $section = $_;
    $self->part($_) for $section->children;
    $section->insert(
	'tr',
	'td' => {
	    width  => '92%', class => 'tableEmboss',
	    height => 42,    bgcolor => '#FFFFFF',
	},
	'table' => {
	    border => 0, width => '100%',
	    cellspacing => 0, cellpadding => 0,
	},
    );
    $section->first_child->insert_new_elt(
	'td' => {
	    width => '8%', class => 'tableTitle', height => 42,
	},
    )->set_text($self->loc($section->tag));
    $section->erase;
    1;
}

sub part {
    my $self = shift;
    my $part = shift;
    my $type = $part->tag;
    my $part_id = $self->NextPart;
    my $rand = rand();
    my $trigger = "parent.property.location.href='Property.html?".
		  "Type=$type&Id=$part_id&InContent=" . $self->inContent .
		  "&InPart=$type'"; # XXX - rand?
    my $checked = ($self->Object->PartId eq $part_id);
    $self->Object->SetTrigger($trigger) if $checked;
    my $color = ($checked ? '#6666cc' : 'white');
    $part->wrap_in(
	'td' => {
	    id	=> "PART_$part_id",
	    class => 'content',
	    onclick => "ClearAway(this, 'td');" .
			"if(clicked != 1){$trigger;};clicked=false",
	    style => "border-left:    solid $color 8px;" .
		     "border-right:   solid $color 8px;" .
		     "border-top:     solid $color 1px;" .
		     "border-bottom:  solid $color 1px;",
	},
	'tr' => { valign => 'top' },
    );
    $part->insert_new_elt(
	'before',
	'img' => {
	    width   => 19,
	    height  => 19,
	    align   => 'right',
	    valign  => 'absmiddle',
	    src	    => "/RG/img/obj\u$type.png",
	    alt	    => $self->loc($type),
	    title   => $self->loc($type),
	    style   => 'background: #e0e0e0; border: 1px black ridge',
	}
    );
}

sub graph {
}

sub table {
}

sub p {
    my $self = shift;
    $_->set_text(chr(0xA0)) unless length($_->text);
    $self->NEXT::p(@_);
}

sub include {
    $_->set_text(
	loc($_->tag) . ': ' .  $_->att('name')
    );
    $_->del_att('name');
    $_->set_tag('p');
}

sub img {
    $_->set_att('src' => '/RG/img/UploadIMG.png') unless $_->att;
}

sub var {
    my $self = shift;
    $_->set_text( $self->loc($_->tag) . ': ' .  $_->att('name') );
    $_->erase;
}

sub inContent { $_[0]->{in_content} || 0 }
sub enterContent { $_[0]->{in_content} = 1 }
sub leaveContent { $_[0]->{in_content} = 0 }

1;

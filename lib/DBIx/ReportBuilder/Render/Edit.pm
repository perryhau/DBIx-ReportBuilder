# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/Edit.pm $ $Author: autrijus $
# $Revision: #17 $ $Change: 8712 $ $DateTime: 2003/11/06 15:01:35 $

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
	    include	=> \&include,

	    var		=> \&var,
	    joins	=> \&clauses,
	    limits	=> \&clauses,
	    orderbys	=> \&clauses,
	    groupbys	=> \&clauses,
	    table	=> \&twigTable,
	    graph	=> \&twigGraph,
	    %{$args{twig_handlers}||{}},
	},
	start_tag_handlers => {
	    content	=> \&enterContent,
	    table	=> \&search,
	    graph	=> \&search,
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

sub clause {
    my ($self, $clause, $clause_cur, $part_id) = @_;
    my $clause_id = $1 if $clause->id =~ /(\d+)$/;
    my $checked = ($clause_id eq $clause_cur);

    $clause->set_att( bgcolor => ($checked ? '#6666cc' : 'gray') );

    my $trigger = "parent.property.location.href='Property.html?".
		  "ClauseId=$clause_id&PartId=$part_id';";
    $clause->set_att(
	onclick => "ClearAway(this, 'th');$trigger",
    );
    $self->Object->SetTrigger($trigger) if $checked;
}

sub twigTable {
    my $self    = shift;
    my $part    = shift or return;
    my $part_id = shift || $part->id;
    my $clause_cur = $self->Object->ClauseId;

    my $cnt = 0;
    foreach my $th ($part->find_nodes('thead/tr/th')) {
	$th->insert_new_elt($self->type_icon('cell', 'left'));
	$self->clause($th, $clause_cur, $part_id);
	$cnt++;
    }

    $part->set_att(border => '3');
    $part->set_att(bgcolor => '#c9c9c9');

    my $tbody = $part->first_child('tbody');
    if ($cnt and $tbody) {
	my $tr = $tbody->insert_new_elt(last_child => 'tr');
	$tr->insert_new_elt('td', '...') for 1 .. $cnt;
    }

    my $clauses = $part->att('#Clauses') || $part->parent('#Clauses') or return;
    return unless @$clauses;

    $tbody = $part->insert_new_elt(last_child => 'tbody');

    foreach my $item (@$clauses) {
	foreach my $clause ($item->children) {
	    no warnings 'uninitialized';
	    my $th = $tbody->insert_new_elt(last_child => 'tr')
		  ->insert_new_elt('th',
		      { bgcolor => 'gray', colspan => ($cnt || 1),
		        align => 'left', style => 'font-size: small' });
	    $th->set_text( join(
		', ',
		map {
		    $self->Object->loc($self->Object->ucase($_)) .
			" => '" .
		    (($_ eq 'text') ? $clause->text : $clause->att($_)) .
			"'"
		} $self->Object->Atts($clause->tag)
	    ) );
	    $th->insert_new_elt($self->type_icon($clause->tag, 'left'));
	    $th->set_id($clause->id);
	    $self->clause($th, $clause_cur, $part_id);
	}
    }
}

sub twigGraph {
    my $self = shift;
    my $item = shift;
    $self->twigTable($item, @_);

    $item->set_tag('table');
    $item->set_att(
	'#Tag'	    => 'graph',
	'width'	    => '100%',
	'border'    => '3',
    );

    $self->plotGraph($item);
}

sub part {
    my ($self, $part) = @_;
    my $type = $part->att('#Tag') || $part->tag;

    my $part_id = $self->NextPart;
    $self->$type($part, $part_id);

    my $trigger = "parent.property.location.href='Property.html?".
		  "PartId=$part_id'";
    my $checked = ($self->Object->PartId eq $part_id);
    $self->Object->SetTrigger($trigger)
	if $checked and !$self->Object->Trigger;
    my $color = ($checked ? '#6666cc' : 'white');
    $part->wrap_in(
	'td' => {
	    id	=> "Part$part_id",
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
    $part->parent->parent->insert_new_elt(
	'last_child', 'td', { width => 19 }
    )->insert_new_elt($self->type_icon($type));
}

sub search {
    my $self = shift;
    $_->set_att(rows => 2) unless $_->tag eq 'graph';
    $_->set_att('#Clauses' => []);
    $self->NEXT::search(@_);
}

sub clauses {
    my $self = shift;
    my $item = $_;
    push @{$item->parent->att('#Clauses')}, $item->copy;
    my $method = "SUPER::" . $item->tag;
    $self->$method(@_);
}

sub p {
    my $self = shift;
    $_->set_text(chr(0xA0)) unless length($_->text);
    $self->NEXT::p(@_);
}

sub include {
    my $self = shift;
    $_->set_text(
	$self->Object->loc($_->tag) .
	': ' .
	$self->Object->describe_report($_->att('report'))
    );
}

sub img {
    $_->set_att('src' => '/RG/img/imgUpload.png') unless $_->att('src');
}

sub var {
    my $self = shift;
    my $item = $_;
    $self->NEXT::var(@_);
    $item->set_att('style' => 'background: gray');
}

sub inContent { $_[0]->{in_content} || 0 }
sub enterContent { $_[0]->{in_content} = 1 }
sub leaveContent { $_[0]->{in_content} = 0 }

sub type_icon {
    my ($self, $type, $align) = @_;
    return 'img' => {
	width   => 19,
	height  => 19,
	align   => ($align || 'right'),
	valign  => 'absmiddle',
	src	    => "/RG/img/obj\u$type.png",
	alt	    => $self->loc($type),
	title   => $self->loc($type),
	style   => 'background: #e0e0e0; border: 1px black ridge',
    }
}

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render.pm $ $Author: autrijus $
# $Revision: #27 $ $Change: 8715 $ $DateTime: 2003/11/06 15:50:39 $

package DBIx::ReportBuilder::Render;

use strict;
use Safe;
use DBIx::ReportBuilder ':all';
use base 'XML::Twig';

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(
	twig_handlers => {
	    cells	=> \&cells,
	    join	=> \&join,
	    cell	=> \&cell,
	    limit	=> \&limit,
	    orderby     => \&orderby,
	    groupby     => \&groupby,
	    table	=> \&table,
	    graph	=> \&graph,
	    joins	=> \&joins,
	    limits	=> \&limits,
	    orderbys    => \&orderbys,
	    groupbys    => \&groupbys,
	    var		=> \&var,
	    meta	=> \&meta,
	    include	=> \&include,
	    %{$args{twig_handlers}||{}},
	},
	start_tag_handlers => {
	    table	=> \&search,
	    graph	=> \&search,
	    %{$args{start_tag_handlers}||{}},
	},
	end_tag_handlers => {
	    %{$args{end_tag_handlers}||{}},
	},
	twig_roots	=> {
	    %{$args{twig_roots}||{}},
	    'html'	=> 1
	},
	pretty_print	=> $args{pretty_print},
    );

    my $obj = $args{Object} or die "Must have object";
    $self->SetObject($obj);
    $self->parse( $obj->sprint );
    return $self;
}

sub Render { $_[0]->root->sprint }
sub Object { $_[0]->{object} }
sub SetObject { $_[0]->{object} = $_[1] }

sub NextPart { ++$_[0]->{next_part} }

sub loc {
    my $self = shift;
    $self->Object->loc(@_);
}

sub p {
    my %atts = %{$_->atts};
    $_->del_att( Atts($_) );
    $_->insert(font => { face => $atts{font} }) if $atts{font};
    $_->set_att(align => $atts{align}) if $atts{align};
    my $style;
    $style .= "border: $atts{border}px black solid;" if $atts{border};
    $style .= "font-size: $atts{size};" if $atts{size};
    $_->set_att(style => $style) if $style;
}

sub cells {
    my $self = shift;
    my $item = $_;
    my @children = $item->cut_children;
    my $tr = $item->insert('thead', 'tr');
    my $Headers = $item->parent->att('#Headers');

    foreach my $item (@children) {
	my $th = $tr->insert_new_elt(last_child => 'th');
	$th->set_text($item->text);
	$th->set_att( %{$_->atts} );
	$th->set_id($item->id);
	$item->set_tag('td');
	push @$Headers, $item->text;
    }

    $item->insert_new_elt(last_child => 'tbody')
	if $item->parent->tag eq 'table';

    $self->_do_search(
	$item,
	$item->parent->att('#Tables'),
	$item->parent->att('#SearchBuilder'),
	$item->parent->att('#Result'),
	$item->last_child('tbody'),
	\@children,
    );

    $item->erase;
}

sub _do_search {
    my ($self, $item, $tables, $SB, $result, $tbody, $children) = @_;

    return unless $SB;
    if (my $code = $self->Object->SearchHook) {
	$code->($item, $tables, $SB);
    }
    $SB->RedoSearch;

    my @fields = map { $_->att('field') } @$children;
    my %vars = map {
	$self->Object->lcase($_) => $self->Object->Var($_),
	$self->Object->ucase($_) => $self->Object->Var($_),
    } $self->Object->Vars;

    $SB->DEBUG(1) if $::DEBUG;

    my $tr_cnt = -1;
    while (my $Record = $SB->Next) {
	my $tr = $tbody->insert_new_elt(last_child => 'tr') if $tbody;
	my $td_cnt = -1; ++$tr_cnt;
	foreach my $item (@$children) {
	    my $td = $item->copy;
	    my $text = $Record->{$item->att('#Column')};
	    my $formula = $td->att('formula');
	    if (defined($formula) and length($formula)) {
		my $safe = Safe->new;
		$safe->permit(qw(:base_core :base_math));

		while (my ($k, $v) = each %vars) {
		    ${$safe->varglob($k)} = $v;
		}
		${$safe->varglob('_')} = $text;
		${$safe->varglob($_)} = $Record->{$_} for @fields;

		local $SIG{FPE}		= sub {};
		local $SIG{__WARN__}	= sub {};
		local $SIG{__DIE__}	= sub {};
		$text = $safe->reval($formula);
	    }

	    if (!$tr) {
		# this is a graph part
		$result->[++$td_cnt][$tr_cnt] = $text;
		next;
	    }
	    $td->set_text($text);
	    $td->del_att(qw( id field formula ));
	    $td->paste(last_child => $tr);
	}
    }
}

sub table {
    my $self = shift;
    my $item = $_;

    $item->set_att(width => '100%');
    $item->insert_new_elt('caption', {
	map { $_ => $item->att($_) } grep { $item->att($_) } qw( font size )
    }, $item->att('caption') );
    $item->del_att(grep !/border/, Atts($item));
}

sub graph {
    my $self = shift;
    my $item = $_;
    $self->table($item);
}

sub search {
    my $self = shift;
    my $SB = $self->Object->SearchObj or die "Cannot make Search";
    $SB->SetTable($_->att('table'));
    $SB->UnLimit;

    if (my $item = $_->att('rows')) {
	$SB->RowsPerPage( $item )
    }
    if (my $item = $_->att('firstrow')) {
	$SB->FirstRow( $item )
    }

    $_->set_att(
	'#Tables'	    => {
	    ($SB->Table) => ''		# key: table, val: alias
	},
	'#OrderBy'	    => [],	# passed to OrderByCols
	'#GroupBy'	    => [],	# passed to GroupByCols
	'#SearchBuilder'    => $SB,	# SearchBuilder object
	'#Result'	    => [],	# result set
	'#Headers'	    => [],	# header set
    );
}

sub _alias {
    my $Tables = $_[0]->parent->parent->att('#Tables');
    my $rv = $Tables->{$_[0]->att('table')} or return;
    return (ALIAS => $rv);
};

sub join {
    my $item  = $_;
    my $SB     = $item->parent->parent->att('#SearchBuilder');
    my $Tables = $item->parent->parent->att('#Tables');
    $Tables->{$_->att('table2')} = $SB->Join(
	TYPE	=> ($item->att('type') || 'left'),
	ALIAS1	=> ($Tables->{$item->att('table') || ''} || 'main'),
	FIELD1	=> $item->att('field'),
	TABLE2	=> $item->att('table2'),
	FIELD2	=> $item->att('field2'),
	map { uc($_) => $item->att($_) } $item->att_names
    );
}

sub limit {
    my $item = $_;
    my $SB = $item->parent->parent->att('#SearchBuilder');
    $SB->Limit(
	CASESENSITIVE => 1,
	VALUE	      => $item->text,
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    );
}

sub cell {
    my $item = $_;
    my $SB = $item->parent->parent->att('#SearchBuilder');
    $item->set_att('#Column', $SB->Column(
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    ));
}

sub orderby {
    my $item = $_;
    my $OrderBy = $item->parent->parent->att('#OrderBy');
    push @$OrderBy, {
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    }
}

sub orderbys {
    my $item    = $_;
    my $SB      = $item->parent->att('#SearchBuilder');
    my $OrderBy = $item->parent->att('#OrderBy');
    $SB->OrderByCols( @$OrderBy ) if @$OrderBy;
    $_->delete;
}

sub groupby {
    my $item = $_;
    my $GroupBy = $item->parent->parent->att('#GroupBy');
    push @$GroupBy, {
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    }
}

sub groupbys {
    my $item    = $_;
    my $SB      = $item->parent->att('#SearchBuilder');
    my $GroupBy = $item->parent->att('#GroupBy');
    $SB->GroupByCols( @$GroupBy ) if @$GroupBy;
    $_->delete;
}

sub joins { $_->delete }
sub limits { $_->delete }
sub meta { $_->delete }

sub var {
    my $self = shift;
    my $item = $_;
    $item->set_text( $self->Object->Var( $item->att('name')) );
    $item->set_tag('span');
    $item->del_att('name');
}

sub include {
    XML::Twig::Elt->parse(
	$_[0]->Object->render_report($_->att('report'))
    )->replace($_);
}

sub plotGraph {
    my ($self, $item) = @_;

    my $graph = $self->Object->GraphObj(
	%{ $item->atts },
	width  => 400,
	height => 300,
    ) or return;

    my $png = $graph->Plot(
	labels	=> $item->att('#Headers'),
	data	=> $item->att('#Result'),
    ) or return;

    $item->insert_new_elt(div => { align => 'center' })
	 ->insert_new_elt(img => { src => $self->Object->encode_src($png) });
}

sub HeadDimensions {
    my ($self, $item) = @_;
    my $size = $self->PageToDimensions->{$item->att('paper')};
    $size ||= $self->PageToDimensions->{'A4'};

    my $margins;
    foreach my $key (map "margin_$_", qw/top right bottom left/) {
	my $margin = $item->att($key);
	$margin = '200' unless length($margin);
	$margins .= "${margin}mm ";
    }

    if ($item->att('orientation') eq 'landscape') {
	$size = join(' ', reverse split(/ /, $size));
    }

    return "
	\@page { size: $size; margin: $margins}
	P { margin-bottom: 0.21cm }
	TH P { margin-bottom: 0.21cm; font-style: italic }
	TD P { margin-bottom: 0.21cm }
    ";
}

use constant PageToDimensions => {
    A1 => "59.4cm 84cm",
    A2 => "42cm 59.4cm",
    A3 => "29.7cm 42cm",
    A4 => "21cm 29.7cm",
    A5 => "14.85cm 21cm",
    B1 => "70.7cm 100cm",
    B2 => "50cm 70.7cm",
    B3 => "35.3cm 50cm",
    B4 => "25cm 35.3cm",
    B5 => "17.7cm 25cm",
};

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render.pm $ $Author: autrijus $
# $Revision: #9 $ $Change: 7992 $ $DateTime: 2003/09/08 22:34:50 $

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
	    limit	=> \&limit,
	    orderby     => \&orderby,
	    table	=> \&table,
	    graph	=> \&graph,
	    joins	=> \&joins,
	    limits	=> \&limits,
	    orderbys    => \&orderbys,
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
    my $SB = $item->parent->att('SearchBuilder');
    my @children = $item->cut_children;
    my $tr = $item->insert('thead', 'tr');
    foreach my $item (@children) {
	my $th = $tr->insert_new_elt(last_child => 'th');
	$th->set_text($item->text);
	$th->set_att( %{$_->atts} );
	$th->set_id($item->id);
	$item->set_tag('td');
    }
    my $tbody = $item->insert_new_elt(last_child => 'tbody');
    while (my $Record = $SB->Next) {
	my $tr = $tbody->insert_new_elt(last_child => 'tr');
	my @fields = map { $_->att('field') } @children;

	foreach my $item (@children) {
	    my $td = $item->copy;
	    my $text = $Record->{$td->att('field')};
	    my $formula = $td->att('formula');
	    if (defined($formula) and length($formula)) {
		my $safe = Safe->new;
		$safe->permit(qw(:base_core :base_math));
		${$safe->varglob('_')} = $text;
		${$safe->varglob($_)} = $Record->{$_} for @fields;

		local $SIG{FPE}		= sub {};
		local $SIG{__WARN__}	= sub {};
		local $SIG{__DIE__}	= sub {};
		$text = $safe->reval($formula);
	    }
	    $td->set_text($text);
	    $td->del_att(qw( id field formula ));
	    $td->paste(last_child => $tr);
	}
    }
    $item->parent->del_att(qw( Tables OrderBy SearchBuilder ));
    $item->erase;
}

sub table {
    my $self = shift;
    my $item = $_;

    $item->set_att(width => '100%');
    $item->insert_new_elt('caption', {
	map { $_ => $item->att($_) } grep { $item->att($_) } qw( font size )
    }, $item->att('caption') );
    $item->del_att(Atts($item));
}

sub graph {
    my $self = shift;
    my $item = $_;
    $_ = $item->insert('table');
    return $self->table;
}

sub search {
    my $self = shift;
    my $Handle = $self->Object->Handle or die "No Handle";
    my $SB = $self->BaseClass->spawn(Search => ( Handle => $Handle ));
    $SB->{table} = $_->att('table');
    $SB->UnLimit;

    if (my $item = $_->att('rows')) {
	$SB->RowsPerPage( $item )
    }
    if (my $item = $_->att('firstrow')) {
	$SB->FirstRow( $item )
    }

    $_->set_att('Tables' => {});	    # key: table, val: alias
    $_->set_att('OrderBy' => []);
    $_->set_att('SearchBuilder' => $SB);
}

sub _alias {
    my $Tables = $_[0]->parent->parent->att('Tables');
    my $rv = $Tables->{$_[0]->att('table')} or return;
    return (ALIAS => $rv);
};

sub join {
    my $item  = $_;
    my $SB     = $item->parent->parent->att('SearchBuilder');
    my $Tables = $item->parent->parent->att('Tables');
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
    my $SB = $item->parent->parent->att('SearchBuilder');
    $SB->Limit(
	CASESENSITIVE => 1,
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    );
}

sub orderby {
    my $item = $_;
    my $OrderBy = $item->parent->parent->att('OrderBy');
    push @$OrderBy, {
	(map { uc($_) => $item->att($_) } $item->att_names),
	_alias($item),
    }
}

sub orderbys {
    my $item    = $_;
    my $SB      = $item->parent->att('SearchBuilder');
    my $OrderBy = $item->parent->att('OrderBy');
    $SB->OrderByCols( @$OrderBy ) if @$OrderBy;
    $_->delete;
}

sub joins { $_->delete }
sub limits { $_->delete }

1;

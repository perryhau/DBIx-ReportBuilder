# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7952 $ $DateTime: 2003/09/07 20:09:05 $

package DBIx::ReportBuilder::Render;

use strict;
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
	    joins	=> sub { $_->delete },
	    limits	=> sub { $_->delete },
	    orderbys    => \&orderbys,
	    graph	=> sub { $_->delete },
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

sub Object { $_[0]->{object} }
sub SetObject { $_[0]->{object} = $_[1] }

sub NextPart { ++$_[0]->{next_part} }

sub loc {
    my $self = shift;
    $self->Object->loc(@_);
}

sub p {
    my %atts = %{$_->atts};
    $_->del_att( DBIx::ReportBuilder->Attrs($_->tag) );
    $_->insert(font => { face => $atts{font} }) if $atts{font};
    $_->set_att(align => $atts{align}) if $atts{align};
    my $style;
    $style .= "border: $atts{border}px black solid;" if $atts{border};
    $style .= "font-size: $atts{size};" if $atts{size};
    $_->set_att(style => $style) if $style;
}

sub cells {
    my $self = shift;
    my $SB = $_->parent->att('SearchBuilder');
    my @children = $_->cut_children;
    my $tr = $_->insert('thead', 'tr');
    foreach my $item (@children) {
	my $th = $tr->insert_new_elt(last_child => 'th');
	$th->set_text($item->text);
	$th->set_att( %{$_->atts} );
	$item->set_tag('td');
    }
    my $tbody = $_->insert_new_elt(last_child => 'tbody');
    while (my $Record = $SB->Next) {
	my $tr = $tbody->insert_new_elt(last_child => 'tr');
	foreach my $item (@children) {
	    my $td = $item->copy;
	    $td->set_text($Record->{$td->att('field')});
	    $td->del_att('field');
	    $td->paste(last_child => $tr);
	}
    }
    $_->parent->del_att(qw( Alias OrderBy SearchBuilder ));
    $_->parent->del_att($self->Attrs($_->parent->tag));
    $_->erase;
}

sub search {
    my $self = shift;
    my $SB = $self->BaseClass->spawn(Search => ( Handle => $self->Object->Handle ));
    $SB->{table} = $_->att('table');
    $SB->UnLimit;

    if (my $item = $_->att('rows')) {
	$SB->RowsPerPage( $item )
    }
    if (my $item = $_->att('firstrow')) {
	$SB->FirstRow( $item )
    }

    $_->set_att('Alias' => {});
    $_->set_att('OrderBy' => []);
    $_->set_att('SearchBuilder' => $SB);
}

sub _alias {
    my $Alias = $_[0]->parent->parent->att('Alias');
    my $rv = $Alias->{$_[0]->att('alias')} or return;
    return (ALIAS => $rv);
};

sub join {
    my $item  = $_;
    my $SB    = $item->parent->parent->att('SearchBuilder');
    my $Alias = $item->parent->parent->att('Alias');
    $Alias->{$_->att('alias')} = $SB->Join(
	map { uc($_) => $item->att($_) } $item->att_names
    );
}

sub limit {
    my $item = $_;
    my $SB = $item->parent->parent->att('SearchBuilder');
    $SB->Limit(
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

1;

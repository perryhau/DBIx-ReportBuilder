# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Attribute.pm $ $Author: autrijus $
# $Revision: #30 $ $Change: 8385 $ $DateTime: 2003/10/12 16:24:57 $

package DBIx::ReportBuilder::Attribute;
use strict;

sub new {
    my $class = shift;
    return bless({ @_ }, $class);
}

sub Att	    { $_[0]{Att} }
sub Tag	    { $_[0]{Tag} }
sub Object  { $_[0]{Object} }
sub Name    { $_[0]->Object->ucase($_[0]{Att}) }
sub Type    { $_[0]->Data->{$_[0]->{Att}}->{type} }
sub ReportBuilderObj { $_[0]->Object->twig }

sub Value {
    my $self = shift;
    my $obj  = $self->Object or return;
    my $att  = $self->Att;

    return $obj->att($att) unless $att eq 'text';

    # Text attribute needs $Var escaping

    $obj = $obj->copy;
    foreach my $var ($obj->children('var')) {
	$var->set_text('${' . $self->Object->ucase($var->att('name')) . '}');
    }
    my $text = $obj->text;
    $text =~ s/\$\{(\w+)\}(?!\w)/\$$1/g;
    return $text;
}

sub Attributes {
    my $self  = shift;
    my $array = $self->Tag2Attributes->{$self->Tag} or return;
    return wantarray ? @$array : $array;
}

sub Values {
    my $rv = $_[0]->Data->{$_[0]->{Att}}->{values} or return;
    return $rv->($_[0]) if UNIVERSAL::isa($rv => 'CODE');
    return wantarray ? @$rv : $rv;
}

sub Default {
    my $rv = $_[0]->Data->{$_[0]->{Att}}->{default} or return;
    return $rv->($_[0]) if UNIVERSAL::isa($rv => 'CODE');
    return wantarray ? @$rv : $rv;
}

sub Applicable {
    return if !$_[0]->Attribute2Tags->{$_[0]->{Att}}{$_[0]->Tag || ''};
    my $rv = $_[0]->Data->{$_[0]->{Att}}->{applicable} or return 1;
    return $rv->($_[0]);
}

use constant Tag2Attributes => {
    p           => [ qw( font size border align text ) ],
    img         => [ qw( width height src ) ],
    include     => [ qw( report ) ],
    table       => [ qw( table rows font size border caption ) ],
    graph       => [ qw( table shape style legend threed threed_shading cumulate
			 show_values values_vertical rotate_chart caption ) ],
    join	=> [ qw( table field table2 field2 ) ], # type
    limit	=> [ qw( table field operator text ) ], # entryaggregator 
    orderby	=> [ qw( table field order ) ],
    cell	=> [ qw( table field font size align formula text ) ],
};

use constant Data => {
    align		=> {
	type		=> 'radio',
	values		=> [qw( left center right )],
	default		=> 'left',
    },
    border		=> {
	type		=> 'select',
	values		=> [ 0 .. 4 ],
    },
    caption		=> {
	type		=> 'text',
    },
    field		=> {
	type		=> 'data_source',
	values		=> \&_fields,
	applicable	=> sub {
	    $_[0]->Object->att('table') or
	    $_[0]->Object->parent->parent->att('table')
	},
    },
    field2		=> {
	type		=> 'data_source',
	values		=> \&_fields2,
	applicable	=> sub { $_[0]->Object->att('table2') },
    },
    font		=> {
	type		=> 'select',
	values		=> \&_fonts,
    },
    formula		=> {
	type		=> 'text',
    },
    height		=> {
	type		=> 'number',
    },
    report		=> {
	type		=> 'include',
    },
    operator		=> {
	type		=> 'select',
	values		=> [ qw( = != < > ), 'LIKE', 'NOT LIKE', 'STARTSWITH', 'ENDSWITH' ],
	default		=> '=',
    },
    order		=> {
	type		=> 'radio',
	values		=> [ qw( ASC DESC ) ],
	default		=> 'ASC',
    },
    rows		=> {
	type		=> 'number',
    },
    size		=> {
	type		=> 'select',
	values		=> [ map { ($_*2) } 3..10 ],
	default		=> 12,
    },
    src			=> {
	type		=> 'image',
    },
    table		=> {
	type		=> 'data_source',
	values		=> \&_tables,
	default		=> sub { $_[0]->Object->parent->parent->att('table') },
    },
    table2		=> {
	type		=> 'data_source',
	values		=> \&_tables2,
    },
    text		=> {
	type		=> 'text',
    },
    width		=> {
	type		=> 'number',
    },
    # ------------------------------------------ #
    shape	=> {
	type		=> 'select',
	values		=> [qw(bars lines pie)],
	default		=> 'bars',
    },
    style	=> {
	type		=> 'select',
	values		=> sub {
	    ($_[0]->Object->att('shape') eq 'bars')
		? qw(bar cylinder)
		: qw(line dots)
	},
	applicable	=> \&_is_axis,
	default		=> 'bar',
    },
    legend	=> {
	type		=> 'boolean',
	applicable	=> \&_is_axis,
	default		=> 0,
    },
    (map { substr($_, 0, 1) . '_margin' => {
	type		=> 'number',
	default		=> 0,
    } } qw(top bottom left right)),
    (map { $_."_font" => {
	type		=> 'select',
	values		=> [qw(ming kai)],
 	default		=> 'ming'},
	   $_."_fontsize" => {
	type		=> 'number',
	default		=> 12,
     } } qw(title legend)),
    (map { $_."_font" => {
	type		=> 'select',
	values		=> [qw(ming kai)],
	applicable	=> \&_is_axis,
 	default		=> 'ming'},
	   $_."_fontsize" => {
	type		=> 'number',
	applicable	=> \&_is_axis,
	default		=> 12,
     } }  qw(x_label y_label x_axis y_axis values)),
    (map { $_."_font" => {
	type		=> 'select',
	values		=> [qw(ming kai)],
	applicable	=> \&_is_axis,
 	default		=> 'ming'},
	   $_."_fontsize" => {
	type		=> 'number',
	applicable	=> \&_is_axis,
	default		=> 12,
     } } qw(label value)),
    accentclr	=> {
	type		=> 'select',
	values		=> [qw(
	    white lgray gray dgray black lblue blue dblue
	    gold lyellow yellow dyellow lgreen green dgreen
	    lred red dred lpurple purple dpurple lorange
	    orange pink dpink marine cyan lbrown dbrown
	)],
	default		=> 'black',
    },
    cumulate	=> {
	type		=> 'boolean',
	applicable	=> sub { $_[0]->Object->att('shape') eq 'bars' },
	default		=> 0,
    },
    show_values	=> {
	type		=> 'boolean',
	default		=> 0,
    },
    values_vertical	=> {
	type		=> 'boolean',
	applicable	=> sub { $_[0]->Object->att('show_values') },
	default		=> 0,
    },
    rotate_chart	=> {
	type		=> 'boolean',
	default		=> 0,
    },
    threed		=> {
	type		=> 'boolean',
	default		=> 1,
    },
    threed_shading	=> {
	type		=> 'boolean',
	applicable	=> sub { $_[0]->Object->att('threed') },
	default		=> 1,
    },
};

use constant Attribute2Tags => do {
    my %a2t; 
    while (my ($k, $v) = each %{+Tag2Attributes}) {
	$a2t{$_}{$k}++ for @$v;
    }
    $a2t{$_}{''}++ for keys %a2t;
    \%a2t;
};

sub _fonts { 'serif', 'sans serif', 'monotype' }

sub _fields {
    my $self = shift;
    my $att  = shift || 'table';
    my $obj  = $self->Object;
    my $table = $obj->att($att) || $obj->parent->parent->att($att) or return;
    return $obj->twig->SearchObj->Fields($table);
}

sub _fields2 {
    my $self = shift;
    return $self->_fields( 'table2' );
}

sub _tables {
    my $self = shift;
    my $tag = $self->Object->tag;
    if ($self->Att eq 'table2' or $tag eq 'table' or $tag eq 'graph') {
	return sort map { /(\w+)\W*$/ ? lc($1) : lc($_) }
	    $self->ReportBuilderObj->Handle->dbh->tables;
    }
    else {
	# limit only to those accessible by us
	my %tables;
	my $obj = $self->Object->parent->parent or return;
	$tables{ $obj->att('table') }++;
	foreach my $clause ($obj->first_child('joins')->children) {
	    $tables{ $clause->att('table2') }++;
	}
	return sort map lc, grep defined, grep length, keys %tables;
    }
}
sub _tables2 { goto &_tables }

sub _is_axis { $_[0]->Object->att('shape') ne 'pie' }

1;

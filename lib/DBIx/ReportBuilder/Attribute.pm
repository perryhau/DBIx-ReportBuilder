# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Attribute.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 7983 $ $DateTime: 2003/09/08 17:03:47 $

package DBIx::ReportBuilder::Attribute;
use strict;

sub new {
    my $class = shift;
    return bless({ @_ }, $class);
}

sub Tag { $_[0]{Tag} }
sub Object { $_[0]{Object} }

sub Attributes {
    my $self  = shift;
    my $array = $self->Tag2Attributes->{$self->Tag};
    return wantarray ? @$array : $array;
}

sub Type {
    $_[0]->Data->{$_[0]->{Att}}->{type}
}

sub Default {
    $_[0]->Data->{$_[0]->{Att}}->{default}
}

sub Values {
    my $rv = $_[0]->Data->{$_[0]->{Att}}->{values} or return;
    return $rv->($_[0]) if UNIVERSAL::isa($_[0] => 'CODE');
    return wantarray ? @$rv : $rv;
}

sub Applicable {
    return if !$_[0]->Attribute2Tags->{$_[0]->{Att}}{$_[0]->Tag || ''};
    my $rv = $_[0]->Data->{$_[0]->{Att}}->{applicable} or return 1;
    return $rv->($_[0]);
}

use constant Tag2Attributes => {
    p           => [ qw( align font size border text ) ],
    img         => [ qw( width height src ) ],
    include     => [ qw( report ) ],
    table       => [ qw( table rows font size border caption ) ],
    graph       => [ qw( table shape style legend threed threed_shading cumulate
			 show_values values_vertical rotate_chart caption ) ],
    join	=> [ qw( table field table2 field2 ) ],  # type
    limit	=> [ qw( table field operator value ) ], # entryaggregator 
    orderby	=> [ qw( table field order ) ],
    cell	=> [ qw( field align font size formula ) ],
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
	type		=> 'select',
	values		=> \&_fields,
	applicable	=> sub { $_[0]->att('table') },
    },
    field2		=> {
	type		=> 'select',
	values		=> \&_fields2,
	applicable	=> sub { $_[0]->att('table2') },
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
	type		=> 'select',
	values		=> \&_reports,
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
	type		=> 'select',
	values		=> \&_tables,
    },
    table2		=> {
	type		=> '',
	values		=> \&_tables2,
    },
    text		=> {
	type		=> 'text',
    },
    value		=> {
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
	values		=> [qw(bar cylinder)],
	disabled	=> sub { $_[0]->Object->att('type') ne 'bars' },
	default		=> 'bar',
    },
    legend	=> {
	type		=> 'boolean',
	disabled	=> sub { $_[0]->Object->att('type') eq 'pie' },
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
	disabled	=> sub { $_[0]->Object->att('type') eq 'pie' },
 	default		=> 'ming'},
	   $_."_fontsize" => {
	type		=> 'number',
	disabled	=> sub { $_[0]->Object->att('type') eq 'pie' },
	default		=> 12,
     } }  qw(x_label y_label x_axis y_axis values)),
    (map { $_."_font" => {
	type		=> 'select',
	values		=> [qw(ming kai)],
	disabled	=> sub { $_[0]->Object->att('type') ne 'pie' },
 	default		=> 'ming'},
	   $_."_fontsize" => {
	type		=> 'number',
	disabled	=> sub { $_[0]->Object->att('type') ne 'pie' },
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
	disabled	=> sub { $_[0]->Object->att('type') ne 'bars' },
	default		=> 0,
    },
    show_values	=> {
	type		=> 'boolean',
	default		=> 0,
    },
    values_vertical	=> {
	type		=> 'boolean',
	disabled	=> sub { $_[0]->Object->att('show_values') },
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
	disabled	=> sub { $_[0]->Object->att('threed') },
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

sub _fonts { 'ming', 'kai' }
sub _reports { }
sub _fields {}
sub _fields2 {}
sub _tables {}
sub _tables2 {}

1;

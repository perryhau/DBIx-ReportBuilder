# $File: //member/autrijus/DBIx-ReportBuilder/t/1-basic.t $ $Author: autrijus $
# $Revision: #28 $ $Change: 8063 $ $DateTime: 2003/09/12 01:08:45 $

use Test::More tests => 165;
use FindBin;

use strict;
use lib "$FindBin::Bin/../lib";
local $SIG{__WARN__} = sub {
    print $_[0] unless $_[0] =~ m{XML/Twig|DBIx\W+SearchBuilder}
};

# Database - mysql, [ODBC] {{{

use_ok('DBIx::ReportBuilder');

my $obj = eval {
    local $SIG{__WARN__} = sub {};
    DBIx::ReportBuilder->new(
	Driver	    => 'mysql',
	Host	    => 'localhost',
	Port	    => (($^O eq 'MSWin32') ? 8285 : 3306),
	User	    => 'root',
	Database    => 'rt3',
    )
} || DBIx::ReportBuilder->new;

# }}}
# Object - ReportBuilder, Render, Part, Clause {{{

isa_ok($obj, 'DBIx::ReportBuilder');
isa_ok($obj->Handle, 'DBIx::SearchBuilder::Handle');
isa_ok($obj->RenderObj, 'DBIx::ReportBuilder::Render');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::P');
is($obj->ClauseObj, undef, 'ClauseObj is undefined');

# }}}
# Document - HTML, Edit, XML, [SXW] {{{

my $render = $obj->RenderEdit;
is($obj->RenderEdit, $render, 'RenderEdit consistency');
is($obj->RenderHTML, $obj->RenderHTML, 'RenderHTML consistency');
is($obj->RenderSXW, $obj->RenderSXW, 'RenderSXW consistency');
is($obj->RenderXML,
    '<?xml version="1.0" encoding="UTF-8"?>' . "\n" . $obj->root->sprint,
    'RenderXML consistency');
is($obj->Render, $obj->RenderHTML, 'Render means RenderHTML');
# }}}
# Navigation - Cursor position, Reload, Recount {{{

is($obj->PartId, 3, 'PartId autoposition');
is($obj->SectionId, 3, 'SectionId autoposition');
is($obj->ClauseId, 0, 'ClauseId does not have autoposition');
ok($obj->Reload, 'Reload successful');
is($obj->PartId, 3, 'Reload does not move PartId');
is($obj->RenderEdit, $render, 'Render consistency across reload');
is($obj->Recount, 3, 'Recount returns PartId under scalar context');
is($obj->RenderEdit, $render, 'Render consistency across recount');
is($obj->SetSectionId(1), 1, 'Set SectionId to 1');
is($obj->PartId, 1, 'PartId autopositon with SectionId');
is($obj->SetPartId(3), 3, 'Set PartId to 3');
is($obj->SectionId, 3, 'SectionId autopositon with PartId');

# }}}
# Attribute {{{

is_deeply( [$obj->PartObj->Atts],
    [qw( font size border align text )], 'Atts gets attributes');
is( $obj->PartObj->Att('shape')->Type,
    'select', 'Att("shape") is a typed attribute');
is_deeply( [$obj->PartObj->Att('shape')->Values],
    [qw( bars lines pie )], 'Att("shape") has some values');
is( $obj->PartObj->Att('shape')->Default,
    'bars', 'Att("shape") has the correct default values');
ok( !$obj->PartObj->Att('shape')->Applicable, 'It is not applicable to P');

# }}}
# Graph {{{

foreach my $shape ($obj->PartObj->Att('shape')->Values) {
    my $graph = $obj->NewGraph(
	shape  => $shape,
	width  => 100,
	height => 100,
    );
    my $png = $graph->Plot(
	labels	=> [ 'a' .. 'c' ],
	data	=> [[ 1 .. 3 ]],
    );
    like($png, qr(^\x89PNG), 'Graph plotted');
}

# }}}
# Navigation - Invalid input {{{

is($obj->PartFooBar, undef, 'Invalid op is noop');
is($obj->ClauseFooBar, undef, 'Invalid op is noop');

# }}}
# Navigation - Part - Change text/attributes {{{

is($obj->PartChange( text => 100 ), 3, 'Change does not move PartId');
is($obj->PartObj->text, 100, 'Text changed');

is($obj->PartChange( font => 12, align => 'left' ), 3, 'attr change');
is($obj->PartObj->text, 100, 'Text remains unchanged');
is_deeply(
    $obj->PartObj->atts,
    { id => 'Part3', font => 12, align => 'left' },
    'Attr changed'
);

# }}}
# Edit rendering - Part - P {{{

my ($p) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/p'
);
isa_ok($p, 'XML::Twig::Elt', 'P from get_xpath');
like($p->first_child('font')->sprint,
    qr(^\s*<font face="12">100</font>\s*$), 'Correctly renders font');

# }}}
# Navigation - Variables {{{

is($obj->Var('ReportName'), '(new)', "Variable 'ReportName' has value");
is($obj->SetName('Foo'), 'Foo', "Set ReportName");
is($obj->Var('ReportName'), 'Foo', "Variable 'ReportName' changed value");
is($obj->VarObj('ReportName')->Var, 'report_name', "->Var is lcased");
is($obj->VarObj('ReportName')->Name, 'ReportName', "->Name is ucased");

is($obj->Var('Page'), 1, "Variable 'Page' has value");
is($obj->Var('PageCount'), 1, "Variable 'PageCount' has value");
like($obj->Var('Date'), qr(^\d{4}-\d{2}-\d{2}$), "Variable 'Date' has value");
like($obj->Var('Time'), qr(^\d{2}:\d{2}:\d{2}$), "Variable 'Time' has value");

is($obj->PartChange( text => "Hello, cruel \$Date" ), 3, 'Set vars in text');

my ($var) = $obj->PartObj->first_child('var');
isa_ok($var, 'XML::Twig::Elt', 'VAR from get_xpath');
is($var->att('name'), 'date', "Variable name is in lcase");

my ($p_var) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/p'
);
isa_ok($p_var, 'XML::Twig::Elt', 'P containing VAR from get_xpath');
like($p_var->text,
    qr(^Hello, cruel \d{4}-\d{2}-\d{2}$), 'Contains interpolated variable');
isa_ok(($p_var->descendants('span'))[0],
    'XML::Twig::Elt', 'SPAN produced by P containing VAR from get_xpath');

isa_ok($obj->SetVar(Date => '19100'),
    'DBIx::ReportBuilder::Variable', "Set a variable");
is($obj->Var('Date'), '19100', "Retrieve its value");

isa_ok($obj->SetVar(Era => 'Discord'),
    'DBIx::ReportBuilder::Variable', "Add a variable");
is($obj->Var('Era'), 'Discord', "Retrieve its value");
ok($obj->Reload, 'Reload successful');
is($obj->Var('Era'), undef, "Value should vanish after reload");

isa_ok($obj->SetVarDefault(Era => 'Discord'),
    'DBIx::ReportBuilder::Variable', "Add a variable with default value");
is($obj->Var('Era'), 'Discord', "Retrieve its value");
ok($obj->Reload, 'Reload successful');
is($obj->Var('Era'), 'Discord', "Value should retain after reload");

is_deeply(
    [$obj->Vars],
    [qw( Page PageCount Date Time ReportName Era)],
    "Vars should return all existing variable"
);

is($obj->VarInsert( 'Era' ), 3, 'Set vars in text');
my ($var2) = $obj->PartObj->last_child('var');
isa_ok($var2, 'XML::Twig::Elt', 'VAR from get_xpath');
is($var2->att('name'), 'era');

my ($p_var2) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/p'
);
isa_ok($p_var2, 'XML::Twig::Elt', 'P containing VAR from get_xpath');
like($p_var2->text,
    qr(^Hello, cruel \d{4}-\d{2}-\d{2}Discord$), 'Contains interpolated variables');
isa_ok(($p_var2->descendants('span'))[1],
    'XML::Twig::Elt', 'SPAN produced by P containing VAR from get_xpath');

# }}}
# Navigation - Part - P, Img: Insert, Change, Up, Down, Remove {{{

is($obj->PartInsertP, 4, 'Insert p moves PartId');
is_deeply($obj->PartObj->atts,
    { id => 'Part4' }, 'New part has id after reload');
is($obj->PartInsertImg, 4, 'Insert img to empty p = replace');

isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Img');
is($obj->PartObj->tag, 'img', 'Really replaced');
is($obj->PartObj->id, 'Part4', 'ID is correct');

is($obj->PartUp, 3, 'Move up img');
is($obj->PartUp, 3, 'Move up again has no effect');
is($obj->PartDown, 4, 'Move down img');
is($obj->PartDown, 4, 'Move down again has no effect');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Img');

open my $fh, "$FindBin::Bin/test.png" or die $!;
is($obj->PartChange(src => $fh), 4, "Upload an image");
like($obj->PartObj->att('src'),
    qr(^javascript:'\\x89\\x50\\x4e\\x47\\x0d\\x0a), 'Image parsed');
close $fh;

$obj->SetPartId(3);
is($obj->PartRemove, 3, 'Remove p returns PartId to 3');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Img');
is($obj->SetPartId(0), 3, 'PartId autofocus to 3 even for non-P elements');

is($obj->PartRemove, 3, 'Remove img retains PartId in 3');

isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::P');
is($obj->PartObj->parent->tag, 'content', 'Still in content after removal');
is_deeply($obj->PartObj->atts,
    { id => 'Part3' }, 'But has all attributes cleared');

# }}}
# Navigation - Part - Table: Insert, Change {{{

is($obj->PartInsertTable, 3, 'Insert table replaces p');
is($obj->PartObj->tag, 'table', 'Really inserted');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Table');
is_deeply(
    [map $_->tag, $obj->PartObj->children],
    [qw(joins limits orderbys cells)],
    'New table has subelements'
);
is($obj->RenderEdit, $obj->RenderEdit, 'RenderEdit consistency');
my @attr = (table => 'scrips', rows => 10, caption => 'Scrip List');
is($obj->PartChange(@attr), 3, 'Change does not move PartId');
is_deeply($obj->PartObj->atts, { id => 'Part3', @attr }, 'Changed attributes');

# }}}
# Navigation - Clause - Limit: Insert, Change, Remove, Up, Down {{{

is($obj->ClauseInsertLimit, 1, 'Insert clause increments ClauseId');
is($obj->ClauseId, 1, 'ClauseId increments to 1');
is_deeply([$obj->Recount], [3, 1], 'Recount in list context returns both IDs');

is($obj->SetPartId(2), 2, 'PartId set to 2');
is($obj->ClauseId, 0, 'ClauseId should reset to 0');
is($obj->SetPartId(3), 3, 'PartId set to 3');
is($obj->ClauseId, 0, 'ClauseId should remain as 0');
is($obj->SetClauseId(1), 1, 'ClauseId set to 1');

is($obj->ClauseRemove, 0, 'Remove limit returns ClauseId to 0');
is($obj->ClauseId, 0, 'ClauseId decrements to 0');
is($obj->ClauseInsertLimit, 1, 'Insert limit increments ClauseId');
is($obj->ClauseInsertLimit, 2, 'Insert limit increments ClauseId');

is($obj->ClauseUp, 1, 'Move up limit');
is($obj->ClauseUp, 1, 'Move up again has no effect');
is($obj->ClauseDown, 2, 'Move down limit');
is($obj->ClauseDown, 2, 'Move down again has no effect');
is($obj->ClauseRemove, 1, 'Remove limit returns ClauseId to 1');
is($obj->ClauseRemove, 0, 'Remove limit returns ClauseId to 0');

is($obj->ClauseInsertLimit( field => 'id', operator => '<', text => 2000 ),
    1, 'Insert limit increments ClauseId');
is($obj->ClauseChange( text => 20 ),
    1, 'Change limit does not affect ClauseId');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause1', field => 'id', operator => '<' },
    'Attr changed as part of Insert'
);
is($obj->ClauseObj->text, 20, 'Text changed as part of Insert');

# }}}

SKIP: { skip("Can't connect to RT3 database", 9) unless $obj->Handle->dbh;
# Navigation - Clause - Cell - Insert, Change, Remove, Up, Down {{{

is($obj->ClauseInsertCell( field => 'id', text => "\${Era}Id" ),
    2, 'Insert cell increments ClauseId');
is($obj->ClauseInsertCell( field => 'id', text => 'Template' ),
    3, 'Insert cell increments ClauseId');
is($obj->ClauseObj->text, 'Template', 'Text changed as part of Insert');
is($obj->ClauseChange( field => 'template', foo => 'bar' ),
    3, 'Change cell does not affect ClauseId');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause3', field => 'template' },
    'Attr changed as part of Insert'
);
is($obj->ClauseInsertCell(
    field => 'id',
    text => '100xId',
    formula => '(($_ + $id) * 50) . $Era'
), 4, 'Insert cell increments ClauseId');

# }}}
# Edit rendering - Part - Table {{{

is($obj->RenderEdit, $obj->RenderEdit, 'RenderEdit consistency');

my ($table) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/table'
);
isa_ok($table, 'XML::Twig::Elt', 'Table from get_xpath');
is($table->first_child('caption')->text,
    'Scrip List', 'Correctly renders caption');
is($table->first_child('thead')->text,
    'DiscordIdTemplate100xId', 'Correctly renders thead');
like($table->first_child('tbody')->text,
    qr(^1+0+Discord2+0+Discord\Q.........\E$), 'Correctly renders tbody');
ok($table->first_child('tbody')->children <= 3,
    'Edit should only preserve 2 rows, plus ...');
is($obj->ClauseObj(1)->text, 20, 'Text of limit is still 20');
is($table->last_child('tbody')->text,
    "FIELD => 'id', OPERATOR => '<', VALUE = '20'",
    'Correctly renders second tbody');

# }}}
# Navigation - Part - Graph: Insert, Change {{{

is($obj->PartInsertGraph, 4, 'Insert graph increments PartId');
is($obj->PartObj->tag, 'graph', 'Really inserted');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Graph');
is_deeply(
    [map $_->tag, $obj->PartObj->children],
    [qw(joins limits orderbys cells)],
    'New graph has subelements'
);
is($obj->PartChange( table => 'templates', rows => 10, text => 'Template List' ),
    4, 'Change does not move PartId');

# }}}
# Navigation - Clause - Cell, Join, Limit, OrderBy: Insert {{{

is($obj->ClauseInsertCell( field => 'id', text => 'Id' ),
    5, 'Insert cell increments ClauseId');
is($obj->ClauseInsertCell( field => 'name', text => 'Name' ),
    6, 'Insert cell increments ClauseId');
is($obj->ClauseObj->parent->parent->tag, 'graph', "Cell belongs to the correct parent");

is($obj->ClauseInsertJoin( field => 'queue', table2 => 'queues', field2 => 'id' ),
    5, 'Insert join before cells brings back ClauseId');
is($obj->ClauseInsertLimit( field => 'name', table => 'queues', text => '___Approvals' ),
    6, 'Insert limit increments ClauseId');
is($obj->ClauseInsertJoin( field => 'queue', table2 => 'scrips', field2 => 'queue' ),
    6, 'Insert join before limit brings back ClauseId');
is($obj->ClauseInsertLimit( field => 'id', table => 'scrips', operator => '>', text => '0' ),
    8, 'Insert limit brings forward ClauseId');
is($obj->ClauseInsertOrderby( field => 'description', table => 'scrips' ),
    9, 'Insert orderby increments ClauseId');

# }}}
# Edit rendering - Part - GraphAsTable {{{

isa_ok($obj->PartObj->set_tag('table'),
    'DBIx::ReportBuilder::Part::Table', 'Graph->set_tag("table")');
is($obj->RenderEdit, $obj->RenderEdit, 'RenderEdit consistency');
my ($graph_as_table) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr[2]/td/table'
);
isa_ok($graph_as_table, 'XML::Twig::Elt', 'GraphAsTable from get_xpath');
is($graph_as_table->first_child('thead')->text,
    'IdName', 'Correctly renders thead');
like($graph_as_table->first_child('tbody')->text,
    qr(^\d+New Pending Approval\d+Approval Passed\Q......\E), 'Correctly renders tbody');

isa_ok($obj->PartObj->set_tag('graph'),
    'DBIx::ReportBuilder::Part::Graph', 'Table->set_tag("graph")');

# }}}
# Edit rendering - Part - Graph {{{

my ($graph) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr[2]/td/table'
);
isa_ok($graph, 'XML::Twig::Elt', 'Graph from get_xpath');

# }}}
}

# Navigation - Part - Include: Insert, Change {{{

is($obj->PartInsertInclude( report => 3 ),
    5, 'Insert include increments PartId');
is($obj->PartObj->tag, 'include', 'Really inserted');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Include');

my ($include) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr[3]/td/include'
);
isa_ok($include, 'XML::Twig::Elt', 'Include from get_xpath');
is($include->text, 'include: #3', 'Correctly renders include');

isa_ok($obj->SetDescribeReport( sub { "Report #$_[0]" } ),
    'CODE', 'Setting DescribeReport callback');

($include) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr[3]/td/include'
);
isa_ok($include, 'XML::Twig::Elt', 'Include from get_xpath');
is($include->text,
    'include: Report #3', 'Correctly renders include with the new callback');

($include) = $obj->RenderHTMLObj->root->get_xpath(
    '/html/body/div'
);
isa_ok($include, 'XML::Twig::Elt', 'Include from get_xpath');
is($include->text, '#3', 'Correctly renders include in HTML');

# }}}

1;

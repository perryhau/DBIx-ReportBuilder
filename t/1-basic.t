# $File: //member/autrijus/DBIx-ReportBuilder/t/1-basic.t $ $Author: autrijus $
# $Revision: #13 $ $Change: 7984 $ $DateTime: 2003/09/08 17:11:41 $

use Test::More tests => 102;
use FindBin;

use strict;
use lib "$FindBin::Bin/../lib";
local $SIG{__WARN__} = sub { print $_[0] unless $_[0] =~ m{XML/Twig} };

# Database - mysql, [ODBC] {{{

use_ok('DBIx::ReportBuilder');

my $obj = eval {
    local $SIG{__WARN__} = sub {};
    DBIx::ReportBuilder->new(
	Driver	    => 'mysql',
	Host	    => 'localhost',
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
is($obj->ClauseId, 0, 'ClauseId does not have autoposition');
ok($obj->Reload, 'Reload successful');
is($obj->PartId, 3, 'Reload does not move PartId');
is($obj->RenderEdit, $render, 'Render consistency across reload');
is($obj->Recount, 3, 'Recount returns PartId under scalar context');
is($obj->RenderEdit,
    $render, 'Render consistency across reload');

# }}}
# Attribute {{{

is_deeply( [$obj->PartObj->Atts],
    [qw( align font size border text )], 'Atts gets attributes');
is( $obj->PartObj->Att('shape')->Type,
    'select', 'Att("shape") is a typed attribute');
is_deeply( [$obj->PartObj->Att('shape')->Values],
    [qw( bars lines pie )], 'Att("shape") has some values');
is( $obj->PartObj->Att('shape')->Default,
    'bars', 'Att("shape") has the correct default values');
ok( !$obj->PartObj->Att('shape')->Applicable, 'It is not applicable to P');

# }}}
# Navigation - Invalid input {{{

is($obj->PartFooBar, undef, 'Invalid op is noop');
is($obj->ClauseFooBar, undef, 'Invalid op is noop');

# }}}
# Navigation - Invalid input {{{
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
    qr{^\s*<font face="12">100</font>\s*$}, 'Correctly renders font');

# }}}
# Navigation - Part - P, Img: Insert, Up, Down, Remove {{{

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

is($obj->PartRemove, 3, 'Remove img returns PartId to 3');
is($obj->PartRemove, 3, 'Remove p retains PartId in 3');

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
my @attr = (table => 'scrips', rows => 10, caption => 'Scrip List');
is($obj->PartChange(@attr), 3, 'Change does not move PartId');
is_deeply($obj->PartObj->atts, { id => 'Part3', @attr }, 'Changed attributes');

# }}}
# Navigation - Clause - Limit: Insert, Change, Remove, Up, Down {{{

is($obj->ClauseInsertLimit, 1, 'Insert clause increments ClauseId');
is($obj->ClauseId, 1, 'ClauseId increments to 1');
is_deeply([$obj->Recount], [3, 1], 'Recount in list context returns both IDs');
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

is($obj->ClauseInsertLimit( field => 'id', operator => '<', value => 2000 ),
    1, 'Insert limit increments ClauseId');
is($obj->ClauseChange( value => 20 ),
    1, 'Change limit does not affect ClauseId');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause1', field => 'id', operator => '<', value => 20 },
    'Attr changed as part of Insert'
);

# }}}
# Navigation - Clause - Cell - Insert, Change, Remove, Up, Down {{{

SKIP: { skip("Can't connect to RT3 database", 9) unless $obj->Handle->dbh;

is($obj->ClauseInsertCell( field => 'id', text => 'Id' ),
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
is($obj->ClauseInsertCell( field => 'id', text => '100xId', formula => '($_ + $id) * 50' ),
    4, 'Insert cell increments ClauseId');

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
    'IdTemplate100xId', 'Correctly renders thead');
is($table->first_child('tbody')->text,
    '1110022200', 'Correctly renders tbody');
is($table->first_child('tbody')->children,
    2, 'Edit should only preserve 2 rows at most');

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
is($obj->ClauseInsertLimit( field => 'name', table => 'queues', value => '___Approvals' ),
    6, 'Insert limit increments ClauseId');
is($obj->ClauseInsertJoin( field => 'queue', table2 => 'scrips', field2 => 'queue' ),
    6, 'Insert join before limit brings back ClauseId');
is($obj->ClauseInsertLimit( field => 'id', table => 'scrips', operator => '>', value => '0' ),
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
is($graph_as_table->first_child('tbody')->text,
    '9New Pending Approval10Approval Passed', 'Correctly renders tbody');

isa_ok($obj->PartObj->set_tag('graph'),
    'DBIx::ReportBuilder::Part::Graph', 'Table->set_tag("graph")');

# }}}
# Edit rendering - Part - Graph {{{

my ($graph) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr[2]/td/table'
);

isa_ok($graph, 'XML::Twig::Elt', 'Graph from get_xpath');

# XXX - graph should show image

# }}}

}

# TODO Navigation - Part - Include: Insert, Change
# TODO Edit rendering - Part - Include

# TODO Navigation - Variables - Default: Insert, Change
# TODO Edit rendering - Variables - Default

# TODO Navigation - Variables - UserDefined: Insert, Change
# TODO Navigation - Part - Table: Change - Bind variables
# TODO Edit rendering - Variables - UserDefined

1;

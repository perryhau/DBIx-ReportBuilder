# $File: //member/autrijus/DBIx-ReportBuilder/t/1-basic.t $ $Author: autrijus $
# $Revision: #5 $ $Change: 7966 $ $DateTime: 2003/09/08 00:13:35 $

use Test::More tests => 71;

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

isa_ok($obj, 'DBIx::ReportBuilder');
isa_ok($obj->Handle, 'DBIx::SearchBuilder::Handle');
isa_ok($obj->RenderObj, 'DBIx::ReportBuilder::Render');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::P');
is($obj->ClauseObj, undef, 'ClauseObj is undefined');

is($obj->PartId, 3, 'PartId autoposition');
is($obj->ClauseId, 0, 'ClauseId does not have autoposition');
is($obj->RenderHTML, $obj->RenderHTML, 'RenderHTML consistency');
is(my $render = $obj->RenderEdit,
    $obj->RenderEdit, 'RenderEdit consistency');
is($obj->RenderXML,
    '<?xml version="1.0" encoding="UTF-8"?>' . "\n" . $obj->root->sprint,
    'RenderXML consistency');
is($obj->Render, $obj->RenderHTML, 'Render means RenderHTML');

ok($obj->Reload, 'Reload successful');
is($obj->PartId, 3, 'Reload does not move PartId');
is($obj->RenderEdit,
    $render, 'Render consistency across reload');

is($obj->Recount, 3, 'Recount returns PartId under scalar context');
is($obj->RenderEdit,
    $render, 'Render consistency across reload');

is($obj->PartChange( text => 100 ), 3, 'Change does not move PartId');
is($obj->PartObj->text, 100, 'Text changed');

is($obj->PartChange( font => 12, align => 'left' ), 3, 'attr change');
is($obj->PartObj->text, 100, 'Text remains unchanged');
is_deeply(
    $obj->PartObj->atts,
    { id => 'Part3', font => 12, align => 'left' },
    'Attr changed'
);

my ($p) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/p'
);
isa_ok($p, 'XML::Twig::Elt');
like($p->first_child('font')->sprint,
    qr{^\s*<font face="12">100</font>\s*$}, 'Correctly renders font');

is($obj->PartFooBar( tag => 'p' ), undef, 'Illegal op is noop');
is($obj->ClauseFooBar( tag => 'p' ), undef, 'Illegal op is noop');

is($obj->PartInsert( tag => 'p' ), 4, 'Insert p moves PartId');
is_deeply($obj->PartObj->atts, { id => 'Part4' }, 'New part has id after reload');
is($obj->PartInsert( tag => 'img' ), 4, 'Insert img to empty p = replace');

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

is($obj->PartInsert( tag => 'table' ), 3, 'Insert table replaces p');
is($obj->PartObj->tag, 'table', 'Really inserted');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Table');
is_deeply(
    [map $_->tag, $obj->PartObj->children],
    [qw(caption joins limits orderbys cells)],
    'New table has subelements'
);

is($obj->PartChange( table => 'users', rows => 10, text => 'User List' ),
    3, 'Change does not move PartId');
is($obj->ClauseInsert( tag => 'limit' ),
    1, 'Insert clause increments ClauseId');
is($obj->ClauseId, 1, 'ClauseId increments to 1');
is_deeply([$obj->Recount], [3, 1], 'Recount in list context returns both IDs');
is($obj->ClauseRemove, 0, 'Remove limit returns ClauseId to 0');
is($obj->ClauseId, 0, 'ClauseId decrements to 0');
is($obj->ClauseInsert( tag => 'limit' ),
    1, 'Insert limit increments ClauseId');
is($obj->ClauseInsert( tag => 'limit' ),
    2, 'Insert limit increments ClauseId');

is($obj->ClauseUp, 1, 'Move up limit');
is($obj->ClauseUp, 1, 'Move up again has no effect');
is($obj->ClauseDown, 2, 'Move down limit');
is($obj->ClauseDown, 2, 'Move down again has no effect');
is($obj->ClauseRemove, 1, 'Remove limit returns ClauseId to 1');
is($obj->ClauseRemove, 0, 'Remove limit returns ClauseId to 0');

is($obj->ClauseInsert(
    tag => 'limit', field => 'id', operator => '<', value => 20
), 1, 'Insert limit increments ClauseId');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause1', field => 'id', operator => '<', value => 20 },
    'Attr changed as part of Insert'
);

SKIP: { skip("Can't connect to RT3 database", 9) unless $obj->Handle->dbh;

is($obj->ClauseInsert( tag => 'cell', field => 'id', text => 'Id' ),
    2, 'Insert cell increments ClauseId');
is($obj->ClauseInsert( tag => 'cell', field => 'name', text => 'Name' ),
    3, 'Insert cell increments ClauseId');
is($obj->ClauseObj->text, 'Name', 'Text changed as part of Insert');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause3', field => 'name' },
    'Attr changed as part of Insert'
);

is($obj->RenderEdit, $obj->RenderEdit, 'RenderEdit consistency');
my ($table) = $obj->RenderEditObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/table'
);
isa_ok($table, 'XML::Twig::Elt');
is($table->first_child('caption')->text,
    'User List', 'Correctly renders caption');
is($table->first_child('thead')->text,
    'IdName', 'Correctly renders thead');
is($table->first_child('tbody')->text,
    '1RT_System10Nobody12root', 'Correctly renders tbody');

}

1;

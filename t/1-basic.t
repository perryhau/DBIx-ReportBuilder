# $File: //member/autrijus/DBIx-ReportBuilder/t/1-basic.t $ $Author: autrijus $
# $Revision: #2 $ $Change: 7953 $ $DateTime: 2003/09/07 22:05:43 $

use FindBin;
use Test::More tests => 69;

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
is(my $render = $obj->Render, $obj->Render, 'Render consistency');
is($obj->Render('HTML'), $obj->Render('HTML'), 'Render HTML consistency');

ok($obj->Reload, 'Reload successful');
is($obj->PartId, 3, 'Reload does not move PartId');
is($obj->Render, $render, 'Render consistency across reload');

is($obj->Recount, 3, 'Recount returns PartId under scalar context');
is($obj->Render, $render, 'Render consistency across reload');

is($obj->Part(Change => ( text => 100 )), 3, 'Change does not move PartId');
is($obj->PartObj->text, 100, 'Text changed');

is($obj->Part(Change => ( font => 12, align => 'left' )), 3, 'attr change');
is($obj->PartObj->text, 100, 'Text remains unchanged');
is_deeply(
    $obj->PartObj->atts,
    { id => 'Part3', font => 12, align => 'left' },
    'Attr changed'
);

my ($p) = $obj->RenderObj->root->get_xpath(
    '/div/table/tr[3]/td[2]/table/tr/td/p'
);
isa_ok($p, 'XML::Twig::Elt');
like($p->first_child('font')->sprint,
    qr{^\s*<font face="12">100</font>\s*$}, 'Correctly renders font');

is($obj->Part(FooBar => ( tag => 'p' )), undef, 'Illegal op is noop');
is($obj->Clause(FooBar => ( tag => 'p' )), undef, 'Illegal op is noop');

is($obj->Part(Insert => ( tag => 'p' )), 4, 'Insert p moves PartId');
is_deeply($obj->PartObj->atts, { id => 'Part4' }, 'New part has id after reload');
is($obj->Part(Insert => ( tag => 'img' )), 4, 'Insert img to empty p = replace');

isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Img');
is($obj->PartObj->tag, 'img', 'Really replaced');
is($obj->PartObj->id, 'Part4', 'ID is correct');

is($obj->Part('Up'), 3, 'Move up img');
is($obj->Part('Up'), 3, 'Move up again has no effect');
is($obj->Part('Down'), 4, 'Move down img');
is($obj->Part('Down'), 4, 'Move down again has no effect');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Img');

is($obj->Part('Remove'), 3, 'Remove img returns PartId to 3');
is($obj->Part('Remove'), 3, 'Remove p retains PartId in 3');

isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::P');
is($obj->PartObj->parent->tag, 'content', 'Still in content after removal');
is_deeply($obj->PartObj->atts, { id => 'Part3' }, 'But has all attributes cleared');

is($obj->Part(Insert => ( tag => 'table' )), 3, 'Insert table replaces p');
is($obj->PartObj->tag, 'table', 'Really inserted');
isa_ok($obj->PartObj, 'DBIx::ReportBuilder::Part::Table');
is_deeply(
    [map $_->tag, $obj->PartObj->children],
    [qw(caption joins limits orderbys cells)],
    'New table has subelements'
);

is($obj->Part( Change => ( table => 'users', rows => 10, text => 'User List' )),
    3, 'Change does not move PartId');
is($obj->Clause( Insert => ( tag => 'limit' ) ),
    1, 'Insert clause increments ClauseId');
is($obj->ClauseId, 1, 'ClauseId increments to 1');
is_deeply([$obj->Recount], [3, 1], 'Recount in list context returns both IDs');
is($obj->Clause('Remove'), 0, 'Remove limit returns ClauseId to 0');
is($obj->ClauseId, 0, 'ClauseId decrements to 0');
is($obj->Clause( Insert => ( tag => 'limit' ) ),
    1, 'Insert limit increments ClauseId');
is($obj->Clause( Insert => ( tag => 'limit' ) ),
    2, 'Insert limit increments ClauseId');

is($obj->Clause('Up'), 1, 'Move up limit');
is($obj->Clause('Up'), 1, 'Move up again has no effect');
is($obj->Clause('Down'), 2, 'Move down limit');
is($obj->Clause('Down'), 2, 'Move down again has no effect');
is($obj->Clause('Remove'), 1, 'Remove limit returns ClauseId to 1');
is($obj->Clause('Remove'), 0, 'Remove limit returns ClauseId to 0');

is($obj->Clause( Insert => ( tag => 'limit', field => 'id', operator => '<', value => 2000 ) ),
    1, 'Insert limit increments ClauseId');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause1', field => 'id', operator => '<', value => 2000 },
    'Attr changed as part of Insert'
);

SKIP: { skip("Can't connect to RT3 database", 9) unless $obj->Handle->dbh;

is($obj->Clause( Insert => ( tag => 'cell', field => 'id', text => 'Id' ) ),
    2, 'Insert cell increments ClauseId');
is($obj->Clause( Insert => ( tag => 'cell', field => 'name', text => 'Name' ) ),
    3, 'Insert cell increments ClauseId');
is($obj->ClauseObj->text, 'Name', 'Text changed as part of Insert');
is_deeply(
    $obj->ClauseObj->atts,
    { id => 'Clause3', field => 'name' },
    'Attr changed as part of Insert'
);

is($obj->Render, $obj->Render, 'Render consistency');
my ($table) = $obj->RenderObj->root->get_xpath(
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

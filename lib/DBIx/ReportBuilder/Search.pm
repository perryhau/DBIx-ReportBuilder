# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 8037 $ $DateTime: 2003/09/10 18:33:37 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

my $stub;
sub NewItem { bless(\$stub) }
sub LoadFromHash { bless($_[0] = $_[1]) }
sub Id { $_[0]->{id} }

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Search.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7953 $ $DateTime: 2003/09/07 22:05:43 $

package DBIx::ReportBuilder::Search;

use strict;
use base 'DBIx::SearchBuilder';

my $stub;
sub NewItem { bless(\$stub) }
sub LoadFromHash { $_[0] = $_[1] }

1;

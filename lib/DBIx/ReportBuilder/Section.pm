# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Section.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 8081 $ $DateTime: 2003/09/12 22:59:29 $

package DBIx::ReportBuilder::Section;

use strict;
use DBIx::ReportBuilder ':all';
use base 'XML::Twig::Elt';

sub new {
    my $class = shift;
    my $self  = shift || {};
    $class = ref($class) || $class;

    bless $self, $class;
    $self->init;
    return $self;
}

sub init {}

1;

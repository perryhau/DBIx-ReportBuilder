# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/XML.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 7956 $ $DateTime: 2003/09/07 23:01:03 $

package DBIx::ReportBuilder::Render::XML;
use base 'DBIx::ReportBuilder::Render';
use strict;

sub new {
    my ($class, %args) = @_;
    my $self = $class->XML::Twig::new;
    $self->SetObject( $args{Object} );
    return $self;
}

sub Render {
    my $self = shift;
    $self->Object->sprint;
}

1;

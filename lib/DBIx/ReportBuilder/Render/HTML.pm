# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/HTML.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 8070 $ $DateTime: 2003/09/12 01:49:30 $

package DBIx::ReportBuilder::Render::HTML;
use base 'DBIx::ReportBuilder::Render';
use strict;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(
	%args,
	twig_handlers => {
	    preamble    => \&section,
	    header	=> \&section,
	    content	=> \&section,
	    footer	=> \&section,
	    postamble   => \&section,
	    graph	=> sub { $_[0]->plotGraph($_[1]) },
	},
	pretty_print	=> ($args{pretty_print} || 'none'),
    );
};

sub section { $_->erase }

1;

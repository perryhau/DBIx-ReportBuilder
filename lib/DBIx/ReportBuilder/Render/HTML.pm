# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Render/HTML.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 8292 $ $DateTime: 2003/09/28 23:47:26 $

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

sub section {
    if ($_->att('separator')) {
	if ($_->tag eq 'header') {
	    $_->insert_new_elt(last_child => 'hr');
	}
	elsif ($_->tag eq 'footer') {
	    $_->insert_new_elt(first_child => 'hr');
	}
    }
    $_->att('hidden') ? $_->delete : $_->erase;
}

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Graph.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 8390 $ $DateTime: 2003/10/12 16:53:29 $

package DBIx::ReportBuilder::Graph;

=head1 SYNOPSIS

    my $graph = DBIx::ReportBuilder::Graph->new(
	shape  => 'bars',
	width  => 100,
	height => 100,
    );
    open OUT, ">out.png" or die $!;
    print OUT $graph->Plot([[ 'a' .. 'c' ], [ 1 .. 3 ]]);

=cut

use strict;

sub new {
    my ($class, %args) = @_;
    my $pkg = __PACKAGE__ . '::'. ( $args{class} ||= 'GD' );
    my $file = $pkg;
    $file =~ s{::}{/}g;
    require "$file.pm";
    return $pkg->new(%args);
}

sub escape {
    my $self = shift;
    return $_[0] if $] < 5.007003 or !(defined($_[0]) and length($_[0]));

    my $text = shift;
    require Encode;
    Encode::_utf8_on($text);
    return Encode::encode(ascii => $text, Encode::FB_HTMLCREF());

    return $text;
}

sub ttf_path {
    return '/usr/local/share/fonts/TrueType' unless $^O eq 'MSWin32';
    return '/Progra~1/OurInternet/Common/fonts/truetype/arphic';
}

sub ttf_file {
    my ($self, $font) = @_;
    my $rv = $self->ttf_path . '/' . $font;

    die "can't find $rv" unless -r $rv;
    return $rv unless $^O eq 'MSWin32';

    $rv = Win32::GetFullPathName($rv);
    $rv =~ s|\\|/|g;
    $rv =~ s|^\w:||;
    return $rv;
}

1;

# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Graph.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 7980 $ $DateTime: 2003/09/08 15:37:26 $

package DBIx::ReportBuilder::Graph;

use strict;

=head1 NAME

DBIx::ReportBuilder::Graph - ReportBuilder wrapper to GD::Graph

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use constant Labels =>
    qw( title legend x_label y_label x_axis y_axis values label value );
use constant Widgets =>
    qw( fg text label axislabel legend values accent );

our $AUTOLOAD;

BEGIN {
    no warnings 'redefine';
    # Okay, this is thoroughly evil, but totally neccessary.
    # (otherwise GD::Text gets $n_space == 0);
    use POSIX;
    *POSIX::isgraph = sub { die if (caller)[0] eq 'GD::Text' };
}

sub new {
    my ($class, %args) = @_;

    # Normalize identifiers
    $args{'3d'}         = delete($args{threed});
    $args{'3d_shading'} = delete($args{threed_shading});

    my $graph = $class->make_gd(%args);

    $graph->set(%args, title => $class->escape($args{text}));
    $graph->set(map { ("${_}clr" => 'black') } $class->Widgets);

    foreach my $label ($class->Labels) {
	my $font = ($args{"${label}_font"} || 'ming') or next;
	$font = ($font eq 'ming') ? 'bsmi00lp.ttf' : 'bkai00mp.ttf';

	my $method = "set_${label}_font";
	next unless $graph->can($method);

	$graph->$method($class->ttf_file($font),
	    $args{ $_ . '_fontsize' } || 10);
    }

    return bless({ graph => $graph, args => \%args }, $class);
}

sub Plot {
    my ($self, $val, $fields) = @_;
    my $graph = $self->{graph};
    my %args  = %{ $self->{args} };

    if ($args{legend}) {
	my @fields = (
	    ($graph =~ m/pie/)
		? @{ $val->[0] }
		: map { $args{descr}{$_} || $_ } @{$fields}
	);
	$graph->set_legend(map $self->escape($_), @fields);
    }
    else {
	delete $graph->{legend};    # XXX: pollution prevention
    }

    if ($graph->isa('GD::Graph::axestype')) {
	require Chart::Math::Axis;

	my $axis = Chart::Math::Axis->new;
	$axis->add_data(map { @{ $val->[$_] } } 1 .. $#{$val});
	$axis->include_zero;
	$axis->apply_to($graph);
    }

    return $graph->plot($val);
}

sub escape {
    my $self = shift;
    return $_[0] if $] < 5.007003 or !length($_[0]);

    my $text = shift;
    require Encode;
    Encode::_utf8_on($text);
    return Encode::encode(ascii => $text, Encode::FB_HTMLCREF());

    return $text;
}

sub ttf_path {
    return '/usr/local/share/fonts/TrueType' unless $^O eq 'MSWin32';
    return '/Progra~1/OurInternet/Common/texmf/fonts/truetype/arphic';
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

sub get_shape {
    my ($class, %args) = @_;
    my $shape = $args{shape};

    return 'pie3d' if $shape eq 'pie';

    if ($shape eq 'bars') {
	$shape .= '3d' if $args{'3d'};
	return 'cylinder' if $args{style} eq 'cylinder';
    }
    elsif ($shape eq 'lines') {
	$shape .= '3d'     if $args{'3d'};
	$shape .= 'points' if $args{dots};
    }
    else {
	die "unknown graph shape $shape";
    }

    return $shape;
}

sub make_gd {
    my ($class, %args) = @_;
    my $shape = $class->get_shape(%args);

    no strict 'refs';
    require "GD/Graph/$shape.pm";
    return "GD::Graph::$shape"->new($args{width}, $args{height});
}

sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/^.*:://;
    my $graph = $self->{graph} or return;
    $graph->$AUTOLOAD(@_) if $graph->can($AUTOLOAD);
}

1;

__END__

=head1 SEE ALSO

L<GD::Graph>, L<Chart::Math::Axis>

=head1 AUTHORS

Chia-Liang Kao E<lt>clkao@clkao.orgE<gt>,
Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002, 2003 by 104 Technology Inc., Taiwan.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

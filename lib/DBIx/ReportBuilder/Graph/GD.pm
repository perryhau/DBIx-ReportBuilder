# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Graph/GD.pm $ $Author: autrijus $
# $Revision: #8 $ $Change: 8828 $ $DateTime: 2003/11/13 14:15:32 $

package DBIx::ReportBuilder::Graph::GD;
use base 'DBIx::ReportBuilder::Graph';

use strict;

=head1 NAME

DBIx::ReportBuilder::Graph::GD - ReportBuilder wrapper to GD::Graph

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
    *POSIX::isgraph = sub { die if caller and caller eq 'GD::Text' };
}

sub new {
    my ($class, %args) = @_;

    delete $args{class};
    return unless %args;

    # Normalize identifiers
    $args{'3d'}         = delete($args{threed});
    $args{'3d_shading'} = delete($args{threed_shading});
    delete $args{show_values} if $args{cumulate};

    return bless(\%args, $class);
}

sub Plot {
    my $self	= shift;
    my %args	= (%$self, @_);
    my $data	= $args{data};
    my $labels	= $args{labels};
    my @legends;

    if ($args{legend}) {
	my @fields = (
	    ($args{x_axis_field})
		? @{$labels}[1 .. $#{$labels}]
		: @{shift(@$data) || []}
	);
	shift @$labels unless $args{x_axis_field};
	@legends = map $self->escape($_), @fields;
    }

    if ($args{x_axis_field}) {
	$labels = shift(@$data) || [];
    }
    else {
	# rotate by 90 degrees
	$data = [
	    map {
		my $y = $_;
		[ map { $data->[$_][$y] } (0 .. $#{$data}) ]
	    } (0 .. $#{$data->[0]}) # y
	];
    }

    # ensure minimal height when chart is rotated
    my $min_height = @$data * 20;
    $self->{height} = $min_height
	if $self->{rotate_chart} and $self->{height} < $min_height;
    $self->{height} += 50 if @legends;

    my $graph = $self->make_graph or return;
    $graph->set_legend(@legends) if @legends;

    if ($graph->isa('GD::Graph::axestype')) {
	require Chart::Math::Axis;
	my $axis = Chart::Math::Axis->new;

	if ($self->{cumulate}) {
	    require List::Util;

	    $axis->add_data( map {
		my $y = $_;
		List::Util::sum(
		    map { $data->[$_][$y] } (0 .. $#{$data})
		);
	    } (0 .. $#{$data->[0]}));
	}
	else {
	    $axis->add_data(map { @$_ } @$data);
	}

	$axis->add_data(int($axis->max * 1.1)) if $self->{show_values};
	$axis->include_zero;
	$axis->apply_to($graph);
    }

    return eval { $graph->plot([ $labels, @$data ])->png };
}

sub make_graph {
    my $self = shift;
    my $graph = $self->make_gd or return;

    $graph->set(%$self, title => $self->escape($self->{text}));
    $graph->set(map { ("${_}clr" => 'black') } $self->Widgets);

    foreach my $label ($self->Labels) {
	my $font = ($self->{"${label}_font"} || 'ming') or next;
	$font = ($font eq 'ming') ? 'bsmi00lp.ttf' : 'bkai00mp.ttf';

	my $method = "set_${label}_font";
	next unless $graph->can($method);

	$graph->$method(
	    $self->ttf_file($font),
	    ($self->{ "${label}_fontsize" } || 10),
	);
    }

    return $graph;
}

sub get_shape {
    my $self = shift;
    my $shape = $self->{shape} or return;
    my $style = $self->{style} || '';

    return 'pie3d' if $shape eq 'pie';

    if ($shape eq 'bars') {
	$shape .= '3d' if $self->{'3d'};
	return 'cylinder' if $style eq 'cylinder';
    }
    elsif ($shape eq 'lines') {
	$shape .= '3d'     if $self->{'3d'};
	$shape .= 'points' if $style eq 'dots';
    }
    else {
	die "unknown graph shape $shape";
    }

    return $shape;
}

sub make_gd {
    my $self = shift;
    my $shape = $self->get_shape or return;
    my ($width, $height) = @{$self}{'width', 'height'};

    no strict 'refs';
    require "GD/Graph/$shape.pm";
    return "GD::Graph::$shape"->new($width, $height)
	    || die "Cannot make $shape.pm";
    
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

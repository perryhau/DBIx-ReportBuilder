# $File: //member/autrijus/DBIx-ReportBuilder/lib/DBIx/ReportBuilder/Variable.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 8047 $ $DateTime: 2003/09/11 00:35:14 $

package DBIx::ReportBuilder::Variable;
use strict;

use constant Variables => qw( page page_count date time report_name );

sub new {
    my $class = shift;
    return bless({ @_ }, $class);
}

sub Var	    { $_[0]{Var} }
sub Object  { $_[0]{Object} }
sub Name    { $_[0]->Object->ucase($_[0]{Var}) }

sub Vars {
    my $self = shift;
    if (my @meta = $self->MetaObj) {
	return map $_->att('name'), @meta;
    }
    return $self->Variables;
}

sub DefaultValue {
    my $self = shift;
    return $self->Value('default_only');
}

sub SetDefaultValue {
    my ($self, $value) = @_;
    return $self->SetValue($value, 'as_default');
}

sub Remove {
    my $self = shift;
    my $meta = $self->MetaObj($self->Var) or return;
    $meta->delete unless $meta->att('auto');
}

sub Value {
    my ($self, $default_only) = @_;
    my $var  = $self->Var;
    my $meta = $self->MetaObj($var);
    return $meta->att('#value')
	if $meta and !$default_only and exists $meta->atts->{'#value'};
    return $meta->att('content')
	if $meta and !$meta->att('auto');
    return $self->$var if $self->can($var);
    return;
}

sub MetaObj {
    my ($self, $var) = @_;
    return unless ref($self->Object);

    my $root = $self->Object->root or return;
    my $head = $root->first_child('head');

    return $head->first_child("meta[\@name='$var']") if defined($var);
    return $head->children("meta[\@name]");
}

sub SetValue {
    my ($self, $value, $as_default) = @_;
    my $var  = $self->Var;
    my $head = $self->Object->root->first_child('head') or die "No HEAD!";
    my $meta = $self->MetaObj($var) || $head->insert_new_elt(last_child => "meta");

    return if $as_default and $meta->att('auto');

    my $att = ($as_default ? 'content' : '#value');
    $meta->set_att(name => $var, $att => $value);
    return $self;
}

sub page { 1 }
sub page_count { 1 }

sub date {
    my ($mday, $mon, $year) = (localtime())[3 .. 5];
    $year += 1900; $mon++;
    return sprintf("%04s-%02s-%02s", $year, $mon, $mday);
}

sub time {
    my ($sec, $min, $hour) = (localtime())[0 .. 2];
    return sprintf("%02s:%02s:%02s", $hour, $min, $sec);
}

sub report_name {
    my $self = shift;
    $self->Object->Name;
}

1;

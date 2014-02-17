package Lamawiki;
use 5.008;
use strict;
use warnings;
use Encode;

our $VERSION = '0.01';

sub config          { return $_[0]{'config'} }
sub default_title   { return shift->config->{'default.title'} }
sub all_title       { return shift->config->{'all.title'} }
sub recent_title    { return shift->config->{'recent.title'} }

sub now        { return $_[0]{'now'} }
sub user       { return @_ > 1 ? ($_[0]{'user'} = $_[1]) : $_[0]{'user'} }

# colleagues
sub db         { return @_ > 1 ? ($_[0]{'db'} = $_[1]) : $_[0]{'db'} }
sub sch        { return $_[0]{'sch'} }
sub auth       { return $_[0]{'auth'} }
sub capability { return $_[0]{'capability'} }
sub session    { return $_[0]{'session'} }
sub page       { return $_[0]{'page'} }
sub interwiki  { return $_[0]{'interwiki'} }
sub converter  { return $_[0]{'converter'} }
sub generater  { return $_[0]{'generater'} }

sub new {
    my($class, $h) = @_;
    my $self = bless {'now' => time, %{$h || +{}}}, ref $class || $class;
    $self->{'config'} ||= +{};
    $self->{'generater'} ||= +{};
    %{$self->{'generater'}} = ($self->core_generaters, %{$self->{'generater'}});
    return $self;
}

sub core_generaters {
    my($self) = @_;
    my %h;
    if (defined $self->all_title) {
        $h{$self->all_title} = sub{ $_[1]->generate_all($_[0]) };
    }
    if (defined $self->recent_title) {
        $h{$self->recent_title} = sub{ $_[1]->generate_recent($_[0]) };
    }
    return %h;
}

sub merge_generaters {
    my($self, %h) = @_;
    return $self->new({%{$self}, 'generater' => {%{$self->generater}, %h}});
}

sub launch {
    my($self, $now) = @_;
    return $self->new({%{$self}, 'now' => $now || time});
}

sub find_authenticate {
    my($self, $key) = @_;
    my $user = $self->session && $self->session->find_authenticate($self, $key);
    my $capability = $self->capability && $self->capability->new($self->capability);
    return $self->new({%{$self}, 'user' => $user, 'capability' => $capability});
}

sub reload_interwiki {
    my($self) = @_;
    my $q = $self->config->{'interwiki.title'};
    return $self->new($self) if ! $q || ! $self->interwiki;
    my $page = $self->page->find_interwiki($self, $q);
    my $h = $self->converter->scan_interwiki_servers($page);
    my $interwiki = $self->interwiki->reload($h);
    return $self->new({%{$self}, 'interwiki' => $interwiki});
}

1;

__END__

=pod

=head1 NAME

Lamawiki - the lamawiki mediator

=head1 VERSION

0.01

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


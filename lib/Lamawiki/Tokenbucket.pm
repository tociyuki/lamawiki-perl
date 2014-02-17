package Lamawiki::Tokenbucket;
use strict;
use warnings;
use Carp;

our $VERSION = '0.02';

# after accepting burst tokens, limits 1 token / period seconds.
sub burst  { return $_[0]{'burst'} }
sub period { return $_[0]{'period'} }

sub new {
    my($class, $h) = @_;
    my $self = bless {%{$h || +{}}}, ref $class || $class;
    $self->{'burst'} ||= 3; # times
    $self->{'period'} ||= 12 * 3600; # seconds
    return $self;
}

sub preset {
    my($self, $wiki, $remote, $now, $token) = @_;
    my $capacity = $self->burst * $self->period;
    $token = defined $token ? $token : $capacity;
    my $begun = $wiki->db->begun_work;
    $begun or $wiki->db->begin_work;
    $wiki->db->call('tbf.delete', {'credit' => $now - 2 * $capacity});
    my $h0 = $wiki->db->call('tbf.select_remote', {'remote' => $remote})->[0];
    my $h1 = {'remote' => $remote, 'credit' => $now - $token};
    $wiki->db->call($h0 ? 'tbf.update' : 'tbf.insert', $h1);
    $begun or $wiki->db->commit;
    return $self;
}

sub pass {
    my($self, $wiki, $remote, $now) = @_;
    my $capacity = $self->burst * $self->period;
    my $pass = q();
    my $begun = $wiki->db->begun_work;
    $begun or $wiki->db->begin_work;
    my $h = $wiki->db->call('tbf.select_remote', {'remote' => $remote})->[0];
    if (! $h) {
        $h = {'remote' => $remote, 'credit' => $now - $capacity};
        $wiki->db->call('tbf.insert', $h);
        $pass = 1;
    }
    else {
        my $token = $now - $h->{'credit'};
        if ($token > $capacity) {
            $token = $capacity;
        }
        if ($token >= $self->period) {
            $token -= $self->period;
            $pass = 1;
        }
        $h->{'credit'} = $now - $token;
        $wiki->db->call('tbf.update', $h);
    }
    $begun or $wiki->db->commit;
    return $pass;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Tokenbucket - the token bucket filter.

=head1 VERSION

0.02

=head1 SEE ALSO

linux-2.6.32/net/sched/sch_tbf.c

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


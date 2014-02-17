package Lamawiki::Cookie;
use strict;
use warnings;
use Encode;

our $VERSION = '0.02';

my $random_bytes;
BEGIN{
    if (! eval{
        require Crypt::OpenSSL::Random;
        $random_bytes = \&Crypt::OpenSSL::Random::random_bytes;
        1;
    }) {
        require Crypt::URandom;
        $random_bytes = \&Crypt::URandom::urandom;
    }
}

sub new { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub sesskey  { return @_ > 1 ? ($_[0]{'sesskey'}  = $_[1]) : $_[0]{'sesskey'} }
sub name     { return @_ > 1 ? ($_[0]{'name'}     = $_[1]) : $_[0]{'name'} }
sub token    { return @_ > 1 ? ($_[0]{'token'}    = $_[1]) : $_[0]{'token'} }
sub posted   { return @_ > 1 ? ($_[0]{'posted'}   = $_[1]) : $_[0]{'posted'} }
sub remote   { return @_ > 1 ? ($_[0]{'remote'}   = $_[1]) : $_[0]{'remote'} }
sub expires  { return @_ > 1 ? ($_[0]{'expires'}  = $_[1]) : $_[0]{'expires'} }
sub lifetime { return @_ > 1 ? ($_[0]{'lifetime'} = $_[1]) : $_[0]{'lifetime'} }

my @B62 = ('0' .. '9', 'a' .. 'z', 'A' .. 'Z');

sub start_session {
    my($self, $h, $expires) = @_;
    return $self->new({
        %{$self},
        'sesskey' => $self->genkey,
        'name' => $h->{'name'},
        'token' => $self->genkey,
        'posted' => $h->{'posted'},
        'remote' => $h->{'remote'},
        'expires' => $expires, 
    });
}

sub genkey {
    my($class) = @_;
    my $t = join q(), map { $B62[$_ % @B62] } unpack 'C*', $random_bytes->(64);
    return "c$t";
}

sub find_authenticate {
    my($self, $wiki, $key) = @_;
    return if ! $key;
    my $h = $wiki->db->call('cookies.select_auth',
        {'sesskey' => $key, 'expires' => $wiki->now})->[0];
    return $h && $self->new({%{$self}, %{$h}});
}

sub signin {
    my($self, $wiki, $h0) = @_;
    my $h = {'posted' => $wiki->now};
    @{$h}{qw(name password remote)} = @{$h0}{qw(name password remote)};
    return if $wiki->user;
    return if $wiki->sch && ! $wiki->sch->pass($wiki, $h->{'remote'}, $h->{'posted'});
    return if ! $wiki->auth->check($h);
    $wiki->sch && $wiki->sch->preset($wiki, $h->{'remote'}, $h->{'posted'});
    my $expires = $h->{'posted'} + $self->lifetime;
    my $user = $self->start_session($h, $expires);
    $wiki->db->call('cookies.insert', $user);
    return $wiki->user($user);
}

sub signout {
    my($self, $wiki) = @_;
    return if ! $self->sesskey;
    $wiki->db->call('cookies.update',
        {'sesskey' => $self->sesskey, 'expires' => $wiki->now - 1});
    $wiki->user(undef);
    return 1;
}

sub long_silence {
    my($self, $wiki, $time, @name_list) = @_;
    my $stx = $wiki->db->prepare('cookies.select_latest');
    for my $name (@name_list) {
        $stx->execute({'name' => $name});
        my $h = $stx->fetchrow or next;
        return q() if $h->{'posted'} > $time;
    }
    return 1;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Cookie - the cookie session for signin user.

=head1 VERSION

0.02

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


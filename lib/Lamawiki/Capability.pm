package Lamawiki::Capability;
use strict;
use warnings;

our $VERSION = '0.01';

sub new { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }

sub allow {
    my($self, $wiki, $action, $orig, $page) = @_;
    my $role = $self->roleof($wiki, $wiki->user);
    my $domain = $self->domainof($wiki, $orig->title);
    return if $domain eq 'readonly';
    return 1 if $role eq 'master';
    return if $role ne 'master'    and $domain eq 'private';
    if ($role eq 'anonymous') {
        return if $domain ne 'public';
        return if ! $wiki->config->{'anonymous.edit'};
        return if $self->check_protect($wiki);
        return if $action eq 'insert' && ! $wiki->config->{'anonymous.insert'};
        return if $action eq 'delete' && ! $wiki->config->{'anonymous.delete'};
        return if ($action eq 'insert' || $action eq 'update')
                    && $self->count_deny_link($wiki, $orig, $page) > 0;
    }
    return 1;
}

sub roleof {
    my($self, $wiki, $user) = @_;
    return 'anonymous' if ! $user;
    my $name = $user->name;
    my $roleof = $wiki->config->{'role'} || +{};
    return $roleof->{$name} || $roleof->{q(*)} || 'user';
}

sub domainof {
    my($self, $wiki, $q) = @_;
    return 'readonly' if exists $wiki->generater->{$q};
    my $domainof = $wiki->config->{'domain'} || [];
    my $i = 0;
    while ($i < @{$domainof}) {
        my($k, $v) = @{$domainof}[$i, $i + 1]; $i += 2;
        return $v if $q =~ m/\A$k\z/msx;
    }
    return 'public';
}

sub check_protect {
    my($self, $wiki) = @_;
    my $period = $wiki->config->{'protect_after'} or return q();
    my $roleof = $wiki->config->{'role'} or return q();
    if (! exists $self->{'_check_protect'}) {
        $self->{'_check_protect'}
            = $wiki->session->long_silence($wiki, $wiki->now - $period, 
                grep { $roleof->{$_} eq 'master' } keys %{$roleof});
    }
    return $self->{'_check_protect'};
}

sub count_deny_link {
    my($self, $wiki, $orig, $page) = @_;
    return 0 if ! $page;
    my $uric = qr{[\w\#\$&'()*+,\-./:;=?\@~]|%[0-9A-Fa-f]{2}}msx;
    my %keep;
    my $origsrc = $orig->source;
    while ($origsrc =~ m{\b((?:ht|f)tps?://$uric+)}gmsx) {
        my $uri = $1;
        $keep{$uri} = 1;
    }
    my $n = 0;
    my $lexauthority = qr{\A
        [0-9A-Za-z]+(?:-[0-9A-Za-z]+)*(?:[.][0-9A-Za-z]+(?:-[0-9A-Za-z]+)*)+
    \z}msx;
    my $pagesrc = $page->source or return 0;
    my $linkok = join q(|), qr/example[.](?:net|org|com)/msx,
                            @{$wiki->config->{'link_ok'} || []};
    $linkok = qr/\A(?:.+?[.])?(?:$linkok)\z/msx;
    while ($pagesrc =~ m{\b((?:ht|f)tps?://$uric+)}gmsx) {
        my $uri = $1;
        next if $keep{$uri};
        if ($uri =~ m{\A(?:ht|f)tps?://([^/?#]*)}msx) {
            my $s = $1;
            next if $s =~ m/$lexauthority/msx && $s =~ m/$linkok/msx;
        }
        ++$n;
    }
    return $n;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Capability - authorization for wiki data.

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


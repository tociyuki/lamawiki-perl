package Lamawiki::Interwiki;
use strict;
use warnings;
use Carp;
use Encode;

our $VERSION = '0.01';

sub new  { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub server { return $_[0]{'server'} }

sub reload {
    my($self, $h) = @_;
    return $self->new({'server' => $h});
}

sub resolve {
    my($self, $q) = @_;
    if ($q =~ m/\A(\p{Alnum}[\w\-.]*):(.+?)\z/msx) {
        my($key, $arg) = ($1, $2);
        my $uri = $self->server->{$key} or return;
        if ($uri !~ m/\x{24}(?:1(?!\d)|[(]1:(utf8|euc|jis|sjis)[)])/msx) {
            $uri .= "\x{24}(1:utf8)";
        }
        $uri =~ s{\x{24}(?:1(?!\d)|[(]1:(utf8|euc|jis|sjis)[)])}
                 {_escape_encode($1 || 'utf8', $arg)}egmsx;
        $uri =~ s{(%[0-9A-Fa-f]{2})|(&(?:amp;)?)|([^0-9A-Za-z\-_.,:;+=()/~?\#])}
                 {$1 ? $1 : $2 ? '&amp;' : sprintf '%%%02X', ord $3}egmsxo;
        return $uri;
    }
    return;
}

sub _escape_encode {
    my($e, $s) = @_;
    my %enc = (
        'utf8' => 'UTF-8', 'euc' => 'euc-jp', 'jis' => 'jis', 'sjis' => 'shiftjis',
    );
    $s = encode($enc{$e}, $s);
    $s =~ s{([^0-9A-Za-z\-_./~])}{sprintf '%%%02X', ord $1}egmsx;
    return $s;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Interwiki - the interwiki resolver.

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


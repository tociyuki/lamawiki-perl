package Lamawiki::Htpasswd;
use strict;
use warnings;
use integer;
use Carp;
use Encode;
use Digest::MD5 qw(md5);
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64);

our $VERSION = '0.03';

sub new { return bless {%{$_[1]}}, ref $_[0] || $_[0] }
sub path { return shift->{'path'} }

sub check {
    my($self, $h) = @_;
    return if ! defined $h->{'name'} || $h->{'name'} eq q();
    return if ! defined $h->{'password'} || $h->{'password'} eq q();
    my $secret = $self->get($h->{'name'}) or return;
    return crypt_pbkdf2(encode_utf8($h->{'password'}), $secret) eq $secret
           || crypt_md5(encode_utf8($h->{'password'}), $secret) eq $secret;
}

sub get {
    my($self, $username) = @_;
    my $secret = q(not found);
    my $path = $self->path;
    open my($fh), '<:encoding(utf-8)', $path or croak "cannot open '$path'. $!";
    binmode $fh;
    while (<$fh>) {
        chomp;
        my($k, $v) = split /:/msx, $_, 3;
        if ($k eq $username) {
            $secret = $v;
            last;
        }
    }
    close $fh;
    return $secret;
}

sub crypt_pbkdf2 {
    my($plain, $secret) = @_;
    my @c64 = ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '.', '/');
    $secret ||= '$d8$10$' . (join q(), map { $c64[rand 64] } 1 .. 22);
    if ($secret =~ m{\A\$d8\$([12][0-9]?|3[0-1]?|[4-9])\$([a-zA-Z0-9./]{22})}msx) {
        my $cost = $1;
        my $salt = $2;
        my $t = pbkdf2(\&hmac_sha256, $plain, $salt, 1 << $cost, 48);
        my $b64 = encode_base64($t, q());
        $b64 =~ tr/+/./;
        return '$d8$' . $cost . '$' . $salt . $b64;
    }
    return "not $secret";
}

sub pbkdf2 {
    my($prf, $password, $salt, $c, $dklen) = @_;
    my $dk = q();
    my $i = 0;
    while ($dklen > 0) {
        my $u = $prf->($salt . pack('N', ++$i), $password);
        my $t = $u;
        for (2 .. $c) {
            $u = $prf->($u, $password);
            $t ^= $u;
        }
        my $n = $dklen < (length $t) ? $dklen : (length $t);
        $dk .= substr $t, 0, $n;
        $dklen -= $n;
    }
    return $dk;
}

sub crypt_md5 {
    my($plain, $secret) = @_;
    my $c64 = [q(.), q(/), '0' .. '9', 'A' .. 'Z', 'a' .. 'z'];
    my($magic, $salt) = $secret =~ m{\A(\$(?:apr)?1\$)([./0-9A-Za-z]{1,8})\$}msx
        ? ($1, $2) : return "not $secret";

    my $digest = md5($plain, $salt, $plain);
    for my $n (length $plain) {
        my $s = join q(), $plain, $magic, $salt,
                    substr $digest x (1 + ($n >> 4)), 0, $n;
        my($i, $c0, $p0) = ($n, (pack 'C', 0), (substr $plain, 0, 1));
        while ($i) {
            $s .= $i & 1 ? $c0 : $p0;
        } continue { $i >>= 1 }
        $digest = md5($s);
    }
    for (0 .. 22) { # 1000 == 2 * 3 * 7 * 23 + 34
        $digest = md5($digest,                $plain ); #  0: 0 0 0
        $digest = md5($plain,  $salt, $plain, $digest); #  1: 1 1 1
        $digest = md5($digest, $salt, $plain, $plain ); #  2: 0 2 2
        $digest = md5($plain,         $plain, $digest); #  3: 1 0 3
        $digest = md5($digest, $salt, $plain, $plain ); #  4: 0 1 4
        $digest = md5($plain,  $salt, $plain, $digest); #  5: 1 2 5
        $digest = md5($digest,        $plain, $plain ); #  6: 0 0 6
        $digest = md5($plain,  $salt,         $digest); #  7: 1 1 0
        $digest = md5($digest, $salt, $plain, $plain ); #  8: 0 2 1
        $digest = md5($plain,         $plain, $digest); #  9: 1 0 2
        $digest = md5($digest, $salt, $plain, $plain ); # 10: 0 1 3
        $digest = md5($plain,  $salt, $plain, $digest); # 11: 1 2 4
        $digest = md5($digest,        $plain, $plain ); # 12: 0 0 5
        $digest = md5($plain,  $salt, $plain, $digest); # 13: 1 1 6
        $digest = md5($digest, $salt,         $plain ); # 14: 0 2 0
        $digest = md5($plain,         $plain, $digest); # 15: 1 0 1
        $digest = md5($digest, $salt, $plain, $plain ); # 16: 0 1 2
        $digest = md5($plain,  $salt, $plain, $digest); # 17: 1 2 3
        $digest = md5($digest,        $plain, $plain ); # 18: 0 0 4
        $digest = md5($plain,  $salt, $plain, $digest); # 19: 1 1 5
        $digest = md5($digest, $salt, $plain, $plain ); # 20: 0 2 6
        $digest = md5($plain,                 $digest); # 21: 1 0 0
        $digest = md5($digest, $salt, $plain, $plain ); # 22: 0 1 1
        $digest = md5($plain,  $salt, $plain, $digest); # 23: 1 2 2
        $digest = md5($digest,        $plain, $plain ); # 24: 0 0 3
        $digest = md5($plain,  $salt, $plain, $digest); # 25: 1 1 4
        $digest = md5($digest, $salt, $plain, $plain ); # 26: 0 2 5
        $digest = md5($plain,         $plain, $digest); # 27: 1 0 6
        $digest = md5($digest, $salt,         $plain ); # 28: 0 1 0
        $digest = md5($plain,  $salt, $plain, $digest); # 29: 1 2 1
        $digest = md5($digest,        $plain, $plain ); # 30: 0 0 2
        $digest = md5($plain,  $salt, $plain, $digest); # 31: 1 1 3
        $digest = md5($digest, $salt, $plain, $plain ); # 32: 0 2 4
        $digest = md5($plain,         $plain, $digest); # 33: 1 0 5
        $digest = md5($digest, $salt, $plain, $plain ); # 34: 0 1 6
        $digest = md5($plain,  $salt,         $digest); # 35: 1 2 0
        $digest = md5($digest,        $plain, $plain ); # 36: 0 0 1
        $digest = md5($plain,  $salt, $plain, $digest); # 37: 1 1 2
        $digest = md5($digest, $salt, $plain, $plain ); # 38: 0 2 3
        $digest = md5($plain,         $plain, $digest); # 39: 1 0 4
        $digest = md5($digest, $salt, $plain, $plain ); # 40: 0 1 5
        $digest = md5($plain,  $salt, $plain, $digest); # 41: 1 2 6
    }
    $digest = md5($digest,                $plain ); #  0: 0 0 0
    $digest = md5($plain,  $salt, $plain, $digest); #  1: 1 1 1
    $digest = md5($digest, $salt, $plain, $plain ); #  2: 0 2 2
    $digest = md5($plain,         $plain, $digest); #  3: 1 0 3
    $digest = md5($digest, $salt, $plain, $plain ); #  4: 0 1 4
    $digest = md5($plain,  $salt, $plain, $digest); #  5: 1 2 5
    $digest = md5($digest,        $plain, $plain ); #  6: 0 0 6
    $digest = md5($plain,  $salt,         $digest); #  7: 1 1 0
    $digest = md5($digest, $salt, $plain, $plain ); #  8: 0 2 1
    $digest = md5($plain,         $plain, $digest); #  9: 1 0 2
    $digest = md5($digest, $salt, $plain, $plain ); # 10: 0 1 3
    $digest = md5($plain,  $salt, $plain, $digest); # 11: 1 2 4
    $digest = md5($digest,        $plain, $plain ); # 12: 0 0 5
    $digest = md5($plain,  $salt, $plain, $digest); # 13: 1 1 6
    $digest = md5($digest, $salt,         $plain ); # 14: 0 2 0
    $digest = md5($plain,         $plain, $digest); # 15: 1 0 1
    $digest = md5($digest, $salt, $plain, $plain ); # 16: 0 1 2
    $digest = md5($plain,  $salt, $plain, $digest); # 17: 1 2 3
    $digest = md5($digest,        $plain, $plain ); # 18: 0 0 4
    $digest = md5($plain,  $salt, $plain, $digest); # 19: 1 1 5
    $digest = md5($digest, $salt, $plain, $plain ); # 20: 0 2 6
    $digest = md5($plain,                 $digest); # 21: 1 0 0
    $digest = md5($digest, $salt, $plain, $plain ); # 22: 0 1 1
    $digest = md5($plain,  $salt, $plain, $digest); # 23: 1 2 2
    $digest = md5($digest,        $plain, $plain ); # 24: 0 0 3
    $digest = md5($plain,  $salt, $plain, $digest); # 25: 1 1 4
    $digest = md5($digest, $salt, $plain, $plain ); # 26: 0 2 5
    $digest = md5($plain,         $plain, $digest); # 27: 1 0 6
    $digest = md5($digest, $salt,         $plain ); # 28: 0 1 0
    $digest = md5($plain,  $salt, $plain, $digest); # 29: 1 2 1
    $digest = md5($digest,        $plain, $plain ); # 30: 0 0 2
    $digest = md5($plain,  $salt, $plain, $digest); # 31: 1 1 3
    $digest = md5($digest, $salt, $plain, $plain ); # 32: 0 2 4
    $digest = md5($plain,         $plain, $digest); # 33: 1 0 5
    return $magic . $salt . q($)
        . _encode_vector($c64, $digest, 4,  0,  6, 12)
        . _encode_vector($c64, $digest, 4,  1,  7, 13)
        . _encode_vector($c64, $digest, 4,  2,  8, 14)
        . _encode_vector($c64, $digest, 4,  3,  9, 15)
        . _encode_vector($c64, $digest, 4,  4, 10,  5)
        . _encode_vector($c64, $digest, 2, 11);
}

sub _encode_vector {
    my($c64, $digest, $n, $i, $j, $k) = @_;
    my $x = $n == 2
        ?  (unpack 'C', substr $digest, $i, 1)
        : ((unpack 'C', substr $digest, $i, 1) << 16)
        | ((unpack 'C', substr $digest, $j, 1) <<  8)
        |  (unpack 'C', substr $digest, $k, 1);
    my $t = q();
    for (1 .. $n) {
        $t .= $c64->[$x & 0x3f];
        $x >>= 6;
    }
    return $t;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Htpasswd - check user password with htpasswd file

=head1 VERSION

0.03

=head1 AUTHOR

MIZUTANI Tociyuki

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2015, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


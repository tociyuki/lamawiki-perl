package Lamawiki::Strftime;
use strict;
use warnings;
use Carp;
use Time::Local qw(timelocal timegm);
use base qw(Exporter);

our $VERSION = '0.02';

our @EXPORT_OK = qw(strftime);

my $TIMESTUMP = qr{
    ([0-9]{4})-([0-9]{2})-([0-9]{2}) [ T] ([0-9]{2}):([0-9]{2}):([0-9]{2})(Z)?
}msx;

my @TIMEA = qw(Sun Mon Tue Wed Thu Fri Sat);
my @TIMEB = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @TIMEP = qw(AM PM);

sub strftime {
    my($fmt, $datetime) = @_;
    my $is_utc = $fmt =~ m/GMT|UTC|[+-]00:?00|%-?[0-9]*[mdMS]Z\b/msxo;
    my %t;
    $datetime = defined $datetime ? $datetime : time;
    if (! ref $datetime && $datetime =~ m/\A[0-9]+\z/msxo) {
        $t{'s'} = $datetime;
    }
    elsif (! ref $datetime && $datetime =~ m/\A$TIMESTUMP\z/msxo) {
        $t{'s'} = $7 ? timegm($6, $5, $4, $3, $2 - 1, $1 - 1900)
                     : timelocal($6, $5, $4, $3, $2 - 1, $1 - 1900);
    }
    elsif (ref $datetime && eval { $datetime->can('epoch') }) {
        $t{'s'} = $datetime->epoch;
    }
    else {
        croak "strftime: cannot datetime '$datetime'.";
    }
    @t{qw(S M H d _b _y _a j)} = $is_utc ? gmtime $t{'s'} : localtime $t{'s'};
    @t{qw(Y m w)} = ($t{'_y'} + 1900, $t{'_b'} + 1, $t{'_a'});
    @t{qw(y C)} = ($t{'Y'} % 100, int $t{'Y'} / 100);
    @t{qw(I _p)} = ($t{'H'} % 12 || 12, $t{'H'} < 12 ? 0 : 1);
    @t{qw(a b p)} = ($TIMEA[$t{'_a'}], $TIMEB[$t{'_b'}], $TIMEP[$t{'_p'}]);
    my %d = ('Y' => '%04d', 'j' => '%d', 'w' => '%d', 's' => '%d');
    $fmt =~ s{
        \%
        (?: (\%)
        |   (-?[0-9]*)(?:([SMHIdmYyCjws])) # 2 3
        |   ([abp]) # 4
        |   \(([^\)]*)\)([abp]) # 5 6
        )
    }{
          $1 ? $1
        : $4 ? $t{$4}
        : $6 ? (split /\s/msx, $5)[$t{"_$6"}]
        : (sprintf $2 ne q() ? "%$2d" : $d{$3} ? $d{$3} : '%02d', $t{$3})
    }egmsx;
    return $fmt;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Strftime - format date and time

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


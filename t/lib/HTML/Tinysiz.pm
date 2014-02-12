package HTML::Tinysiz;
use strict;
use warnings;
use Carp;

our $VERSION = '0.03';
# https://gist.github.com/tociyuki/7626735

my $ID = qr/[\p{Alpha}_:][\w:-]*/msx;
my $SP = qr/[ \t\n\r]/msx;
my $NL = qr/(?:\r\n?|\n)/msx;
my $TAGNAMESEL = qr/\G(?:($ID)|[*])/msx;
my $ATTRSEL = qr/\G(?:\#($ID)|[.]([\w:-]+)|\[($ID)(?:([~^\$*|]?=)"([^"]+)")?\])/msx;
my %SELF_CLOSING = map { $_ => 1 } qw(
    area base br col command embed hr img input link meta param source
);

sub new {
    my($class, $s) = @_;
    my @parent;
    my $node = my $doc = $class->node('#doc');
    while ($s =~ m{\G
        $SP*(.*?)$SP*
        ([<](?:($ID)(.*?)$SP*(/?>)|/($ID)$SP*>
            |   \?.*?\?>|\!--.*?-->|\!\[CDATA\[.*?\]\]>|\!DOCTYPE[^>]+?>))
    }gcmsxo) {
        my($t1, $t2, $stag3, $attr4, $gt5, $etag6) = ($1, $2, $3, $4, $5, $6);
        $t1 ne q() and push @{$node}, $t1;
        if ($stag3) {
            my $element = $class->node($stag3);
            while ($attr4 =~ m{\G
                $SP+($ID)
                (?:$SP*=$SP*("([^<>"]*)"|'([^<>']*)|`([^<>`]*)`|[^\s<>"'`=]+))?
            }gcmsxo) {
                $element->attr->{$1} = defined $2 ? $+ : $1;
            }
            push @{$node}, $element;
            next if $gt5 eq q(/>) || exists $SELF_CLOSING{lc $stag3};
            push @parent, $node;
            $node = $element;
        }
        elsif ($etag6) {
            my $stag3 = $node->tagname;
            $etag6 eq $stag3 or croak "<$stag3> ne </$etag6>";
            $node = pop @parent;
        }
        elsif ($t2) {
            push @{$node}, $class->node($t2);
        }
    }
    if ($s =~ m/\G$SP*(\S.*?)$SP*\z/gcmsx) {
        push @{$node}, $1;
    }
    @parent and croak 'invalid.';
    return $doc;
}

sub get    { return shift->_selectall($_[0], 1) }
sub getall { return shift->_selectall($_[0], 0) }

sub _selectall {
    my($self, $s, $once) = @_;
    my $sel = $self->_parse($s);
    my @a;
    my @kont = ([$self]);
    while (@kont) {
        my @path = @{shift @kont};
        my $x = $path[-1];
        if ($self->_match($sel, @path)) {
            return $x if $once;
            push @a, $x;
        }
        unshift @kont, map { ref $_ ? [@path, $_] : () } $x->child;
    }
    return if $once;
    return @a;
}

sub node     { return bless [$_[1], {}], $_[0] }
sub tagname  { return $_[0][0] }
sub attr     { return $_[0][1] }
sub child    { return @{$_[0]}[2 .. $#{$_[0]}] }

sub _parse {
    my($class, $s) = @_;
    my @sel;
    for (split /\s+/msx, $s) {
        my @term = (m/$TAGNAMESEL/gcmsxo ? $1 : undef);
        while (m/$ATTRSEL/gcmsxo) {
            push @term, $1 ? ('id', q(=), $1)
                : defined $2 ? ('class', q(~=), $2)
                : $3 ? ($3, $4, $5)
                : ();
        }
        push @sel, \@term;
    }
    return \@sel;
}

sub _match {
    my($self, $sel, @path) = @_;
    my @list = @{$sel};
    my $base = pop @path;
    my($tagname, @attrsel) = @{pop @list};
    return if $tagname && $base->tagname ne $tagname;
    return if ! $base->_match_attr(@attrsel);
    my $term = shift @list or return 1;
    for my $node (@path) {
        my($tagname, @attrsel) = @{$term};
        next if $tagname && $node->tagname ne $tagname;
        next if ! $node->_match_attr(@attrsel);
        $term = shift @list or return 1;
    }
    return;
}

sub _match_attr {
    my($self, @attrsel) = @_;
    while (my($attr, $op, $str) = splice @attrsel, 0, 3) {
        return if ! exists $self->attr->{$attr};
        next if ! defined $op;
        my $value = $self->attr->{$attr};
        return if ! defined $value;
        return if $op eq q(=)  && $value ne $str;
        return if $op eq q(~=) && 0 > index " $value ", " $str ";
        return if $op eq q(^=) && $value !~ m/\A\Q$str\E/msx;
        return if $op eq q($=) && $value !~ m/\Q$str\E\z/msx;
        return if $op eq q(*=) && 0 > index $value, $str;
        return if $op eq q(|=) && 0 > index "-$value-", "-$str-";
    }
    return 1;
}

1;

__END__

=pod

=head1 NAME

HTML::Tinysiz - Picks up HTML element(s) with CSS2 like selector

=head1 VERSION

0.03

=head1 AUTHOR

MIZUTANI Tociyuki  C<< <tociyuki\x40gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2013, MIZUTANI Tociyuki C<< <tociyuki\x40gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


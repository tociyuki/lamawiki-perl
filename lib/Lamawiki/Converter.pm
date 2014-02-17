package Lamawiki::Converter;
use strict;
use warnings;
use Encode;

our $VERSION = '0.01';

my $URIC = qr{[\w\#\$&'()*+,\-./:;=?\@~]|%[0-9A-Fa-f]{2}}msx;
my $HTURI = qr{(?:ht|f)tps?://[0-9A-Za-z\-.]+(?:[/?\#]$URIC*)?}msx;
my %TAG = (
    q(>>>) => "\n<blockquote>", q(<<<) => "</blockquote>\n",
    q(----) => "\n<hr />\n",
    q(*) => [qw(ul li)], q(1.) => [qw(ol li)],
    q(?) => [qw(dl dt)], q(:)  => [qw(dl dd)],
);
my %ESC = (
    qw[& &amp; < &lt; > &gt; " &quot;],
    q(') => '&#39;', q(*) => '&#42;',
);
my $AMP = qr/&(?:\#(?:[1-9][0-9]{1,9};|x[0-9A-Fa-f]{1,8};)|[A-Za-z][0-9A-Za-z]{0,15};)?/msx;

sub new      { return bless +{%{$_[1] || +{}}}, ref $_[0] || $_[0] }
sub rel      { return $_[0]{'rel'} }
sub footnote { return $_[0]{'footnote'} }
sub reflink  { return $_[0]{'reflink'} }

sub _htmlall_escape {
    my($s) = @_;
    $s =~ s/([&<>"'*])/$ESC{$1}/egmsxo;
    return $s;
}

sub _htmlstar_escape {
    my($s) = @_;
    $s =~ s/($AMP|[<>"'*])/$ESC{$1} || $1/egmsxo;
    return $s;
}

sub _html_escape {
    my($s) = @_;
    $s =~ s/($AMP|[<>"'])/$ESC{$1} || $1/egmsxo;
    return $s;
}

sub _uriall_escape {
    my($s) = @_;
    utf8::is_utf8($s) and $s = encode_utf8($s);
    $s =~ s{([^0-9A-Za-z_\-./~])}{sprintf '%%%02X', ord $1}egmsxo;
    return $s;
}

sub _uri_escape {
    my($s) = @_;
    utf8::is_utf8($s) and $s = encode_utf8($s);
    $s =~ s{(%[0-9A-Fa-f]{2})|(&(?:amp;)?)|([^0-9A-Za-z\-_.,:;+=()/~?\#])}
           {$1 ? $1 : $2 ? '&amp;' : sprintf '%%%02X', ord $3}egmsxo;
    return $s;
}

sub _anchor_escape {
    my($s) = @_;
    my $a = substr $s, 0, 1;
    my $d = substr $s, 1;
    my $g = sub{
        my($i) = @_;
        my $w = $i < 0x80 ? '02' : $i < 0x10000 ? '04' : '08';
        sprintf "U%${w}xU", $i;
    };
    $a =~ s/([^A-TV-Za-z])/$g->(ord $1)/egmsx;
    $d =~ s/([^0-9A-TV-Za-z_\-.:])/$g->(ord $1)/egmsx;
    my $t = $a . $d;
    $t =~ s/UU/-/gmsx;
    return $t;
}

sub _preprocess {
    my($self, $s0) = @_;
    chomp $s0; $s0 .= "\n";
    $s0 =~ tr/\t/ /;
    $s0 =~ s/[^\n \p{Graph}]//gmsx;
    $s0 =~ s/^[ ]+$//gmsx;
    my($fn, $s) = (0, q());
    while ($s0 =~ m{\G(
        ```\n.*?\n```\n
    |   [ ]{0,3}\[\^([\w\-]+)\][:][ ]+(\S[^\n]*(?:\n[ ]{4}\S[^\n]*)*)\n
    |   [ ]{0,3}\[([\w\-]+)\][:][ ]+($HTURI)(?:[ ]+[^\n]*)?\n
    |   (-\#)? [^\n]*\n
    )}gcmsxo) {
        if (defined $2) {
            ++$fn;
            $self->footnote->{lc $2} = [$fn, "fn$fn", $3];
        }
        elsif (defined $4) {
            $self->reflink->{lc $4} = $5;
        }
        elsif (! defined $6) {
            $s .= $1;
        }
    }
    return $s;
}

sub scan_interwiki_servers {
    my($self, $page) = @_;
    my $h = {};
    my $s = $page->source;
    return $self if $s eq q();
    chomp $s; $s .= "\n";
    $s =~ s/^```\n.*?\n```\n//gmsx;
    while ($s =~ m{
        ^[ ]*[?][ ]+(\p{Alnum}[\w\-.]*)[^\n]*\n+
         [ ]*[:][ ]+(
            https?://[0-9A-Za-z][0-9A-Za-z\-.]*(?:[:][0-9]*)?
            (?:/(?:~?[0-9A-Za-z][0-9A-Za-z\-_.,;:*()&+\$%]*
                   (?:/~?[0-9A-Za-z][0-9A-Za-z\-_.,;:*()&+\$%]*)*/?)?)?
            (?:[?][0-9A-Za-z\-_=.,;:*()/&+\$%?]*)?
            (?:\#[A-Za-z][0-9A-Za-z\-.:]*)?
        )[^\n]*\n+
    }gmsxo) {
        $h->{$1} = $2;
    }
    return $h;
}

sub convert {
    my($self, $page) = @_;
    my $c = $self->new({%{$self}, 'rel' => {}, 'footnote' => {}, 'reflink' => {}});
    $page = $page->new({%{$page}, 'rel' => []});
    my $s = $c->_preprocess($page->source);
    my $summary = q();
    my($toc, $t, $tnest, $nest, %section) = (q(), q(), [[0]], [[0]]);
    while ($s =~ m{\G
        (?: ()\n+|(>>>|<<<|-{4,})\n+|```\n(.*?)\n```\n+
        |   ([ ]*)([!]\[[^\[\]]*\](?:\[\[[^\[\]]*\]\]
            |\(\s*https?://[0-9A-Za-z\-.]+[/?]$URIC+\s*\)))\n+
        |   (\#{1,5})\#*[ ]*([^\n]+?)[ ]*(?:\#+[ ]*)?\n+
        |   ([ ]*)(?:([?:*])|[0-9]+[.])[ ]+(\S[^\n]*(?:\n
             [ ]*(?![?:*][ ]|[0-9]+[.][ ]|[!]\[[^\[\]]*\]|>>>\n|<<<\n)
             \S[^\n]*)*)\n+
        |   ([ ]*\S[^\n]*(?:\n[ ]*(?!>>>\n|<<<\n)\S[^\n]*)*)\n
        )
    }gcmsxo) {
        my $b = $#-;
        $t .= $b == 11 ? $c->_nestag($nest, q(), 'p')
            : $b == 10 ? $c->_nestag($nest, " $8", @{$TAG{$9 || '1.'}})
            : $4 ? q()
            : $b == 2 ? $c->_nestag($nest, q()) . ($TAG{$2} || $TAG{q(----)}) 
            : $c->_nestag($nest, q());
        my $sharps = $6;
        if ($b == 3) {
            $t .= "\n<pre><code>" . _htmlall_escape($3) . "</code></pre>\n";
        }
        elsif ($b == 5) {
            $t .= $c->_figure($page, $5);
        }
        next if $b < 7;
        my $t1 = $c->_inline($page, $+);
        my $t2 = $t1;
        $t2 =~ s/<[^>]*>//gmsx;
        $summary .= $t2 . "\n";
        if (defined $sharps) {
            my $n = 1 + length $sharps;
            my $m = ++$section{$t2};
            my $escid = _anchor_escape($t2 . ($m == 1 ? q() : "_$m"));
            $toc .= $c->_nestag($tnest, q( ) x $n, 'ul', 'li')
                . qq(<a href="#$escid">$t2</a>);
            $t1 = qq(\n<h$n id="$escid">$t1</h$n>\n);
        }
        $t .= $t1;
    }
    $t .= $c->_nestag($nest, q());
    $toc .= $c->_nestag($tnest, q());
    if ($summary =~ m/^[ ]*(\S[^\n]*)$/msx) {
        $summary = $1;
    }
    if ($toc) {
        $t = qq(\n<nav id="toc">$toc</nav>\n) . $t;
    }
    $t =~ s{\n<div[ ]wiki="toc:?">(.*?)</div>\n}{
          $toc eq q() ? q()
        : $1 eq q() ? $toc
        : qq(\n<nav class="toc">\n<h1>$1</h1>\n$toc</nav>\n);
    }egmsx;
    if (%{$c->footnote}) {
        $t .= qq(\n<ol class="footnote">\n);
        for (sort { $a->[0] <=> $b->[0] } values %{$c->footnote}) {
            my($fn, $id, $line) = @{$_};
            my $escid = _uriall_escape($id);
            my $y = $c->_inline($page, $line);
            $t .= qq(<li id="$escid">$y</li>\n);
        }
        $t .= qq(</ol>\n);
    }
    $t =~ s/&\#42;/*/gmsx;
    return $page->new({%{$page}, 'summary' => $summary, 'content' => $t});
}

sub _figure {
    my($self, $page, $s) = @_;
    if ($s =~ m{
        \A[!]\[([^\[\]]*)\](?:\[\[\s*([^\[\]]+?)\s*\]\]
        | \(\s*(https?://[0-9A-Za-z\-.]+[/?]$URIC+)\s*\))\z
    }msxo) {
        if (defined $3) {
            my($escx, $escu) = (_html_escape($1), _uri_escape($3));
            my $t = qq(\n<figure>\n<img src="$escu" alt="" /><br />\n);
            if ($escx ne q()) {
                $t .= qq(<figcaption>$escx</figcaption>\n);
            }
            $t .= qq(</figure>\n);
            return $t;
        }
        elsif ($page->is_title($2)) {
            my($escx, $esck) = (_html_escape($1), _htmlall_escape($2));
            return qq(\n<div wiki="$esck">$escx</div>\n);
        }
    }
    return "\n<p>" . _htmlall_escape($s) . "</p>\n";
}

sub _inline {
    my($self, $page, $s) = @_;
    my $t = q();
    $s =~ s/^[ ]+//gmsx;
    while ($s =~ m{\G(.*?)(()\z
    |   (`+)\s*(.*?)\s*\4
    |   ([ ]{2}\n)
    |   \[\^([\w\-]+)\]
    |   \[\[\s*([^\[\]]+?)\s*\]\]
    |   \[([^\[\]]+)\]
        (?:\s*\[\[\s*([^\[\]]+?)\s*\]\]|\s*\[([\w\-]*)\]|\(\s*($HTURI)\s*\))?
    |   <($HTURI)>
    |   [*]{4,}|(?:^|(?<=[\s.,;:?!]))[*]+(?:$|(?=[\s.,;:?!]))
    )}gcmsxo) {
        if ($1 ne q()) {
            $t .= _html_escape($1);
        }
        last if defined $3;
        if (defined $8 || defined $10) {
            my($q, $f) = split m/\#/msx, defined $8 ? $8 : $10, 2;
            my $escx = _htmlstar_escape(defined $8 ? $8 : $9);
            my $escf = defined $f ? q(#) ._anchor_escape($f) : q();
            if ($q eq q()) {
                $t .= qq(<a href="$escf">$escx</a>);
                next;
            }
            elsif ($page->is_title($q)) {
                if (! exists $self->rel->{$q}) {
                    push @{$page->rel}, $page->new({'title' => $q});
                    $self->rel->{$q} = $#{$page->rel};
                }
                my $esci = _uri_escape($self->rel->{$q});
                my $escq = _htmlstar_escape($q);
                $t .= qq(<a href="$esci$escf" title="$escq">$escx</a>);
                next;
            }
        }
        elsif (defined $13 || defined $9) {
            my $u = $13 || $12
                || $self->reflink->{defined $11 && $11 ne q() ? lc $11 : lc $9};
            if ($u) {
                my $escu = _uri_escape($u);
                my $escx = _htmlstar_escape($13 || $9);
                $t .= qq(<a href="$escu">$escx</a>);
                next;
            }
        }
        elsif (defined $7) {
            my $k = lc $7;
            if (exists $self->footnote->{$k}) {
                my $escid = _uriall_escape($self->footnote->{$k}[1]);
                my $escfn = _htmlstar_escape($self->footnote->{$k}[0]);
                $t .= qq(<a href="#$escid" rel="footnote">$escfn</a>);
                next;
            }
        }
        elsif (defined $6) {
            $t .= "<br />\n";
            next;
        }
        my($ticks, $escx) = ($4 || q(), _htmlall_escape(defined $5 ? $5 : $2));
        $t .= (length $ticks) > 2 ? "<code>$escx</code>" : $escx;
    }
    $t =~ s{(?<![*])[*]((?:[*][*])?)([^\s*][^*]*?)(?<=[^\s*])[*]((?:[*][*])?)(?![*])}
           {$1<em>$2</em>$3}gmsx;
    $t =~ s{[*][*]([^\s*][^*]*?)(?<=[^\s*])[*][*]}{<strong>$1</strong>}gmsx;
    $t =~ s{[*]([^\s*][^*]*?)(?<=[^\s*])[*]}{<em>$1</em>}gmsx;
    return $t;
}

sub _nestag {
    my($self, $nest, $indent, @stag) = @_;
    my $level = length $indent;
    my $t = q();
    while (@{$nest} > 1 && $level < $nest->[-1][0]) {
        if ($nest->[-2][0] < $level) {
            $nest->[-1][0] = $level;
            last;
        }
        my(undef, @etag) = @{pop @{$nest}};
        $t .= join q(), map { "</$_>\n" } reverse @etag;
    }
    if ($nest->[-1][0] < $level) {
        push @{$nest}, [$level, @stag];
        $t .= join q(), map { "\n<$_>" } @stag;
    }
    else {
        my(undef, @etag) = @{$nest->[-1]};
        @{$nest->[-1]} = ($level, @stag);
        my $x = (join q(), map { "</$_>\n" } reverse @etag)
              . (join q(), map { "\n<$_>" } @stag);
        $x =~ s{</([dou]l)>\n\n<\1>\n}{}gmsx;
        $t .= $x;
    }
    return $t;
}

1;

__END__

=pod

=head1 NAME

Lamawiki::Converter - convert text from the source field to the content field.

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


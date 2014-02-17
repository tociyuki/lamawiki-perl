use strict;
use warnings;
use Encode;
use Lamawiki;
use Lamawiki::Page;
use Lamawiki::Interwiki;
use Lamawiki::Liq;
use Lamawiki::Controller;
use Test::More;

plan tests => 3;

my $server = {
    'plain' => 'http://www.example.net/wiki?',
    'default' => 'http://www.example.net/wiki?title=$1&amp;command=browse',
    'bareamp' => 'http://www.example.net/wiki?title=$1&command=browse',
    'utf8' => 'http://www.example.net/wiki?$(1:utf8)',
    'euc' => 'http://www.example.net/wiki?$(1:euc)',
    'jis' => 'http://www.example.net/wiki?$(1:jis)',
    'sjis' => 'http://www.example.net/wiki?$(1:sjis)',
};

my $wiki = Lamawiki->new({
    'page' => Lamawiki::Page->new,
    'interwiki' => Lamawiki::Interwiki->new->reload($server),
});
my $liq = Lamawiki::Liq->new;
my $view = $liq->merge_filters(
    Lamawiki::Controller->filters($wiki, '/test'),
);

{
    my $input = <<'EOS';

<p>there are many <a href="0">LamawikiEngine</a> in the world.
from page to page, page links with <a href="1">wiki name</a>.</p>
EOS
    my $expected = <<'EOS';

<p>there are many <a href="/test/4">LamawikiEngine</a> in the world.
from page to page, page links with <a href="/test/5">wiki name</a>.</p>
EOS
    my $page = $wiki->page->new({
        'id' => 3, 'title' => 'Foo', 'rev' => 3, 'content' => $input,
        'rel' => [
            $wiki->page->new({'id' => 4, 'title' => 'LamawikiEngine', 'rev' => 4}),
            $wiki->page->new({'id' => 5, 'title' => 'wiki name', 'rev' => 5}),
        ],
    });
    my $got = $view->call('RESOLVE', $page)->output;
    is $got, $expected,
        'it should resolve inner links.';
}

{
    my $input = <<'EOS';

<p><a href="0">innerlink:Foo</a></p>

<p><a href="1">plain:Foo</a><p>

<p><a href="2">default:Foo</a></p>

<p><a href="3">utf8:Foo</a></p>

<p><a href="4">euc:Foo</a></p>

<p><a href="5">jis:Foo</a></p>

<p><a href="6">sjis:Foo</a></p>
EOS
    my $expected = <<'EOS';

<p><a href="/test/4">innerlink:Foo</a></p>

<p><a href="http://www.example.net/wiki?Foo">plain:Foo</a><p>

<p><a href="http://www.example.net/wiki?title=Foo&amp;command=browse">default:Foo</a></p>

<p><a href="http://www.example.net/wiki?Foo">utf8:Foo</a></p>

<p><a href="http://www.example.net/wiki?Foo">euc:Foo</a></p>

<p><a href="http://www.example.net/wiki?Foo">jis:Foo</a></p>

<p><a href="http://www.example.net/wiki?Foo">sjis:Foo</a></p>
EOS
    my $page = $wiki->page->new({
        'id' => 3, 'title' => 'Foo', 'rev' => 3, 'content' => $input,
        'rel' => [
            $wiki->page->new({'id' => 4, 'title' => 'innerlink:Foo', 'rev' => 4}),
            $wiki->page->new({'id' => 5, 'title' => 'plain:Foo', 'rev' => 0}),
            $wiki->page->new({'id' => 6, 'title' => 'default:Foo', 'rev' => 0}),
            $wiki->page->new({'id' => 7, 'title' => 'utf8:Foo', 'rev' => 0}),
            $wiki->page->new({'id' => 8, 'title' => 'euc:Foo', 'rev' => 0}),
            $wiki->page->new({'id' => 9, 'title' => 'jis:Foo', 'rev' => 0}),
            $wiki->page->new({'id' => 10, 'title' => 'sjis:Foo', 'rev' => 0}),
        ],
    });
    my $got = $view->call('RESOLVE', $page)->output;
    is $got, $expected,
        'it should resolve inner link and inter links.';
}

{
    my $q = "\x{632f}\x{821e}";
    my $input = <<"EOS";

<p><a href="0">innerlink:$q</a></p>

<p><a href="1">plain:$q</a><p>

<p><a href="2">default:$q</a></p>

<p><a href="3">utf8:$q</a></p>

<p><a href="4">euc:$q</a></p>

<p><a href="5">jis:$q</a></p>

<p><a href="6">sjis:$q</a></p>
EOS
    my $expected = <<"EOS";

<p><a href="/test/4">innerlink:$q</a></p>

<p><a href="http://www.example.net/wiki?%E6%8C%AF%E8%88%9E">plain:$q</a><p>

<p><a href="http://www.example.net/wiki?title=%E6%8C%AF%E8%88%9E&amp;command=browse">default:$q</a></p>

<p><a href="http://www.example.net/wiki?%E6%8C%AF%E8%88%9E">utf8:$q</a></p>

<p><a href="http://www.example.net/wiki?%BF%B6%C9%F1">euc:$q</a></p>

<p><a href="http://www.example.net/wiki?%1B%24B%3F6Iq%1B%28B">jis:$q</a></p>

<p><a href="http://www.example.net/wiki?%90U%95%91">sjis:$q</a></p>
EOS
    my $page = $wiki->page->new({
        'id' => 3, 'title' => 'Foo', 'rev' => 3, 'content' => $input,
        'rel' => [
            $wiki->page->new({'id' => 4, 'title' => "innerlink:$q", 'rev' => 4}),
            $wiki->page->new({'id' => 5, 'title' => "plain:$q", 'rev' => 0}),
            $wiki->page->new({'id' => 6, 'title' => "default:$q", 'rev' => 0}),
            $wiki->page->new({'id' => 7, 'title' => "utf8:$q", 'rev' => 0}),
            $wiki->page->new({'id' => 8, 'title' => "euc:$q", 'rev' => 0}),
            $wiki->page->new({'id' => 9, 'title' => "jis:$q", 'rev' => 0}),
            $wiki->page->new({'id' => 10, 'title' => "sjis:$q", 'rev' => 0}),
        ],
    });
    my $got = $view->call('RESOLVE', $page)->output;
    is encode_utf8($got), encode_utf8($expected),
        'it should resolve inner link and inter links with encoding.';
}


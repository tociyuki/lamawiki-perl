use strict;
use warnings;
use Test::More;
use Lamawiki::Interwiki;

plan tests => 19;

{
    package Mock::Page;

    sub new { return bless {%{$_[1] || +{}}}, ref $_[0] || $_[0] }
    sub source { return @_ > 1 ? ($_[0]{'source'}   = $_[1]) : $_[0]{'source'} }
}

can_ok 'Lamawiki::Interwiki', qw(new server reload resolve);

{
    my $it = 'its resolve';
    my $interwiki = Lamawiki::Interwiki->new({
        'server' => {
            'plain' => 'http://www.example.net/wiki?',
            'default' => 'http://www.example.net/wiki?title=$1&amp;command=browse',
            'bareamp' => 'http://www.example.net/wiki?title=$1&command=browse',
            'utf8' => 'http://www.example.net/wiki?$(1:utf8)',
            'euc' => 'http://www.example.net/wiki?$(1:euc)',
            'jis' => 'http://www.example.net/wiki?$(1:jis)',
            'sjis' => 'http://www.example.net/wiki?$(1:sjis)',
        },
    });

    is ref $interwiki->server, 'HASH', "$it should inject server";
    is $interwiki->server->{'plain'},
        'http://www.example.net/wiki?', "$it should inject server definitions";

    ok ! $interwiki->resolve('NotInterWiki'),
        "$it should resolve null not to interwiki";
    is $interwiki->resolve('plain:Foo'),
        'http://www.example.net/wiki?Foo',
        "$it should resolve plain";
    is $interwiki->resolve('default:Foo'),
        'http://www.example.net/wiki?title=Foo&amp;command=browse',
        "$it should resolve default";
    is $interwiki->resolve('bareamp:Foo'),
        'http://www.example.net/wiki?title=Foo&amp;command=browse',
        "$it should resolve bare amp";
    is $interwiki->resolve('utf8:Foo'),
        'http://www.example.net/wiki?Foo',
        "$it should resolve utf8";
    is $interwiki->resolve('euc:Foo'),
        'http://www.example.net/wiki?Foo',
        "$it should resolve euc";
    is $interwiki->resolve('jis:Foo'),
        'http://www.example.net/wiki?Foo',
        "$it should resolve jis";
    is $interwiki->resolve('sjis:Foo'),
        'http://www.example.net/wiki?Foo',
        "$it should resolve sjis";

    my $title = "\x{632f}\x{821e}";
    is $interwiki->resolve("plain:$title"),
        'http://www.example.net/wiki?%E6%8C%AF%E8%88%9E',
        "$it should resolve plain (ja)";
    is $interwiki->resolve("default:$title"),
        'http://www.example.net/wiki?title=%E6%8C%AF%E8%88%9E&amp;command=browse',
        "$it should resolve default (ja)";
    is $interwiki->resolve("bareamp:$title"),
        'http://www.example.net/wiki?title=%E6%8C%AF%E8%88%9E&amp;command=browse',
        "$it should resolve bareamp (ja)";
    is $interwiki->resolve("utf8:$title"),
        'http://www.example.net/wiki?%E6%8C%AF%E8%88%9E',
        "$it should resolve utf8 (ja)";
    is $interwiki->resolve("euc:$title"),
        'http://www.example.net/wiki?%BF%B6%C9%F1',
        "$it should resolve euc (ja)";
    is $interwiki->resolve("jis:$title"),
        'http://www.example.net/wiki?%1B%24B%3F6Iq%1B%28B',
        "$it should resolve jis (ja)";
    is $interwiki->resolve("sjis:$title"),
        'http://www.example.net/wiki?%90U%95%91',
        "$it should resolve sjis (ja)";
}

{
    my $it = 'its reload';

    my $interwiki = Lamawiki::Interwiki->new->reload({
        'plain' => 'http://www.example.net/wiki?',
        'default' => 'http://www.example.net/wiki?title=$1&amp;command=browse',
        'bareamp' => 'http://www.example.net/wiki?title=$1&command=browse',
        'utf8' => 'http://www.example.net/wiki?$(1:utf8)',
        'euc' => 'http://www.example.net/wiki?$(1:euc)',
        'jis' => 'http://www.example.net/wiki?$(1:jis)',
        'sjis' => 'http://www.example.net/wiki?$(1:sjis)',
    });

    is_deeply $interwiki->server, {
        'plain' => 'http://www.example.net/wiki?',
        'default' => 'http://www.example.net/wiki?title=$1&amp;command=browse',
        'bareamp' => 'http://www.example.net/wiki?title=$1&command=browse',
        'utf8' => 'http://www.example.net/wiki?$(1:utf8)',
        'euc' => 'http://www.example.net/wiki?$(1:euc)',
        'jis' => 'http://www.example.net/wiki?$(1:jis)',
        'sjis' => 'http://www.example.net/wiki?$(1:sjis)',
    }, "$it should reload page->source";

}


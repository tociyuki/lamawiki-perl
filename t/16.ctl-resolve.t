use strict;
use warnings;
use Lamawiki;
use Lamawiki::Page;
use Lamawiki::Liq;
use Lamawiki::Controller;
use Test::More;
use lib qw(./t/lib);
use Lamawikix::Testutil qw(split_spec);

my $blocks = split_spec(qw(@== @--), do{ local $/ = undef; scalar <DATA> });

plan tests => 1 * @{$blocks};

my $wiki = Lamawiki->new({
    'config' => {
        'default.title' => 'Top',
        'all.title' => 'All',
        'recent.title' => 'Recent',
    },
    'page' => Lamawiki::Page->new,
});
my $view = Lamawiki::Liq->new->merge_filters(
    Lamawiki::Controller->filters($wiki, '/test'),
);

for my $test (@{$blocks}) {
    my $page = $wiki->page->new({
        'id' => 2, 'title' => 'Foo', 'rev' => 6, 'content' => $test->{'input'},
        'rel' => [
            $wiki->page->new({'id' => 3, 'title' => 'WikiEngine', 'rev' => 8}),
            $wiki->page->new({'id' => 4, 'title' => 'wiki name', 'rev' => 9}),
        ],
    });
    my $got = $view->call('RESOLVE', $page)->output;
    is $got, $test->{'expected'}, $test->{'name'};
};

__END__

@== wikiname
@-- input
<p>there are many <a href="0" title="WikiEngine">WikiEngine</a> in the world.
from page to page, page links with <a href="1" title="wiki name">wiki name</a>.</p>
@-- expected
<p>there are many <a href="/test/3" title="WikiEngine">WikiEngine</a> in the world.
from page to page, page links with <a href="/test/4" title="wiki name">wiki name</a>.</p>


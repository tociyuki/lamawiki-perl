use strict;
use warnings;
use Lamawiki;
use Lamawiki::Liq;
use Lamawiki::Controller;
use Test::More;

plan tests => 39;

{
    package Mock::Capability;
    sub allow {
        my($self, $wiki, $action, $orig, $page) = @_;
        return exists $wiki->generater->{$orig->title} ? q() : 1;
    }

    package Mock::Page;
    use base qw(Lamawiki::Page);
    
    sub see_title {
        my($self, $wiki, $q) = @_;
        $q = $self->is_title($q) ? $q : $wiki->default_title;
        return $self->{'.see_title'}{$q};
    }
}

my $wiki = Lamawiki->new({
    'config' => {
        'default.title' => 'Top',
        'interwiki.title' => 'InterWikiName',
        'all.title' => 'All',
        'recent.title' => 'Recent',
        'staticlocation' => '/static',
    },
    'capability' => (bless {}, 'Mock::Capability'),
    'page' => Mock::Page->new({
        '.see_title' => {
            'Top' => Mock::Page->new({'id' => 1, 'title' => 'Top', 'rev' => 1}),
            'All' => Mock::Page->new({'id' => 2, 'title' => 'All', 'rev' => 0}),
            'Recent' => Mock::Page->new({'id' => 3, 'title' => 'Recent', 'rev' => 0}),
            'Foo' => Mock::Page->new({'id' => 4, 'title' => 'Foo', 'rev' => 2}),
            'Bar' => Mock::Page->new({'id' => undef, 'title' => 'Bar', 'rev' => 0}),
        },
    }),
});
my $liq = Lamawiki::Liq->new;

{
    my $it = $liq->merge_filters(
        Lamawiki::Controller->new->filters($wiki, ''),
    );

    is $it->call('STATIC'), '/static',
        'it should locate static "/static".';

    is $it->call('SCRIPT'), '',
        'it should locate script "" base.';

    is $it->call('SIGNIN'), '/signin',
        'it should locate signin "/signin".';

    is $it->call('SIGNOUT'), '/signout',
        'it should locate script "/signout".';

    is $it->call('REMOTE', 'alice'), '/?remote=alice',
        'it should locate script "/?remote=alice".';

    is $it->call('LOCATION', $wiki->page->see_title($wiki, 'Foo')), '/4',
        'it should locate script "" and title "Foo".';

    is $it->call('LOCATION', $wiki->page->see_title($wiki, 'Bar')), '/?Bar',
        'it should locate script "" and title "Bar".';

    is $it->call('REVISION', $wiki->page->new({'id' => 4, 'title' => 'Foo', 'rev' => 7})),
        '/4/7',
        'it should locate script "" and id 4 title "Foo" revision 7.';

    is $it->call('DEFAULT')->title, $wiki->default_title,
        'its DEFAULT title should be "DEFAULT_TITLE".';

    is $it->call('ALL')->title, $wiki->all_title,
        'its ALL title should be "ALL_TITLE".';

    is $it->call('RECENT')->title, $wiki->recent_title,
        'its RECENT title should be "RECENT_TITLE".';

    is $it->execute('{{DEFAULT LOCATION}}',{}), '/1',
        'its {{DEFAULT LOCATION}} should be "/1".';

    is $it->execute('{{ALL LOCATION}}',{}), '/2',
        'its {{ALL LOCATION}} should be "/2".';

    is $it->execute('{{RECENT LOCATION}}',{}), '/3',
        'its {{RECENT LOCATION}} should be "/3".';
}

{
    my $it = $liq->merge_filters(
        Lamawiki::Controller->new->filters($wiki, '/wiki.cgi'),
    );

    is $it->call('STATIC'), '/static',
        'it should locate static "/static".';

    is $it->call('SCRIPT'), '/wiki.cgi',
        'it should locate script "/wiki.cgi" base.';

    is $it->call('SIGNIN'), '/wiki.cgi/signin',
        'it should locate signin "/wiki.cgi/signin".';

    is $it->call('SIGNOUT'), '/wiki.cgi/signout',
        'it should locate script "/wiki.cgi/signout".';

    is $it->call('REMOTE', 'alice'), '/wiki.cgi/?remote=alice',
        'it should locate script "/wiki.cgi/?remote=alice".';

    is $it->call('LOCATION', $wiki->page->see_title($wiki, 'Foo')), '/wiki.cgi/4',
        'it should locate script "/wiki.cgi" and title "Foo".';

    is $it->call('REVISION', $wiki->page->new({'id' => 4, 'title' => 'Foo', 'rev' => 7})),
       '/wiki.cgi/4/7',
        'it should locate script "/wiki.cgi" and id 4 title "Foo" revision 7.';

    is $it->execute('{{DEFAULT LOCATION}}',{}), '/wiki.cgi/1',
        'its {{DEFAULT LOCATION}} should be "/wiki.cgi/1".';

    is $it->execute('{{ALL LOCATION}}',{}), '/wiki.cgi/2',
        'its {{ALL LOCATION}} should be "/wiki.cgi/2".';

    is $it->execute('{{RECENT LOCATION}}',{}), '/wiki.cgi/3',
        'its {{RECENT LOCATION}} should be "/wiki.cgi/3".';
}

{
    my $it = $liq->merge_filters(
        Lamawiki::Controller->new->filters($wiki, ''),
    );

    ok $it->call('EDIT?', $wiki->page->see_title($wiki, 'Top')),
        'it should edit "Top".';

    ok ! $it->call('EDIT?', $wiki->page->see_title($wiki, 'All')),
        'it should not edit "All".';

    ok ! $it->call('EDIT?', $wiki->page->see_title($wiki, 'Recent')),
        'it should not edit "Recent".';

    ok $it->call('EDIT?', $wiki->page->see_title($wiki, 'Foo')),
        'it should edit "Foo".';

    ok $it->call('EDIT?', $wiki->page->see_title($wiki, 'Bar')),
        'it should edit "Bar".';
}

{
    my $it = $liq->merge_filters(
        Lamawiki::Controller->new->filters($wiki, ''),
    );

    ok $it->call('INSERT?', $wiki->page->see_title($wiki, 'Top')),
        'it should insert "Top".';

    ok ! $it->call('INSERT?', $wiki->page->see_title($wiki, 'All')),
        'it should not insert "All".';

    ok ! $it->call('INSERT?', $wiki->page->see_title($wiki, 'Recent')),
        'it should not insert "Recent".';

    ok $it->call('INSERT?', $wiki->page->see_title($wiki, 'Foo')),
        'it should edit "Foo".';

    ok $it->call('INSERT?', $wiki->page->see_title($wiki, 'Bar')),
        'it should edit "Bar".';
}

{
    my $it = $liq->merge_filters(
        Lamawiki::Controller->new->filters($wiki, ''),
    );

    ok $it->call('HISTORY?', $wiki->page->see_title($wiki, 'Top')),
        'it should have history "Top".';

    ok ! $it->call('HISTORY?', $wiki->page->see_title($wiki, 'All')),
        'it should not have history "All".';

    ok ! $it->call('HISTORY?', $wiki->page->see_title($wiki, 'Recent')),
        'it should not have history "Recent".';

    ok $it->call('HISTORY?', $wiki->page->see_title($wiki, 'Foo')),
        'it should have history "Foo".';

    ok ! $it->call('HISTORY?', $wiki->page->see_title($wiki, 'Bar')),
        'it should not have history "Bar".';
}


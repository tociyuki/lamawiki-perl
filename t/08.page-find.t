use strict;
use warnings;
use File::Spec;
use Test::More;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Page;
use lib qw(./t/lib);
use Lamawikix::Testutil qw(dbx_fixup_data make_titles_sources fakeyaml_loadfile);

plan tests => 33;

my $srcname = File::Spec->catfile(qw[. t data find.yml]);
my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

my $data = fakeyaml_loadfile($srcname);
my($titles, $sources) = make_titles_sources($data, Lamawiki::Page->new);

my $wiki = Lamawiki->new({
    'config' => {
        'default.title' => 'Top',
        'interwiki.title' => 'InterWikiName',
        'all.title' => 'All',
        'recent.title' => 'Recent',
        'recent.limit' => 20,
    },
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($db) = @_;
        $db->fixup($db->module->{'create_table'});
        dbx_fixup_data($db, $data);
    }),
    'page' => Lamawiki::Page->new,
});

{
    is_deeply [$wiki->page->find($wiki, 'id', {'id' => 1})],
              [{'page' => $titles->{1}}],
        'it should find page /1.';

    is_deeply [$wiki->page->find($wiki, 'title', {'title' => 'Top'})],
              [{'page' => $titles->{1}}],
        'it should find page /?Top.';

    is_deeply [$wiki->page->find($wiki, 'id', {'id' => 6})],
              [{'page' => $titles->{6}}],
        'it should find page /6.';

    is_deeply [$wiki->page->find($wiki, 'title', {'title' => 'Foo'})],
              [{'page' => $titles->{6}}],
        'it should find page /?Foo.';
}

{
    # {id: 7, title: Bar, history: [33, 26, 17, 10, 5]}
    my $bar0 = $wiki->page->new({
        'rev' => 0, 'id' => 7, 'title' => $titles->{7}->title,
        'summary' => $titles->{7}->summary, 'content' => '',
        'posted' => undef, 'remote' => undef, 'source' => '',
    });

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 33})],
              [{'page' => $wiki->page->new({%{$sources->{33}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{26}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page id_rev 33:7:Bar for /7/33.";

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 20})],
              [{'page' => $wiki->page->new({%{$sources->{17}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{10}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page id_rev 17:7:Bar for /7/20.";

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 17})],
              [{'page' => $wiki->page->new({%{$sources->{17}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{10}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page id_rev 17:7:Bar for /7/17.";

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 9})],
              [{'page' => $wiki->page->new({%{$sources->{5}}, 'content' => ''}),
                'prev' => $bar0,
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page id_rev 5:7:Bar for /7/9.";

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 5})],
              [{'page' => $wiki->page->new({%{$sources->{5}}, 'content' => ''}),
                'prev' => $bar0,
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page id_rev 5:7:Bar for /7/5.";

    is_deeply [$wiki->page->find($wiki, 'id_rev', {'id' => 7, 'rev' => 4})],
              [{'page' => $bar0, 'prev' => undef, 'latest' => $bar0}],
        "it should find page id_rev 0:7:Bar for /7/4.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 33})],
              [{'page' => $wiki->page->new({%{$sources->{33}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{26}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page title_rev 33:7:Bar for /?Bar&r=33.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 20})],
              [{'page' => $wiki->page->new({%{$sources->{17}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{10}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should select page title_rev 17:7:Bar for /?Bar&r=20.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 17})],
              [{'page' => $wiki->page->new({%{$sources->{17}}, 'content' => ''}),
                'prev' => $wiki->page->new({%{$sources->{10}}, 'content' => ''}),
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page title_rev 17:7:Bar for /?Bar&r=17.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 9})],
              [{'page' => $wiki->page->new({%{$sources->{5}}, 'content' => ''}),
                'prev' => $bar0,
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page title_rev 5:7:Bar for /?Bar&r=9.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 5})],
              [{'page' => $wiki->page->new({%{$sources->{5}}, 'content' => ''}),
                'prev' => $bar0,
                'latest' => $wiki->page->new({%{$sources->{33}}, 'content' => ''})}],
        "it should find page title_rev 5:7:Bar for /?Bar&r=5.";

    is_deeply [$wiki->page->find($wiki, 'title_rev', {'title' => 'Bar', 'rev' => 4})],
              [{'page' => $bar0, 'prev' => undef, 'latest' => $bar0}],
        "it should find page title_rev 0:7:Bar for /?Bar&r=4.";
}

{
    my $rel = [
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => ''}) }
        grep { $_->id == 6 }
        values %{$sources},
    ];
    my $page = $wiki->page->new({%{$rel->[0]}, 'rel' => $rel});

    is_deeply $wiki->page->findall($wiki, 'id_history', {'id' => 6}), $rel,
        'it should select /6/history.';

    is_deeply $wiki->page->findall($wiki, 'title_history', {'title' => 'Foo'}), $rel,
        'it should select /history?Foo.';

    is_deeply [$wiki->page->find_history($wiki, 'id', {'id' => 6})],
              [{'page' => $page}],
        'it should find page /6/history.';

    is_deeply [$wiki->page->find_history($wiki, 'title', {'title' => 'Foo'})],
              [{'page' => $page}],
        'it should find page /history?Foo.';
}

{
    my $rel = [
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => ''}) }
        grep { $_->id == 7 }
        values %{$sources},
    ];
    my $page = $wiki->page->new({%{$rel->[0]}, 'rel' => $rel});

    is_deeply $wiki->page->findall($wiki, 'id_history', {'id' => 7}), $rel,
        'it should select /7/history.';

    is_deeply $wiki->page->findall($wiki, 'title_history', {'title' => 'Bar'}), $rel,
        'it should select /history?Bar.';

    is_deeply [$wiki->page->find_history($wiki, 'id', {'id' => 7})],
              [{'page' => $page}],
        'it should find page /7/history.';

    is_deeply [$wiki->page->find_history($wiki, 'title', {'title' => 'Bar'})],
              [{'page' => $page}],
        'it should find page /history?Bar.';
}

{
    my $all_id = 3;
    my $all_title = 'All';
    my $latest = [
        sort { $a->title cmp $b->title }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $titles->{$_->id}->rev == $_->rev }
        values %{$sources},
    ];

    is_deeply $wiki->page->findall($wiki, 'all', {}), $latest,
        'it should select /?All.';

    is_deeply [$wiki->page->find($wiki, 'id', {'id' => $all_id})],
              [{'page' => $wiki->page->new({
                    'rev' => $wiki->page->MAXREV + 1,
                    'title' => $all_title, 'id' => $all_id,
                    'posted' => $wiki->now, 'remote' => undef,
                    'summary' => q(), 'content' => q(), 'source' => q(),
                    'rel' => $latest, 'resolver' => 'all'})}],
        'it should find page /:all_id.';

    is_deeply [$wiki->page->find($wiki, 'title', {'title' => $all_title})],
              [{'page' => $wiki->page->new({
                    'rev' => $wiki->page->MAXREV + 1,
                    'title' => $all_title, 'id' => $all_id,
                    'posted' => $wiki->now, 'remote' => undef,
                    'summary' => q(), 'content' => q(), 'source' => q(),
                    'rel' => $latest, 'resolver' => 'all'})}],
        'it should find page /?All.';
}

{
    my $recent_id = 4;
    my $recent_title = 'Recent';
    my $recent = [
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $titles->{$_->id}->rev == $_->rev }
        values %{$sources},
    ];
    splice @{$recent}, $wiki->config->{'recent.limit'};

    is_deeply $wiki->page->findall($wiki, 'recent', {}), $recent,
        'it should select /?Recent.';

    is_deeply [$wiki->page->find($wiki, 'id', {'id' => $recent_id})],
              [{'page' => $wiki->page->new({
                    'rev' => $wiki->page->MAXREV + 1,
                    'title' => $recent_title, 'id' => $recent_id,
                    'posted' => $wiki->now, 'remote' => undef,
                    'summary' => q(), 'content' => q(), 'source' => q(),
                    'rel' => $recent, 'resolver' => 'recent'})}],
        'it should find page /:recent_id.';

    is_deeply [$wiki->page->find($wiki, 'title', {'title' => $recent_title})],
              [{'page' => $wiki->page->new({
                    'rev' => $wiki->page->MAXREV + 1,
                    'title' => $recent_title, 'id' => $recent_id,
                    'posted' => $wiki->now, 'remote' => undef,
                    'summary' => q(), 'content' => q(), 'source' => q(),
                    'rel' => $recent, 'resolver' => 'recent'})}],
        'it should find page /?Recent.';
}

{
    my $alice = [
        sort { -($a->rev <=> $b->rev) }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $_->remote eq 'alice' }
        values %{$sources},
    ];
    splice @{$alice}, $wiki->config->{'recent.limit'};

    is_deeply $wiki->page->findall($wiki, 'remote', {'remote' => 'alice'}), $alice,
        'it should select /?remote=alice.';

    is_deeply [$wiki->page->find_remote($wiki, 'alice')],
              [{'page' => $wiki->page->new({
                    'rev' => $wiki->page->MAXREV + 1,
                    'title' => '', 'id' => undef,
                    'posted' => $wiki->now, 'remote' => 'alice',
                    'rel' => $alice})}],
        'it should find page /?remote=alice.';
}

{
    my $index_b = [
        sort { $a->title cmp $b->title }
        map { $_->new({%{$_}, 'source' => '', 'content' => ''}) }
        grep { $_->title =~ m/\AB/msx && $titles->{$_->id}->rev == $_->rev }
        values %{$sources},
    ];

    is_deeply $wiki->page->findall($wiki, 'index', {'prefix' => 'B'}), $index_b,
        'it should select /index?prefix=B.';
}


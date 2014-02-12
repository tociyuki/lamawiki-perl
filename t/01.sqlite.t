use strict;
use warnings;
use Encode;
use File::Spec;
use Test::More tests => 87;
use Lamawiki::Sqlite;

my $datadir = File::Spec->catdir(qw[. data]);
my $dbname = File::Spec->catfile(qw[. data test.db]);
-d $datadir or mkdir $datadir;
-e $dbname and unlink $dbname;

my $dbx = Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
    my($self) = @_;
    $self->fixup($self->module->{'create_table'});
});

{
    my $it = -e $dbname;
    
    ok $it, 'it should create database file.';

    diag join q( ), map {
        s/"main"[.]"(.*?)"/$1/ && m/^sqlite_/ ? () : $_
    } $dbx->dbh->tables(undef, undef, '%', 'TABLE');
}

{
    # procedures of titles,  sources, and relates

    is $dbx->call('titles.insert', {'title' => 'Top'}), 1,
        'it should call titles.insert 0:1:Top.';

    is $dbx->last_insert_id('titles.primary_key'), 1,
        'it should look last insert titles.primary_key 0:1:Top.';

    is $dbx->call('titles.insert', {'title' => 'InterWikiName'}), 1,
        'it should call titles.insert 0:2:InterWikiName.';

    is $dbx->last_insert_id('titles.primary_key'), 2,
        'it should look last insert titles.primary_key 0:2:InterWikiName.';

    is $dbx->call('titles.insert', {'title' => 'All'}), 1,
        'it should call titles.insert 0:3:All.';

    is $dbx->last_insert_id('titles.primary_key'), 3,
        'it should look last insert titles.primary_key 0:3:All.';

    is $dbx->call('titles.insert', {'title' => 'Recent'}), 1,
        'it should call titles.insert 0:4:Recent.';

    is $dbx->last_insert_id('titles.primary_key'), 4,
        'it should look last insert titles.primary_key 0:4:Recent.';

    is $dbx->call('titles.insert', {'title' => 'foo'}), 1,
        'it should call titles.insert 0:5:foo.';

    is $dbx->last_insert_id('titles.primary_key'), 5,
        'it should look last insert titles.primary_key 0:5:foo.';

    is $dbx->call('titles.update',
        {'id' => 5, 'rev' => 1, 'summary' => 'foo 1', 'content' => 'foo 1'}), 1,
        'it should call titles.update 1:5:foo.';

    is_deeply $dbx->call('titles.select_id', {'id' => 5}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 1}],
        'it should call titles.select_id 1:5:foo';

    is_deeply $dbx->call('titles.select_title', {'title' => 'foo'}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 1}],
        'it should call titles.select_title 1:5:foo';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar1', 'rev' => 0}),
        {'id' => 6, 'title' => 'bar1', 'rev' => 0},
        'it should get or set titles title 0:6:bar1.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 6, 'n' => 1}), 1,
        'it should call relates.insert *:5:foo[0] *:6:bar1.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar2', 'rev' => 0}),
        {'id' => 7, 'title' => 'bar2', 'rev' => 0},
        'it should get or set titles title 0:7:bar2.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 7, 'n' => 2}), 1,
        'it should call relates.insert *:5:foo[1] *:7:bar2.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar3', 'rev' => 0}),
        {'id' => 8, 'title' => 'bar3', 'rev' => 0},
        'it should get or set titles title 0:8:bar3.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 8, 'n' => 3}), 1,
        'it should call relates.insert *:5:foo[2] *:8:bar3.';

    is_deeply $dbx->call('titles.select_id_rel', {'id' => 5}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 0},
         {'id' => 7, 'title' => 'bar2', 'rev' => 0},
         {'id' => 8, 'title' => 'bar3', 'rev' => 0}],
        'it should call titles.select_id_rel *:5:foo.';

    is $dbx->call('relates.delete', {'id' => 5}), 3,
        'it should call relates.delete *:5:foo.';

    is_deeply $dbx->call('titles.select_id_rel', {'id' => 5}), [],
        'it should call titles.select_id_rel *:5:foo again.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar1', 'rev' => 0}),
        {'id' => 6, 'title' => 'bar1', 'rev' => 0},
        'it should get or set titles title 0:6:bar1 again.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 6, 'n' => 1}), 1,
        'it should call relates.insert *:5:foo[0] *:6:bar1 again.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar2', 'rev' => 0}),
        {'id' => 7, 'title' => 'bar2', 'rev' => 0},
        'it should get or set titles title 0:7:bar2 again.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 7, 'n' => 2}), 1,
        'it should call relates.insert *:5:foo[1] *:7:bar2 again.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar3', 'rev' => 0}),
        {'id' => 8, 'title' => 'bar3', 'rev' => 0},
        'it should get or set titles title 0:8:bar3 again.';

    is $dbx->call('relates.insert', {'id' => 5, 'to_id' => 8, 'n' => 3}), 1,
        'it should call relates.insert *:5:foo[2] *:8:bar3 again.';

    is_deeply $dbx->call('titles.select_id_rel', {'id' => 5}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 0},
         {'id' => 7, 'title' => 'bar2', 'rev' => 0},
         {'id' => 8, 'title' => 'bar3', 'rev' => 0}],
        'it should call titles.select_id_rel *:5:foo again.';

    my $time0 = time - 1000;
    is $dbx->call('sources.insert',
        {'id' => 5, 'posted' => $time0, 'remote' => '127.0.0.1', 'source' => 'foo 1'}),
        1,
        'it should call sources.insert 1:5:foo.';

    is $dbx->last_insert_id('sources.primary_key'), 1,
        'it should look last insert sources.primary_key 1:5:foo.';

    is $dbx->call('sources.insert',
        {'id' => 5, 'posted' => $time0 + 10, 'remote' => '127.0.0.1', 'source' => 'foo 2'}),
        1,
        'it should call sources.insert 2:5:foo.';

    is $dbx->last_insert_id('sources.primary_key'), 2,
        'it should look last insert sources.primary_key 2:5:foo.';

    is $dbx->call('titles.update',
        {'id' => 5, 'rev' => 2, 'summary' => 'foo 2', 'content' => 'foo 2'}), 1,
        'it should call titles.update 2:5:foo.';

    is_deeply $dbx->call('pages.select_id', {'id' => 5}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => 'foo 2', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => 'foo 2'}],
        'it should call pages.select_id 2:5:foo.';

    is_deeply $dbx->call('pages.select_id_rev', {'id' => 5, 'rev' => 2}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => 'foo 2'}],
        'it should call pages.select_id_rev 2:5:foo.';

    is_deeply $dbx->call('pages.select_id_rev', {'id' => 5, 'rev' => 1}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 1, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0, 'remote' => '127.0.0.1',
          'source' => 'foo 1'}],
        'it should call pages.select_id_rev 1:5:foo.';

    is_deeply $dbx->call('pages.select_id_rev', {'id' => 5, 'rev' => 0}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 0, 'summary' => 'foo 2',
          'content' => '', 'posted' => undef, 'remote' => undef,
          'source' => ''}],
        'it should call pages.select_id_rev 0:5:foo.';

    is_deeply $dbx->call('pages.select_id_history', {'id' => 5}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 1, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_id_history *:5:foo.';

    is_deeply $dbx->call('pages.select_title', {'title' => 'foo'}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => 'foo 2', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => 'foo 2'}],
        'it should call pages.select_title 2:5:foo.';

    is_deeply $dbx->call('pages.select_title_rev', {'title' => 'foo', 'rev' => 2}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => 'foo 2'}],
        'it should call pages.select_title_rev 2:5:foo.';

    is_deeply $dbx->call('pages.select_title_rev', {'title' => 'foo', 'rev' => 1}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 1, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0, 'remote' => '127.0.0.1',
          'source' => 'foo 1'}],
        'it should call pages.select_title_rev 1:5:foo.';

    is_deeply $dbx->call('pages.select_title_rev', {'title' => 'foo', 'rev' => 0}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 0, 'summary' => 'foo 2',
          'content' => '', 'posted' => undef, 'remote' => undef,
          'source' => ''}],
        'it should call pages.select_title_rev 0:5:foo.';

    is_deeply $dbx->call('pages.select_title_history', {'title' => 'foo'}),
        [{'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 1, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_title_history *:5:foo.';

    is_deeply $dbx->call('pages.select_id', {'id' => 7}),
        [{'id' => 7, 'title' => 'bar2', 'rev' => 0, 'summary' => '',
          'content' => '', 'posted' => undef, 'remote' => undef,
          'source' => ''}],
        'it should call pages.select_id 0:7:bar2.';

    is $dbx->call('sources.insert',
        {'id' => 7, 'posted' => $time0 + 20, 'remote' => '127.0.0.1', 'source' => 'bar2 3'}),
        1,
        'it should call sources.insert 3:7:bar2.';

    is $dbx->last_insert_id('sources.primary_key'), 3,
        'it should look last insert sources.primary_key 3:7:bar2.';

    ok $dbx->call('relates.delete', {'id' => 7}),
        'it should call relates.delete 3:7:bar2.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar1', 'rev' => 0}),
        {'id' => 6, 'title' => 'bar1', 'rev' => 0},
        'it should get or set titles title 0:6:bar1.';

    is $dbx->call('relates.insert', {'id' => 7, 'to_id' => 6, 'n' => 1}), 1,
        'it should call relates.insert *:7:bar2[0] *:6:bar1.';

    is_deeply $dbx->get_or_set('titles', 'title', {'title' => 'bar3', 'rev' => 0}),
        {'id' => 8, 'title' => 'bar3', 'rev' => 0},
        'it should get or set titles title 0:8:bar3.';

    is $dbx->call('relates.insert', {'id' => 7, 'to_id' => 8, 'n' => 2}), 1,
        'it should call relates.insert *:7:bar2[1] *:6:bar1.';

    is_deeply $dbx->call('titles.select_id_rel', {'id' => 7}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 0},
         {'id' => 8, 'title' => 'bar3', 'rev' => 0}],
        'it should call titles.select_id_rel *:7:bar2.';

    is $dbx->call('titles.update',
        {'id' => 7, 'rev' => 3, 'summary' => 'bar2 3', 'content' => 'bar2 3'}), 1,
        'it should call titles.update 3:7:bar2.';

    is $dbx->call('sources.insert',
        {'id' => 6, 'posted' => $time0 + 30, 'remote' => '127.0.0.1', 'source' => 'bar1 4'}),
        1,
        'it should call sources.insert 4:6:bar1.';

    is $dbx->last_insert_id('sources.primary_key'), 4,
        'it should look last insert sources.primary_key 4:6:bar1.';

    is $dbx->call('titles.update',
        {'id' => 6, 'rev' => 4, 'summary' => 'bar1 4', 'content' => 'bar1 4'}), 1,
        'it should call titles.update 4:6:bar1.';

    is_deeply $dbx->call('pages.select_id_ref', {'to_id' => 6}),
        [{'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_id_ref *:6:bar1.';

    is_deeply $dbx->call('pages.select_title_ref', {'to_title' => 'bar1'}),
        [{'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_id_ref *:6:bar1.';

    is_deeply $dbx->call('pages.select_feed', {'-offset' => 0, '-limit' => 10}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => 'bar1 4', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => 'bar1 4'},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => 'bar2 3', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => 'bar2 3'},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => 'foo 2', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => 'foo 2'}],
        'it should call pages.select_feed.';

    is_deeply $dbx->call('pages.select_all', {}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => '', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_all.';

    is_deeply $dbx->call('pages.select_recent', {'-limit' => 10}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => '', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_recent.';

    is_deeply $dbx->call('pages.select_remote',
        {'remote' => '127.0.0.1', '-offset' => 0, '-limit' => 10}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => '', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 1, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_remote.';

    is_deeply $dbx->call('pages.select_index', {'prefix' => 'ba%'}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => '', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_index ba%.';

    is $dbx->call('sources.delete', {'rev' => 1}), 1,
        'it should call sources.delete 1:5:foo.';

    is_deeply $dbx->call('pages.select_remote',
        {'remote' => '127.0.0.1', '-offset' => 0, '-limit' => 10}),
        [{'id' => 6, 'title' => 'bar1', 'rev' => 4, 'summary' => 'bar1 4',
          'content' => '', 'posted' => $time0 + 30, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 7, 'title' => 'bar2', 'rev' => 3, 'summary' => 'bar2 3',
          'content' => '', 'posted' => $time0 + 20, 'remote' => '127.0.0.1',
          'source' => ''},
         {'id' => 5, 'title' => 'foo', 'rev' => 2, 'summary' => 'foo 2',
          'content' => '', 'posted' => $time0 + 10, 'remote' => '127.0.0.1',
          'source' => ''}],
        'it should call pages.select_remote.';
}

{
    # procedures cookies

    my $time0 = time;

    is $dbx->call('cookies.insert',
        {'sesskey' => 'cookie1', 'name' => 'test', 'token' => 'token1',
         'posted' => $time0 - 5000, 'remote' => '127.0.0.1', 'expires' => $time0 + 1000}),
        1,
        'it should call cookies.insert cookie1.';

    is_deeply $dbx->call('cookies.select_auth',
            {'sesskey' => 'cookie1', 'expires' => $time0}),
        [{'sesskey' => 'cookie1', 'name' => 'test', 'token' => 'token1',
         'posted' => $time0 - 5000, 'remote' => '127.0.0.1'}],
        'it should call cookies.select_auth cookie1.';

    is $dbx->call('cookies.update', {'sesskey' => 'cookie1', 'expires' => $time0 - 10}),1,
        'it should call cookies.update cookie1.';

    is_deeply $dbx->call('cookies.select_auth', {'sesskey' => 'cookie1'}), [],
        'it should call cookies.select_auth cookie1 (expired).';

    is $dbx->call('cookies.insert',
        {'sesskey' => 'cookie2', 'name' => 'test', 'token' => 'token2',
         'posted' => $time0 - 4000, 'remote' => '127.0.0.1', 'expires' => $time0 + 1000}),
        1,
        'it should call cookies.insert cookie2.';

    is_deeply $dbx->call('cookies.select_latest', {'name' => 'test'}),
        [{'posted' => $time0 - 4000}],
        'it should call cookies.select_latest.';
}

{
    # procedures tbf

    is $dbx->call('tbf.insert', {'remote' => '198.0.1.2', 'credit' => 30000}), 1,
        'it should call tbf.insert 198.0.1.2.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.2'}),
        [{'remote' => '198.0.1.2', 'credit' => 30000}],
        'it should call tbf.select_remote 198.0.1.2.';

    is $dbx->call('tbf.update', {'remote' => '198.0.1.2', 'credit' => 20000}), 1,
        'it should call tbf.update 198.0.1.2.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.2'}),
        [{'remote' => '198.0.1.2', 'credit' => 20000}],
        'it should call tbf.select_remote 198.0.1.2.';

    is_deeply $dbx->replace('tbf', 'remote', {'remote' => '198.0.1.2'},
        sub{ +{'remote' => '198.0.1.2', 'credit' => 40000} }),
        {'remote' => '198.0.1.2', 'credit' => 40000},
        'it should replace tbf remote 198.0.1.2.';

    is_deeply $dbx->replace('tbf', 'remote', {'remote' => '198.0.1.3'},
        sub{ +{'remote' => '198.0.1.3', 'credit' => 50000} }),
        {'remote' => '198.0.1.3', 'credit' => 50000},
        'it should replace tbf remote 198.0.1.3.';

    is_deeply $dbx->replace('tbf', 'remote', {'remote' => '198.0.1.4'},
        sub{ +{'remote' => '198.0.1.4', 'credit' => 30000} }),
        {'remote' => '198.0.1.4', 'credit' => 30000},
        'it should replace tbf remote 198.0.1.4.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.2'}),
        [{'remote' => '198.0.1.2', 'credit' => 40000}],
        'it should call tbf.select_remote 198.0.1.2.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.3'}),
        [{'remote' => '198.0.1.3', 'credit' => 50000}],
        'it should call tbf.select_remote 198.0.1.3.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.4'}),
        [{'remote' => '198.0.1.4', 'credit' => 30000}],
        'it should call tbf.select_remote 198.0.1.4.';

    is $dbx->call('tbf.delete', {'credit' => 45000}), 2,
        'it should call tbf.delete.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.2'}), [],
        'it should call tbf.select_remote 198.0.1.2 deleted.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.3'}),
        [{'remote' => '198.0.1.3', 'credit' => 50000}],
        'it should call tbf.select_remote 198.0.1.3.';

    is_deeply $dbx->call('tbf.select_remote', {'remote' => '198.0.1.4'}), [],
        'it should call tbf.select_remote 198.0.1.4 deleted.';
}


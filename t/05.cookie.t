use strict;
use warnings;
use File::Spec;
use Lamawiki;
use Lamawiki::Sqlite;
use Lamawiki::Htpasswd;
use Test::More tests => 31;

BEGIN { use_ok 'Lamawiki::Cookie' }

my $alice_pass = 'aEdgakjt9kjer';
my $htpasswdfile = File::Spec->catfile(qw[. t data htpasswd]);
my $dbname = File::Spec->catfile(qw[. data test.db]);

{
    my $wiki = Lamawiki->new({
        'session' => Lamawiki::Cookie->new({'lifetime' => 8*3600}),
        'page' => (bless {}, 'Mock::Page'),
    });
    can_ok $wiki->session, qw(
        new sesskey name token posted remote expires lifetime
        start_session find_authenticate signin signout long_silence
    );

    my $it = 'its signin';

    my $time0 = $wiki->now;
    my $user = $wiki->session->start_session({
        'name' => 'foo', 'posted' => $time0, 'remote' => '127.0.0.1',
    }, $time0 + 12 * 3600);

    is $user->name, 'foo',
        qq($it should has injected value of `foo`.);
    is_deeply $user->posted, $time0,
        qq($it should has injected value of `posted`.);
    is $user->remote, '127.0.0.1',
        qq($it should has injected value of `remote`.);
    is_deeply $user->expires, $time0 + 12 * 3600,
        qq($it should has injected value of `expires`.);
    ok $user->sesskey,
        "$it should generate sesskey";
    ok $user->token,
        "$it should generate token";
    is $user->lifetime, 8*3600,
        "$it should has injected value of `lifetime`.";
}

-e $dbname and unlink $dbname;
my $wiki = Lamawiki->new({
    'db' => Lamawiki::Sqlite->connect("dbi:SQLite:dbname=$dbname", q(), q(), sub{
        my($self) = @_;
        $self->fixup($self->module->{'create_table'});
    }),
    'auth' => Lamawiki::Htpasswd->new({'path' => $htpasswdfile}),
    'session' => Lamawiki::Cookie->new({'lifetime' => 12*3600}),
    'config' => {},
    'page' => (bless {}, 'Mock::Page'),
});
my($user1, $user2);

{
    ok ! $wiki->find_authenticate('ejtaetjanr3dete')->user,
        'it should fail authenticate.';

    my $wiki1 = $wiki->new($wiki);
    ok $wiki1->session->signin($wiki1, {
        'name' => 'alice', 'password' => $alice_pass,
        'remote' => '127.0.0.1', 'posted' => scalar localtime,
    }), 'it should signin alice';

    $user1 = $wiki1->user;
    ok $user1,
        'it should set signin user.';
}

{
    my $cap0 = $wiki->capability;
    my $wiki2 = $wiki->find_authenticate($user1->sesskey);
    $user2 = $wiki2->user;
    my $cap1 = $wiki2->capability;

    ok $user2,
        'it should success authenticate with user1 sesskey';
    is ref $cap0, ref $cap1,
        'it should inherit capability.';
    $cap1->{'.test'} = 'test';
    ok ! exists $cap0->{'.test'},
        'it should duplicate other object for the capability.';
    is_deeply +{
        'name' => $user1->name,
        'sesskey' => $user1->sesskey, 'token' => $user1->token,
    }, +{
        'name' => $user2->name,
        'sesskey' => $user2->sesskey, 'token' => $user2->token,
    }, 'it should reload user.';
}

{
    my $wiki2 = $wiki->find_authenticate($user1->sesskey);
    $user2 = $wiki2->user;
    ok $user2,
        'it should success authenticate again';
    is_deeply +{
        'name' => $user1->name,
        'sesskey' => $user1->sesskey, 'token' => $user1->token,
    }, +{
        'name' => $user2->name,
        'sesskey' => $user2->sesskey, 'token' => $user2->token,
    }, 'it should reload user again';
}

{
    my $wiki2 = $wiki->find_authenticate($user1->sesskey);
    ok $wiki2->user,
        'it should success authenticate again';
    ok $wiki2->user->signout($wiki2),
        'it should signout';
}

{
    my $wiki2 = $wiki->find_authenticate($user1->sesskey);

    ok ! $wiki2->user,
        'it should fail authenticate';
    ok $wiki2->session->signin($wiki2, {
        'name' => 'alice', 'password' => $alice_pass,
        'remote' => '127.0.0.1', 'posted' => scalar localtime,
    }), 'it should signin again';

    $user2 = $wiki2->user;
    is $user2->name, 'alice',
        'it should signin alice again';
    ok $user2->sesskey && $user2->sesskey ne $user1->sesskey,
        'it should change sesskey to signin';
    ok $user2->token && $user2->token ne $user1->token,
        'it should change token to signin';
}

{
    ok ! $wiki->find_authenticate($user1->sesskey)->user,
        'it should fail authenticate by signout sesskey';
}

{
    my $wiki2 = $wiki->find_authenticate($user2->sesskey);
    $user2 = $wiki2->user;
    ok $user2,
        'it should success authenticate by new sesskey';
    ok $wiki2->user->signout($wiki2),
        'it should success signout';
}

{
    my $user3 = $wiki->session->start_session({
        'name' => 'user3',
        'posted' => $wiki->now - 15*24*3600,
        'remote' => '127.0.0.1',
    }, $wiki->now - 15*24*3600);

    $wiki->db->call('cookies.insert', $user3);

    my $user4 = $wiki->session->start_session({
        'name' => 'user4',
        'posted' => $wiki->now - 13*24*3600,
        'remote' => '127.0.0.1',
    }, $wiki->now - 13*24*3600);

    $wiki->db->call('cookies.insert', $user4);

    ok $wiki->session->long_silence(
        $wiki, $wiki->now - 14*24*3600, 'user3'),
        'user3 should be long silence.';

    ok ! $wiki->session->long_silence(
        $wiki, $wiki->now - 14*24*3600, 'user4'),
        'user4 should not be long silence.';

    ok ! $wiki->session->long_silence(
        $wiki, $wiki->now - 14*24*3600, 'user3', 'user4'),
        'user3 or user4 should not be long silence.';
}


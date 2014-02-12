use strict;
use warnings;
use File::Spec;
use Test::More tests => 8;

BEGIN { use_ok 'Lamawiki::Htpasswd' }

can_ok 'Lamawiki::Htpasswd', qw(new path check get crypt_md5);

my $htpasswdfile = File::Spec->catfile(qw[. t data htpasswd]);
my($alice_pass, $carol_pass) = ('aEdgakjt9kjer', 'i3.egw-teEKxPb8');

{
    my $got = Lamawiki::Htpasswd::crypt_md5($alice_pass, '$apr1$ni5p5OOQ$');
    is $got, '$apr1$ni5p5OOQ$jqcQhyYnbOwK7K5H7lJ7l1',
        'it should crypt md5 just same as the command htpasswd(1).';
}

{
    my $got = Lamawiki::Htpasswd::crypt_md5($carol_pass, '$apr1$KE92.sXq$');
    is $got, '$apr1$KE92.sXq$sEyAN23rFkqCaiAvsY0bN0',
        'it should crypt md5 just same as the command htpasswd(1) again.';
}

{
    
    my $auth = Lamawiki::Htpasswd->new({'path' => $htpasswdfile});

    is $auth->get('alice'), '$apr1$ni5p5OOQ$jqcQhyYnbOwK7K5H7lJ7l1',
        'it should get encryption of alice.';

    is $auth->get('carol'), '$apr1$KE92.sXq$sEyAN23rFkqCaiAvsY0bN0',
        'it should get encryption of carol.';

    ok ! ! $auth->check({'name' => 'alice', 'password' => $alice_pass}),
        'it should check password of alice.';

    ok ! ! $auth->check({'name' => 'carol', 'password' => $carol_pass}),
        'it should check password of carol.';
}


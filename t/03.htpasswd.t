use strict;
use warnings;
use File::Spec;
use Test::More tests => 16;

BEGIN { use_ok 'Lamawiki::Htpasswd' }

can_ok 'Lamawiki::Htpasswd', qw(new path check get crypt_pbkdf2 crypt_md5);

my $htpasswdfile = File::Spec->catfile(qw[. t data htpasswd]);
my($alice_pass, $carol_pass) = ('aEdgakjt9kjer', 'i3.egw-teEKxPb8');

{
    my $secret = Lamawiki::Htpasswd::crypt_pbkdf2($alice_pass, '$d8$10$fxHXoNbBMYEZYUzoRTJJej');
    is $secret, '$d8$10$fxHXoNbBMYEZYUzoRTJJej1Gar5ZVVsxHliffeZYudDgXWXKate6/.tC9q4e6tMdZyeqNA6eGqLuzNdI42caRd', 'it should generate secret pbkdf2.';

    my $got = Lamawiki::Htpasswd::crypt_pbkdf2($alice_pass, $secret);
    is $got, $secret, 'it should crypt pbkdf2.';
}

{
    my $secret = Lamawiki::Htpasswd::crypt_pbkdf2($carol_pass, '$d8$10$0mikJzi8T24vJm7bqS5XZi');
    is $secret, '$d8$10$0mikJzi8T24vJm7bqS5XZi9cEzgY6/yd3Jc32Cd.H6Cddw1LWOLR97NuJ9EGzFftMjk2bbvrtTNH4ApeWwDBIR', 'it should generate secret pbkdf2 again.';

    my $got = Lamawiki::Htpasswd::crypt_pbkdf2($carol_pass, $secret);
    is $got, $secret, 'it should crypt pbkdf2 again.';
}

{
    my $auth = Lamawiki::Htpasswd->new({'path' => $htpasswdfile});

    is $auth->get('aliced8'), '$d8$10$fxHXoNbBMYEZYUzoRTJJej1Gar5ZVVsxHliffeZYudDgXWXKate6/.tC9q4e6tMdZyeqNA6eGqLuzNdI42caRd',
        'it should get encryption of alice pbkdf2.';

    is $auth->get('carold8'), '$d8$10$0mikJzi8T24vJm7bqS5XZi9cEzgY6/yd3Jc32Cd.H6Cddw1LWOLR97NuJ9EGzFftMjk2bbvrtTNH4ApeWwDBIR',
        'it should get encryption of carol pbkdf2.';

    ok ! ! $auth->check({'name' => 'aliced8', 'password' => $alice_pass}),
        'it should check password of alice pbkdf2.';

    ok ! ! $auth->check({'name' => 'carold8', 'password' => $carol_pass}),
        'it should check password of carol pbkdf2.';
}

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

    is $auth->get('alicemd5'), '$apr1$ni5p5OOQ$jqcQhyYnbOwK7K5H7lJ7l1',
        'it should get encryption of alice md5.';

    is $auth->get('carolmd5'), '$apr1$KE92.sXq$sEyAN23rFkqCaiAvsY0bN0',
        'it should get encryption of carol md5.';

    ok ! ! $auth->check({'name' => 'alicemd5', 'password' => $alice_pass}),
        'it should check password of alice md5.';

    ok ! ! $auth->check({'name' => 'carolmd5', 'password' => $carol_pass}),
        'it should check password of carol md5.';
}


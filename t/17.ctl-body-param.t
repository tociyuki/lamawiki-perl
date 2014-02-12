use strict;
use warnings;
use Test::More;
use Lamawiki::Controller;
use lib qw(./t/lib);
use Lamawikix::Testutil qw(split_spec);

my $blocks = split_spec(qw(@== @--), do{ local $/ = undef; scalar <DATA> });

plan tests => 1 * @{$blocks};

for my $test (@{$blocks}) {
    my $env = eval $test->{'env'};
    my $postdata = $test->{'postdata'};
    chomp $postdata;
    $postdata .= "\n";
    $postdata =~ s/\n/\x0d\x0a/gmsx;
    $env->{'CONTENT_LENGTH'} = length $postdata;
    open my($fh), '<', \$postdata;
    binmode $fh;
    $env->{'psgi.input'} = $fh;
    my $maxpost = 64 * 1024;
    my $got = Lamawiki::Controller::body_parameters($env, {}, $maxpost);
    my $expected = eval $test->{'expected'};
    is_deeply $got, $expected, $test->{'name'};
};

__END__

@== edit
@-- env
{
    'REQUEST_METHOD' => 'POST',
    'CONTENT_TYPE' => 'multipart/form-data; boundary="e9jae38ry"',
}
@-- postdata
--e9jae38ry
Content-Disposition: form-data; name="c"

e
--e9jae38ry
Content-Disposition: form-data; name="q"

TestPage
--e9jae38ry--
@-- expected
{
    'c' => 'e',
    'q' => 'TestPage',
}

@== editrev
@-- env
{
    'REQUEST_METHOD' => 'POST',
    'CONTENT_TYPE' => 'multipart/form-data; boundary="e9jae38ry"',
}
@-- postdata
--e9jae38ry
Content-Disposition: form-data; name="c"

er
--e9jae38ry
Content-Disposition: form-data; name="q"

TestPage
--e9jae38ry
Content-Disposition: form-data; name="r"

6
--e9jae38ry--
@-- expected
{
    'c' => 'er',
    'q' => 'TestPage',
    'r' => 6,
}

@== write
@-- env
{
    'REQUEST_METHOD' => 'POST',
    'CONTENT_TYPE' => 'multipart/form-data; boundary="e9jae38ry"',
}
@-- postdata
--e9jae38ry
Content-Disposition: form-data; name="c"

w
--e9jae38ry
Content-Disposition: form-data; name="q"

TestPage
--e9jae38ry
Content-Disposition: form-data; name="r"

6
--e9jae38ry
Content-Disposition: form-data; name="t"

[[Lamawiki]] is a small prototype of [[LamawikiEngine]].
--e9jae38ry--
@-- expected
{
    'c' => 'w',
    'q' => 'TestPage',
    'r' => 6,
    't' => '[[Lamawiki]] is a small prototype of [[LamawikiEngine]].',
}


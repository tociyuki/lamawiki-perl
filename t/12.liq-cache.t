use strict;
use warnings;
use File::Spec;
use Lamawiki::Liq;
use Test::More;

plan tests => 15;

my $param = {
    'page' => {'title' => 'TestSimple'},
};

my $input1_r1 = <<'EOS';
<h1>{{page title}} - test 1 r1</a></h1>
EOS
my $expected1_r1 = <<'EOS';
<h1>TestSimple - test 1 r1</a></h1>
EOS
my $input1_r2 = <<'EOS';
<h1>{{page title}} - test 1 r2</a></h1>
EOS
my $expected1_r2 = <<'EOS';
<h1>TestSimple - test 1 r2</a></h1>
EOS

my $input2_r1 = <<'EOS';
<h1>{{page title}} - test 2 r1</a></h1>
EOS
my $expected2_r1 = <<'EOS';
<h1>TestSimple - test 2 r1</a></h1>
EOS
my $input2_r2 = <<'EOS';
<h1>{{page title}} - test 2 r2</a></h1>
EOS
my $expected2_r2 = <<'EOS';
<h1>TestSimple - test 2 r2</a></h1>
EOS

{
    my $liq = Lamawiki::Liq->new({
        'dir' => File::Spec->catdir(qw(. view)),
        'dict' => {},
    });

    can_ok $liq, qw(template render);

    -d $liq->dir or mkdir $liq->dir;
    my $past = time - 3600;
    write_file(File::Spec->catfile($liq->dir, 'test-1.html'), $input1_r1);
    utime $past, $past, File::Spec->catfile($liq->dir, 'test-1.html');
    write_file(File::Spec->catfile($liq->dir, 'test-2.html'), $input2_r1);
    utime $past, $past, File::Spec->catfile($liq->dir, 'test-2.html');

    is $liq->template('test-1.html'), $input1_r1,
        'its template test-1.html should be input1_r1.';

    is $liq->template('test-2.html'), $input2_r1,
        'its template test-2.html should be input2_r1.';

    is $liq->template('test-1.html'), $input1_r1,
        'its template test-1.html should be input1_r1 too.';

    is $liq->template('test-2.html'), $input2_r1,
        'its template test-2.html should be input2_r1 too.';

    is $liq->render('test-1.html', $param), $expected1_r1,
        'it test-1.html should render with input1_r1.';

    is $liq->render('test-2.html', $param), $expected2_r1,
        'it test-2.html should render with input2_r1.';

    write_file(File::Spec->catfile($liq->dir, 'test-1.html'), $input1_r2);

    is $liq->template('test-1.html'), $input1_r2,
        'its template test-1.html should be reloaded input1_r2';

    is $liq->template('test-2.html'), $input2_r1,
        'its template test-2.html should be input2_r1 too.';

    is $liq->render('test-1.html', $param), $expected1_r2,
        'it test-1.html should render with updated input1_r2.';

    is $liq->render('test-2.html', $param), $expected2_r1,
        'it test-2.html should render with input2_r1.';

    write_file(File::Spec->catfile($liq->dir, 'test-2.html'), $input2_r2);

    is $liq->template('test-1.html'), $input1_r2,
        'its template test-1.html should be input1_r2 too.';

    is $liq->template('test-2.html'), $input2_r2,
        'its template test-2.html should be reloaded input2_r2.';

    is $liq->render('test-1.html', $param), $expected1_r2,
        'it test-1.html should render with input1_r2.';

    is $liq->render('test-2.html', $param), $expected2_r2,
        'it test-2.html should render with updated input2_r2.';

    unlink File::Spec->catfile($liq->dir, 'test-1.html');
    unlink File::Spec->catfile($liq->dir, 'test-2.html');
}

sub write_file {
    my($filename, $text) = @_;
    open my($fh), '>', $filename or die "cannot write '$filename' : $!\n";
    binmode $fh;
    print $fh $text;
    close $fh;
    return;
}


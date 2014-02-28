package Lamawikix::Testutil;
use strict;
use warnings;
use Carp;
use File::Spec;
use Lamawiki::Strftime qw(strftime);
use Encode;
use DBI qw(:sql_types);
use base qw(Exporter);

our @EXPORT_OK = qw(
    split_spec ctl_get ctl_post
    dbx_fixup_data make_titles_sources fakeyaml_loadfile fakeyaml_load
);

# based on Test::Base
sub split_spec {
    my($cd, $dd, $spec) = @_;
    my @hunks = ($spec =~ m/^(\Q${cd}\E.*?(?=^\Q${cd}\E|\z))/msg);
    my $blocks = [];
    for my $hunk (@hunks) {
        $hunk =~ s/\A\Q${cd}\E[ \t]*(.*)\s+// or die;
        my $block = {'name' => $1};
        my @parts = split /^\Q${dd}\E +\(?(\w+)\)? *(.*)?\n/m, $hunk;
        my $description = shift @parts;
        while (@parts) {
            my($type, $filters, $value) = splice @parts, 0, 3;
            $value = defined $value ? $value : q();
            $value =~ s/\n+\Z/\n/msx;
            $block->{$type} = $value;
        }
        push @{$blocks}, $block;
    }
    return $blocks;
}

sub ctl_get {
    my($ctl, $env, $now) = @_;
    my $env1 = +{
        'REQUEST_METHOD' => 'GET', 'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_USER_AGENT' => 'Test/1.0', 'REMOTE_ADDR' => '127.0.0.1',
        %{$env},
    };
    return $ctl->call($env1, $now || $ctl->wiki->now || time);
}

sub ctl_post {
    my($ctl, $env, $data, $now) = @_;
    chomp $data; $data .= "\n"; $data =~ s/\r\n?|\n/\x0d\x0a/gmsx;
    # fail on perl-5.8.9 : open my($fh), '<:raw', \$data;
    open my($fh), '<', \$data;
    binmode $fh;
    my $env1 = +{
        'REQUEST_METHOD' => 'POST', 'SCRIPT_NAME' => q(), 'PATH_INFO' => q(/),
        'HTTP_USER_AGENT' => 'Test/1.0', 'REMOTE_ADDR' => '127.0.0.1',
        %{$env},
        'psgi.input' => $fh, 'CONTENT_LENGTH' => length $data,
    };
    return $ctl->call($env1, $now || $ctl->wiki->now || time);
}

sub dbx_fixup_data {
    my($dbx, $data) = @_;
    my $dbf = $dbx->merge_module(
'titles.insert' => [<<'ENDSQL', undef, qw(id title rev summary content)],
INSERT INTO titles (id,title,rev,summary,content) VALUES (?,?,?,?,?);
ENDSQL

'sources.insert' => [<<'ENDSQL', undef, qw(rev id posted remote source)],
INSERT INTO sources (rev,id,posted,remote,source) VALUES (?,?,?,?,?);
ENDSQL
    );
    $dbf->begin_work;
    for my $x (@{$data}) {
        my $table = $x->{'-prop'};
        $dbf->call("$table.insert", $x);
    }
    $dbf->commit;
    return;
}

sub make_titles_sources {
    my($data, $proto) = @_;
    my $titles = {};
    my $sources = {};
    for my $x (@{$data}) {
        if ($x->{'-prop'} eq 'titles') {
            my $page = $proto->new({
                'rev' => $x->{'rev'}, 'id' => $x->{'id'}, 'title' => $x->{'title'},
                'summary' => $x->{'summary'}, 'content' => $x->{'content'},
                'source' => q(), 'posted' => undef, 'remote' => undef, 'rel' => [],
            });
            $titles->{$page->id} = $page;
        }
        if ($x->{'-prop'} eq 'relates') {
            push @{$titles->{$x->{'id'}}->rel}, $proto->new({
                'id' => $x->{'to_id'},
            });
        }
        if ($x->{'-prop'} eq 'sources') {
            my $id = $x->{'id'};
            my $page = $proto->new({
                'rev' => $x->{'rev'}, 'id' => $id, 'title' => $titles->{$id}->title,
                'summary' => $titles->{$id}->summary, 'content' => q(),
                'posted' => $x->{'posted'}, 'remote' => $x->{'remote'},
                'source' => $x->{'source'},
            });
            $sources->{$page->rev} = $page;
            if ($page->rev == $titles->{$page->id}->rev) {
                $titles->{$page->id}->{'posted'} = $page->posted;
                $titles->{$page->id}->{'remote'} = $page->remote;
                $titles->{$page->id}->{'source'} = $page->source;
            }
        }
    }
    for my $id (keys %{$titles}) {
        for my $to (@{$titles->{$id}->rel}) {
            $to->{'title'} = $titles->{$to->id}->title;
            $to->{'rev'} = $titles->{$to->id}->rev;
        }
    }
    return ($titles, $sources);
}

sub fakeyaml_loadfile {
    my($file) = @_;
    return fakeyaml_load(read_file($file));
}

sub read_file {
    my($file) = @_;
    open my($fh), '<:raw', $file
        or croak "cannot open '$file' : $!";
    local $/ = undef;
    my $s = <$fh>;
    close $fh;
    return decode_utf8($s);
}

sub fakeyaml_load {
    my($s) = @_;
    my $seq = qr/\G(?:\#[^\n]*\n+)*-[ ]+!(\w+)\n+/msx;
    my $mapkey = qr/\G[ ]{2}(\w+):/msx;
    my $scalar = qr/\G[ ]+(?:!(!?\w+)[ ]+)?(\S[^\n]*)\n+/msx;
    my $literal = qr/\G[ ]+[|]\n((?:\n*(?:[ ]{4}[^\n]*\n)+)*)\n*/msx;
    my $data = [];
    $s =~ m/\G(?:\#[^\n]*\n+)*---[^\n]*\n+/gcmsxo;
    while ($s =~ m/$seq/gcmsxo) {
        my $item = {'-prop' => $1};
        while ($s =~ m/$mapkey/gcmsxo) {
            my $k = $1;
            if ($s =~ m/$literal/gcmsxo) {
                my $v = $1;
                $v =~ s/^[ ]{4}//gmsxo;
                $item->{$k} = $v;
            }
            elsif ($s =~ m/$scalar/gcmsxo) {
                my($prop, $v) = ($1 || q(), $2);
                $item->{$k} = $prop eq '!timestump' ? strftime('%s', $v) : $v;
            }
            elsif ($s =~ m/\G\n+/gcmsxo) {
                $item->{$k} = q();
            }
        }
        push @{$data}, $item;
    }
    return $data;
}

1;


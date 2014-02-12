use strict;
use warnings;
use File::Spec;
use Test::More tests => 31;

BEGIN { use_ok 'Lamawiki::Liq' }

can_ok 'Lamawiki::Liq', qw(
    new filter dir dict merge_filters core_filters execute call
);

my $viewdir = File::Spec->catdir(qw[. view ja]);

{
    my $it = Lamawiki::Liq->new({
        'filter' => {
            'RAW' => 'raw_filter',  # sub{ $_[0] }
        },
        'dir' => $viewdir,
        'dict' => {'index.html' => ['now', 'ON TEST']}, # {..=>[time, ..]}
    });

    ok ref $it && $it->isa('Lamawiki::Liq'),
        'its new should create an instance of it.';
    is_deeply $it->filter, {'RAW' => 'raw_filter'},
        'its new should inject a hash of attribute `filter`.';
    is $it->dir, $viewdir,
        'its new should inject a value of attribute `dir`.';
    is_deeply $it->dict, {'index.html' => ['now', 'ON TEST']},
        'its new should inject a value of attribute `dict`.';

    my $liq = $it->merge_filters(
        'NOT' => 'not_filter',   # sub{ ! $_[0] }
        'SIZE' => 'size_filter', # sub{ scalar @{$_[0]} }
    );
    is_deeply $liq, {
        'filter' => {
            'RAW' => 'raw_filter',
            'NOT' => 'not_filter',
            'SIZE' => 'size_filter'
        },
        'dir' => $viewdir,
        'dict' => {'index.html' => ['now', 'ON TEST']},
    },  'its merge_filters should append filters into `filter`.';
    is_deeply $it, {
        'filter' => {
            'RAW' => 'raw_filter',
        },
        'dir' => $viewdir,
        'dict' => {'index.html' => ['now', 'ON TEST']},
    },  'its merge_filters should not change the original instance.';

    my $filters = {$it->core_filters};
    is ref $filters->{'HTMLALL'}, 'CODE',
        'its core_filter HTMLALL should be the code.';
    is ref $filters->{'HTML'}, 'CODE',
        'its core_filter HTML should be the code.';
    is ref $filters->{'URIALL'}, 'CODE',
        'its core_filter URIALL should be the code.';
    is ref $filters->{'URI'}, 'CODE',
        'its core_filter URI should be the code.';
    is ref $filters->{'UNHTMLALL'}, 'CODE',
        'its core_filter UNHTMLALL should be the code.';
    is ref $filters->{'RAW'}, 'CODE',
        'its core_filter RAW should be the code.';
    is ref $filters->{'NOT'}, 'CODE',
        'its core_filter NOT should be the code.';
    is ref $filters->{'YMDHM'}, 'CODE',
        'its core_filter YMDHM should be the code.';
    is ref $filters->{'LINES'}, 'CODE',
        'its core_filter LINES should be the code.';
    is ref $filters->{'ENSP'}, 'CODE',
        'its core_filter ENSP should be the code.';
    # see t/14.toyliq-render.t for test `dir`, `dict`, and `execute`.
}

{
    my $it = Lamawiki::Liq->new;

    is_deeply [sort keys %{$it->filter}], [sort keys %{+{$it->core_filters}}],
        'its filter should set core filters in default.';

    my $ascii 
      = ' !"#$%&\'()*+,-./0123456789:;<=>?'
       .'@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'
       .'`abcdefghijklmnopqrstuvwxyz{|}~';

    is $it->call('HTMLALL', $ascii),
        ' !&quot;#$%&amp;&#39;()*+,-./0123456789:;&lt;=&gt;?'
       .'@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'
       .'`abcdefghijklmnopqrstuvwxyz{|}~',
        'its HTMLALL filter should escape 7bit ASCII';

    is $it->call('HTMLALL', '&amp;&nbsp;&#42;'), '&amp;amp;&amp;nbsp;&amp;#42;',
        'its HTMLALL filter should escape &amp;';

    is $it->call('HTMLALL', "\x{3042}"), "\x{3042}",
        'its HTMLALL filter should escape utf8';

    is $it->call('HTML', $ascii),
        ' !&quot;#$%&amp;&#39;()*+,-./0123456789:;&lt;=&gt;?'
       .'@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_'
       .'`abcdefghijklmnopqrstuvwxyz{|}~',
        'its HTML filter should escape 7bit ASCII';

    is $it->call('HTML', '&amp;&nbsp;&#42;'), '&amp;&nbsp;&#42;',
        'its HTML filter should escape &amp;';

    is $it->call('HTML', "\x{3042}"), "\x{3042}",
        'its HTML filter should escape utf8';

    is $it->call('URIALL', $ascii),
        '%20%21%22%23%24%25%26%27%28%29%2A%2B%2C-./0123456789%3A%3B%3C%3D%3E%3F'
       .'%40ABCDEFGHIJKLMNOPQRSTUVWXYZ%5B%5C%5D%5E_'
       .'%60abcdefghijklmnopqrstuvwxyz%7B%7C%7D~',
        'its URIALL filter should escape 7bit ASCII';

    is $it->call('URIALL', "\x{3042}"), '%E3%81%82',
        'its URIALL filter should escape utf8';

    is $it->call('URIALL', 'http://example.net/?c=b&t=wiki&amp;v=%E3%81%82#p3'),
        'http%3A//example.net/%3Fc%3Db%26t%3Dwiki%26amp%3Bv%3D%25E3%2581%2582%23p3',
        'its URIALL filter should escape uri';

    is $it->call('URI', $ascii),
        '%20%21%22#%24%25&amp;%27()%2A+,-./0123456789:;%3C=%3E?'
       .'%40ABCDEFGHIJKLMNOPQRSTUVWXYZ%5B%5C%5D%5E_'
       .'%60abcdefghijklmnopqrstuvwxyz%7B%7C%7D~',
        'its URI filter should escape 7bit ASCII';

    is $it->call('URI', "\x{3042}"), '%E3%81%82',
        'its URI filter should escape encode_utf8';

    is $it->call('URI', 'http://example.net/?c=b&t=wiki&amp;v=%E3%81%82#p3'),
        'http://example.net/?c=b&amp;t=wiki&amp;v=%E3%81%82#p3',
        'its URI filter should escape uri';
}


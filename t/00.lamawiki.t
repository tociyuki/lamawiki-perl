use strict;
use warnings;
use Test::More tests => 27;

BEGIN { use_ok 'Lamawiki' }

diag "Lamawiki $Lamawiki::VERSION";

can_ok 'Lamawiki', qw(new);

{
    my $config = {
        'default.title' => 'MockTop',
        'all.title' => 'MockAll',
        'recent.title' => 'MockRecent',
    };
    my $it = Lamawiki->new({
        'db' => (bless {}, 'Mock::Database'),
        'sch' => (bless {}, 'Mock::Sch'),
        'auth' => (bless {}, 'Mock::Auth'),
        'session' => (bless {}, 'Mock::Session'),
        'capability' => (bless {}, 'Mock::Capability'),
        'page' => (bless {}, 'Mock::Page'),
        'interwiki' => (bless {}, 'Mock::Interwiki'),
        'converter' => (bless {}, 'Mock::Converter'),
        'config' => $config,
    });

    is ref $it->config, ref $config,
        'it should initialize config attribute.';

    is $it->default_title, 'MockTop',
        'its default_title should look config value.';

    is $it->all_title, 'MockAll',
        'its all_title should look config value.';

    is $it->recent_title, 'MockRecent',
        'its recent_title should look config value.';

    is ref $it->db, 'Mock::Database',
        'it should initialize db attribute.';

    ok ! defined $it->db(undef),
        'it should undefine db attribute.';

    ok ! defined $it->db,
        'it should keep undefined db attribute.';

    is ref $it->sch, 'Mock::Sch',
        'it should initialize sch attribute.';

    is ref $it->auth, 'Mock::Auth',
        'it should initialize auth attribute.';

    is ref $it->capability, 'Mock::Capability',
        'it should initialize capability attribute.';

    is ref $it->session, 'Mock::Session',
        'it should initialize session attribute.';

    is ref $it->page, 'Mock::Page',
        'it should initialize page attribute.';

    is ref $it->interwiki, 'Mock::Interwiki',
        'it should initialize interwiki attribute.';

    is ref $it->converter, 'Mock::Converter',
        'it should initialize converter attribute.';

    my $foo = bless {'name' => 'foo'}, 'Mock::User';

    is_deeply $it->user($foo), $foo,
        'it should write user attribute.';

    is_deeply $it->user, $foo,
        'it should keep last value of user attribute.';

    ok ! defined $it->user(undef),
        'it should undefine user attribute.';

    ok ! defined $it->user,
        'it should keep undefined user attribute.';

    is_deeply [sort keys %{+{$it->core_generaters}}],
              [$it->all_title, $it->recent_title],
        'it should make core generaters.';

    is_deeply [sort keys %{+{$it->core_generaters}}],
              [sort keys %{$it->generater}],
        'it should initially fill generater with core_generaters.';
    
    my $it2 = $it->merge_generaters(
        'feed' => sub{},
    );

    is_deeply [sort 'feed', keys %{+{$it->core_generaters}}],
              [sort keys %{$it2->generater}],
        'it should merge generaters.';

    is_deeply [sort keys %{+{$it->core_generaters}}],
              [sort keys %{$it->generater}],
        'it should not touch original Lamawiki object for merge_generaters.';

    isnt "$it", "$it2",
        'it should make other Lamawiki object with merge_generaters.';

    ok $it->can('find_authenticate'),
        'it could find authenticate.'; # detail 05.cookie.t

    ok $it->can('reload_interwiki'),
        'it could reload interwiki.';  # detail 19.intwiki-reload.t
}


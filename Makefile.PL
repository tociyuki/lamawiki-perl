use strict;
use warnings;
use ExtUtils::MakeMaker qw(WriteEmptyMakefile);

my $has_crypt_openssl_random = q();
eval {
    require Crypt::OpenSSL::Random;
    $has_crypt_openssl_random = 1;
};

WriteEmptyMakefile(
    NAME                => 'Lamawiki',
    AUTHOR              => 'MIZUTANI Tociyuki <tociyuki@gmail.com>',
    VERSION_FROM        => 'lib/Lamawiki.pm',
    ABSTRACT_FROM       => 'lib/Lamawiki.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Digest::MD5' => 0,
        'File::Spec' => 0,
        'Encode' => 0,
        'Time::Local' => 0,
        'DBI' => 0,
        'DBD::SQLite' => 0,
        ($has_crypt_openssl_random ? () : ('Crypt::URandom' => 0)),
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);


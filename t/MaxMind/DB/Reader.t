use strict;
use warnings;
use autodie;

use Test::More;

use lib 't/lib';
use Test::MaxMind::DB::Common::Util qw( standard_test_metadata );
use Test::MaxMind::DB::Reader;

use File::Temp qw( tempdir );
use Net::Works::Network;

use MaxMind::DB::Reader;

my $tempdir = tempdir( CLEANUP => 1 );

for my $record_size ( 24, 28, 32 ) {
    for my $file_type (qw( ipv4 mixed )) {
        _test_ipv4_lookups( $record_size, $file_type );
    }

    for my $file_type (qw( ipv6 mixed )) {
        _test_ipv6_lookups( $record_size, $file_type );
    }
}

sub _test_ipv4_lookups {
    my $record_size = shift;
    my $file_type   = shift;

    my $filename = sprintf(
        'MaxMind-DB-test-%s-%s.mmdb',
        $file_type,
        $record_size
    );

    my $reader = MaxMind::DB::Reader->new(
        file => "maxmind-db/test-data/$filename" );

    my $ip_version = $file_type eq 'mixed' ? 6 :4;
    _test_metadata(
        $reader,
        {
            ip_version => $ip_version,
            record_size => $record_size,
        },
        $filename,
    );

    my @subnets
        = Net::Works::Network->range_as_subnets( '1.1.1.1', '1.1.1.32' );

    for my $ip ( map { $_->first()->as_string() } @subnets ) {
        my $expect = ( $ip_version == 6 ? '::' : q{} ) . $ip;

        is_deeply(
            $reader->data_for_address($ip),
            { ip => $expect },
            "found expected data record for $ip - $filename"
        );
    }

    for my $pair (
        [ '1.1.1.3'  => '1.1.1.2' ],
        [ '1.1.1.5'  => '1.1.1.4' ],
        [ '1.1.1.7'  => '1.1.1.4' ],
        [ '1.1.1.9'  => '1.1.1.8' ],
        [ '1.1.1.15' => '1.1.1.8' ],
        [ '1.1.1.17' => '1.1.1.16' ],
        [ '1.1.1.31' => '1.1.1.16' ],
        ) {

        my ( $ip, $expect ) = @{$pair};

        $expect = '::' . $expect if $ip_version == 6;

        is_deeply(
            $reader->data_for_address($ip),
            { ip => $expect },
            "found expected data record for $ip - $filename"
        );
    }

    for my $ip ( '1.1.1.33', '255.254.253.123' ) {
        is(
            $reader->data_for_address($ip),
            undef,
            "no data found for $ip - $filename"
        );
    }
}

sub _test_ipv6_lookups {
    my $record_size = shift;
    my $file_type   = shift;

    my $filename = sprintf(
        'MaxMind-DB-test-%s-%s.mmdb',
        $file_type,
        $record_size
    );

    my $reader = MaxMind::DB::Reader->new(
        file => "maxmind-db/test-data/$filename" );

    my @subnets = Net::Works::Network->range_as_subnets(
        '::1:ffff:ffff',
        '::2:0000:0059'
    );

    _test_metadata(
        $reader,
        {
            ip_version  => 6,
            record_size => $record_size,
        },
        $filename,
    );

    for my $ip ( map { $_->first()->as_string() } @subnets ) {
        is_deeply(
            $reader->data_for_address($ip),
            { ip => $ip },
            "found expected data record for $ip - $filename"
        );
    }

    for my $pair (
        [ '::2:0:1'  => '::2:0:0' ],
        [ '::2:0:33' => '::2:0:0' ],
        [ '::2:0:39' => '::2:0:0' ],
        [ '::2:0:41' => '::2:0:40' ],
        [ '::2:0:49' => '::2:0:40' ],
        [ '::2:0:52' => '::2:0:50' ],
        [ '::2:0:57' => '::2:0:50' ],
        [ '::2:0:59' => '::2:0:58' ],
        ) {

        my ( $ip, $expect ) = @{$pair};
        is_deeply(
            $reader->data_for_address($ip),
            { ip => $expect },
            "found expected data record for $ip - $filename"
        );
    }

    for my $ip ( '1.1.1.33', '255.254.253.123', '89fa::' ) {
        is(
            $reader->data_for_address($ip),
            undef,
            "no data found for $ip - $filename"
        );
    }
}

done_testing();

sub _test_metadata {
    my $reader          = shift;
    my $expect_metadata = shift;
    my $filename        = shift;

    my $metadata = $reader->metadata();
    my %expect   = (
        binary_format_major_version => 2,
        binary_format_minor_version => 0,
        ip_version                  => 6,
        standard_test_metadata(),
        %{$expect_metadata},
    );

    for my $key ( sort keys %expect ) {
        is_deeply(
            $metadata->$key(),
            $expect{$key},
            "read expected value for metadata key $key - $filename"
        );
    }

    my $epoch = $metadata->build_epoch();
    like(
        "$epoch",
        qr/^\d+$/,
        "build_epoch is an integer - $filename"
    );

    cmp_ok(
        $metadata->build_epoch(),
        '<=',
        time(),
        "build_epoch is <= the current timestamp - $filename"
    );
}

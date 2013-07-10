package MaxMind::DB::Reader::Role::HasMetadata;

use strict;
use warnings;
use namespace::autoclean;
use autodie;

require bytes;
use List::AllUtils qw( min );
use MaxMind::DB::Reader::Decoder;
use MaxMind::DB::Metadata;
use MaxMind::DB::Types qw( Int Metadata );

use Moo::Role;

with 'MaxMind::DB::Reader::Role::Sysreader';

has metadata => (
    is       => 'ro',
    isa      => Metadata,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_metadata',
    handles  => [ MaxMind::DB::Metadata->meta()->get_attribute_list() ],
);

has _data_source_size => (
    is       => 'ro',
    isa      => Int,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_data_source_size',
);

has _data_section_end => (
    is       => 'rw',
    writer   => '_set_data_section_end',
    isa      => Int,
    init_arg => undef,
);

my $MetadataStartMarker = "\xab\xcd\xefMaxMind.com";

sub _build_metadata {
    my $self = shift;

    # We need to make sure that whatever chunk we read will have the metadata
    # in it. The description metadata key is a hash of descriptions, one per
    # language. The description could be something verbose like "GeoIP 2.0
    # City Database, Multilingual - English, Chinese (Taiwan), Chinese
    # (China), French, German, Portuguese" (but with c. 20 languages). That
    # comes out to about 250 bytes _per key_. Multiply that by 20 languages,
    # and the description alon ecould use up about 5k. The other keys in the
    # metadata are very, very tiny.
    #
    # Given all this, reading 20k seems fairly future-proof. We'd have to have
    # extremely long descriptions or descriptions in 80 languages before this
    # became too long.

    my $size = $self->_data_source_size();

    my $last_bytes = min( $size, 20 * 1024 );
    my $last_block = q{};
    $self->_read( \$last_block, -$last_bytes, $last_bytes, 'seek from end' );

    my $start = rindex( $last_block, $MetadataStartMarker );

    die 'Could not find a MaxMind DB metadata marker in this file ('
        . $self->file()
        . '). Is this a valid MaxMind DB file?'
        unless $start >= 0;

    # XXX - this is really gross but I couldn't come up with a better way to
    # factor this out that doesn't involve either looking for the metadata
    # marker multiple times _or_ storing the whole metadata raw chunk in
    # memory so we can calculate this later
    $self->_set_data_section_end( $size - ( $last_bytes - $start ) );

    $start += bytes::length($MetadataStartMarker);

    open my $fh, '<', \( substr( $last_block, $start ) );

    my $raw = MaxMind::DB::Reader::Decoder->new(
        data_source => $fh,
    )->decode(0);

    my $metadata = MaxMind::DB::Metadata->new($raw);

    return $metadata;
}

sub _build_data_source_size {
    my $self = shift;

    return ( stat $self->data_source() )[7];
}

1;

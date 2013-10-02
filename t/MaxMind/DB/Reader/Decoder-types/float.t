# PP only
use strict;
use warnings;

use lib 't/lib';

use Test::MaxMind::DB::Common::Data qw( test_cases_for );
use Test::MaxMind::DB::Reader::Decoder qw( test_decoding_of_type );
use Test::More;

use lib 't/lib';
use Test::MaxMind::DB::Reader;

test_decoding_of_type( float => test_cases_for('float') );

done_testing();

#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Math::Prime::Util qw/is_totient/;
my $usexs = Math::Prime::Util::prime_get_config->{'xs'};
my $usegmp = Math::Prime::Util::prime_get_config->{'gmp'};
my $extra = defined $ENV{EXTENDED_TESTING} && $ENV{EXTENDED_TESTING};

plan tests => 0
            + 2
            + 3
            + 3
            + 1
            ;

is_deeply( [map { is_totient($_) } 0..40],
           [0,1,1,0,1,0,1,0,1,0,1,0,1,0,0,0,1,0,1,0,1,0,1,0,1,0,0,0,1,0,1,0,1,0,0,0,1,0,0,0,1],
           "is_totient 0 .. 40" );
is_deeply( [grep { is_totient( 2**29 + $_ ) } 1 .. 80],
           [4,10,12,16,32,38,48,64,68,72],
           "is_fundamental(2^29_1 .. 2^29+80)" );

is( is_totient("9223372036854775836"), 1, "is_totient(2^63+28)" );
SKIP: {
  skip "Skipping is_totient for 2^63 + ...", 2 unless ~0 > 4294967295;
  is( is_totient("9223372036854775828"), 1, "is_totient(2^63+20)" );
  is( is_totient("9223372036854775842"), 0, "is_totient(2^63+34)" );
}

is( is_totient("9671406556917033397649496"), 1, "is_totient(2^83+88)" );
SKIP: {
  skip "Skipping is_totient for 2^83 + ...", 2 unless $extra;
  is( is_totient("9671406556917033397649458"), 0, "is_totient(2^83+50)" );
  is( is_totient("9671406556917033397649472"), 1, "is_totient(2^83+64)" );
}

# trizen found this error in 2019
is( is_totient("281474976710656"), 1, "is_totient(2**48)" );

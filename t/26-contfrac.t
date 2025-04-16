#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Math::Prime::Util qw/contfrac/;

my @ex = (
  [0,1,[0]],
  [0,2,[0]],
  [1,3,[0,3]],
  [4,11,[0, 2, 1, 3]],
  [8,22,[0, 2, 1, 3]],
  [67,29,[2, 3, 4, 2]],
  [121,23,[5, 3, 1, 5]],
  [3,4837,[0,1612,3]],
  [0xfff1,0x7fed,[2, 1423, 1, 6, 1, 2]],
  [83116,51639,[1, 1, 1, 1, 1, 3, 1, 1, 2, 2, 4, 1, 2, 1, 1, 1, 3]],
  [9238492834,2398702938777,[0, 259, 1, 1, 1, 3, 1, 7, 2, 3, 7, 2, 1, 1, 2, 4, 2, 1, 10, 5, 3, 1, 5, 6]],
  ["243224233245235253407096734543059","4324213412343432913758138673203834",[0,17,1,3,1,1,12,1,2,33,2,1,1,1,1,49,1,1,1,1,17,34,1,1,304,1,2,1,1,1,2,1,48,1,20,2,3,5,1,1,16,9,1,1,5,1,2,2,7,4,3,1,7,1,1,17,1,1,29,1,12,2,5]],
  # F(n)/F(n+1)
  [144,233,[0,1,1,1,1,1,1,1,1,1,1,2]],
  ["7540113804746346429","12200160415121876738",[0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2]],
);

my @pi = (
  [377,120,[3,7,17]],
  [3927,1250,[3,7,16,11]],
  [62832,20000,[3,7,16,11]],
  # Best rational approximations
  [22,7,[3,7]],
  [333,106,[3,7,15]],
  [355,113,[3,7,16]],
  [103993,33102,[3,7,15,1,292]],
  [104348,33215,[3,7,15,1,293]],
  [208341,66317,[3,7,15,1,292,2]],
  [312689,99532,[3,7,15,1,292,1,2]],
  [833719,265381,[3,7,15,1,292,1,1,1,2]],
  [1146408,364913,[3,7,15,1,292,1,1,1,3]],
  [4272943,1360120,[3,7,15,1,292,1,1,1,2,1,3]],
  #
  [80143857,25510582,[3,7,15,1,292,1,1,1,2,1,3,1,14]],
  ["262452630335382199398","83541266890691994833",[3,7,15,1,292,1,1,1,2,1,3,1,14,2,1,1,2,2,2,2,1,84,2,1,1,15,3,13,1,4,2,6,6,99]],
);

plan tests => scalar(@ex) + scalar(@pi);

for my $t (@ex, @pi) {
  my($n,$d,$exp) = @$t;
  is_deeply( [contfrac($n,$d)], $exp, "contfrac($n,$d) = (@$exp)" );
}

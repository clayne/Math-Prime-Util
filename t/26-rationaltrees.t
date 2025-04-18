#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Math::Prime::Util qw/next_calkin_wilf next_stern_brocot
                         calkin_wilf_n stern_brocot_n
                         nth_calkin_wilf nth_stern_brocot
                         nth_stern_diatomic
                         farey/;

my @CW = ([1,1],[1,2],[2,1],[1,3],[3,2],[2,3],[3,1],[1,4],[4,3],[3,5],[5,2],[2,5],[5,3],[3,4],[4,1],[1,5],[5,4],[4,7],[7,3],[3,8],[8,5],[5,7],[7,2],[2,7],[7,5],[5,8],[8,3],[3,7],[7,4],[4,5],[5,1],[1,6],[6,5],[5,9],[9,4],[4,11],[11,7],[7,10],[10,3],[3,11],[11,8],[8,13],[13,5],[5,12],[12,7],[7,9],[9,2],[2,9],[9,7],[7,12],[12,5],[5,13],[13,8],[8,11],[11,3],[3,10],[10,7],[7,11],[11,4],[4,9],[9,5],[5,6],[6,1],[1,7],[7,6],[6,11],[11,5],[5,14],[14,9],[9,13],[13,4],[4,15],[15,11],[11,18],[18,7],[7,17],[17,10],[10,13],[13,3],[3,14],[14,11],[11,19],[19,8],[8,21],[21,13],[13,18],[18,5],[5,17],[17,12],[12,19],[19,7],[7,16],[16,9],[9,11],[11,2],[2,11],[11,9],[9,16],[16,7],[7,19]);
my @SB = ([1,1],[1,2],[2,1],[1,3],[2,3],[3,2],[3,1],[1,4],[2,5],[3,5],[3,4],[4,3],[5,3],[5,2],[4,1],[1,5],[2,7],[3,8],[3,7],[4,7],[5,8],[5,7],[4,5],[5,4],[7,5],[8,5],[7,4],[7,3],[8,3],[7,2],[5,1],[1,6],[2,9],[3,11],[3,10],[4,11],[5,13],[5,12],[4,9],[5,9],[7,12],[8,13],[7,11],[7,10],[8,11],[7,9],[5,6],[6,5],[9,7],[11,8],[10,7],[11,7],[13,8],[12,7],[9,5],[9,4],[12,5],[13,5],[11,4],[10,3],[11,3],[9,2],[6,1],[1,7],[2,11],[3,14],[3,13],[4,15],[5,18],[5,17],[4,13],[5,14],[7,19],[8,21],[7,18],[7,17],[8,19],[7,16],[5,11],[6,11],[9,16],[11,19],[10,17],[11,18],[13,21],[12,19],[9,14],[9,13],[12,17],[13,18],[11,15],[10,13],[11,14],[9,11],[6,7],[7,6],[11,9],[14,11],[13,10],[15,11]);

my @ex = (
  # n d idxCW idxSB
  [4, 11, 36, 36],
  [22,7,519,960],
  [37,53,1990,1423],
  [144,233,2730,2730],
  [83116,51639,123456789,111333227],
  [64,65,"36893488147419103230","27670116110564327423"],
  [66,65,"36893488147419103233","55340232221128654848"],
  [32,1,4294967295,4294967295],
  [64,1,"18446744073709551615","18446744073709551615"],
  ["228909276746","645603216423","1054982144710410407556","667408827216638861715"],
);

my @A002487 = (0,1,1,2,1,3,2,3,1,4,3,5,2,5,3,4,1,5,4,7,3,8,5,7,2,7,5,8,3,7,4,5,1,6,5,9,4,11,7,10,3,11,8,13,5,12,7,9,2,9,7,12,5,13,8,11,3,10,7,11,4,9,5,6,1,7,6,11,5,14,9,13,4,15,11,18,7,17,10,13,3,14,11,19,8,21,13,18,5,17,12,19);
my @fuscs = (
  # A212288 every 50
  [4691,257],
  [87339,2312],
  [1222997,13529],
  [9786539,57317],
  [76895573,238605],
  [357214891,744095],
  [1431655083,1948354],
  [5726623019,5102687],
  [22906492075,13354827],
  [91625925291,34961522],
);

my @Farey = (
  undef,
  [[0,1],[1,1]],
  [[0,1],[1,2],[1,1]],
  [[0,1],[1,3],[1,2],[2,3],[1,1]],
  [[0,1],[1,4],[1,3],[1,2],[2,3],[3,4],[1,1]],
  [[0,1],[1,5],[1,4],[1,3],[2,5],[1,2],[3,5],[2,3],[3,4],[4,5],[1,1]],
  [[0,1],[1,6],[1,5],[1,4],[1,3],[2,5],[1,2],[3,5],[2,3],[3,4],[4,5],[5,6],[1,1]],
  [[0,1],[1,7],[1,6],[1,5],[1,4],[2,7],[1,3],[2,5],[3,7],[1,2],[4,7],[3,5],[2,3],[5,7],[3,4],[4,5],[5,6],[6,7],[1,1]],
  [[0,1],[1,8],[1,7],[1,6],[1,5],[1,4],[2,7],[1,3],[3,8],[2,5],[3,7],[1,2],[4,7],[3,5],[5,8],[2,3],[5,7],[3,4],[4,5],[5,6],[6,7],[7,8],[1,1]],
  [[0,1],[1,9],[1,8],[1,7],[1,6],[1,5],[2,9],[1,4],[2,7],[1,3],[3,8],[2,5],[3,7],[4,9],[1,2],[5,9],[4,7],[3,5],[5,8],[2,3],[5,7],[3,4],[7,9],[4,5],[5,6],[6,7],[7,8],[8,9],[1,1]],
);

my @farey_ex = (
  [24, 16, [2,21]],
  [507,427, [3,505]],
);


plan tests => 3 + 3 + 2*scalar(@ex) + 2
            + 3*(scalar(@Farey)-1) + scalar(@farey_ex);

{
  my @s=([1,1]);
  push @s, [next_calkin_wilf($s[-1]->[0],$s[-1]->[1])] for 1..99;
  is_deeply( \@s, \@CW, "next_calkin_wilf first 100 terms" );
}
{
  my @s;
  push @s, calkin_wilf_n($_->[0],$_->[1]) for @CW;
  is_deeply( \@s, [1..100], "calkin_wilf_n first 100 terms" );
}
{
  my @s;
  push @s,[nth_calkin_wilf($_)] for 1..100;
  is_deeply( \@s, \@CW, "nth_calkin_wilf first 100 terms" );
}

{
  my @s=([1,1]);
  push @s, [next_stern_brocot($s[-1]->[0],$s[-1]->[1])] for 1..99;
  is_deeply( \@s, \@SB, "next_stern_brocot first 100 terms" );
}
{
  my @s;
  push @s, stern_brocot_n($_->[0],$_->[1]) for @SB;
  is_deeply( \@s, [1..100], "stern_brocot_n first 100 terms" );
}
{
  my @s;
  push @s,[nth_stern_brocot($_)] for 1..100;
  is_deeply( \@s, \@SB, "nth_stern_brocot first 100 terms" );
}

for my $t (@ex) {
  my($n,$d,$cwidx,$sbidx) = @$t;
  is_deeply( [calkin_wilf_n($n,$d),[nth_calkin_wilf($cwidx)]], [$cwidx,[$n,$d]], "calkin_wilf_n($n,$d) and nth_calkin_wilf($cwidx)" );
  is_deeply( [stern_brocot_n($n,$d),[nth_stern_brocot($sbidx)]], [$sbidx,[$n,$d]], "stern_brocot_n($n,$d) and nth_stern_brocot($sbidx)" );
}

##### Stern diatomic

{
  my @s = map { nth_stern_diatomic($_) } 0 .. $#A002487;
  is_deeply( \@s, \@A002487, "nth_stern_diatomic = A002487 first terms" );
}

{
  my(@s,@exp);
  for my $t (@fuscs) {
    push @s,nth_stern_diatomic($t->[0]);
    push @exp,$t->[1];
  }
  is_deeply( \@s, \@exp, "nth_stern_diatomic(n) for selected n" );
}

##### Farey sequences

# mpu 'say scalar farey(5)
# mpu 'say join " ",map { join "/",@$_ } farey(5)'
# mpu '$n=12; say join " ",map { join "/",@{farey($n,$_)} } 0..farey($n)-1;'

for my $n (1 .. $#Farey) {
  my @expf = @{$Farey[$n]};
  my @gotf = farey($n);
  my $gotlen = farey($n);
  my $explen = scalar(@expf);
  my @gotf1 = map { farey($n,$_) } 0 .. $gotlen;
  is( $gotlen, $explen, "scalar farey($n) = $explen" );
  is_deeply( \@gotf, \@expf, "farey($n) produces correct sequence" );
  is_deeply( \@gotf1, [@expf,undef], "farey($n,0..) produces correct sequence" );
}

for my $t (@farey_ex) {
  my($n,$k,$frac) = @$t;
  is_deeply( farey($n,$k), $frac, "farey($n,$k) = $frac->[0] / $frac->[1]" );
}

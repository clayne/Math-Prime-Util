#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use Math::Prime::Util qw/chinese/;

#my $extra = defined $ENV{EXTENDED_TESTING} && $ENV{EXTENDED_TESTING};
#my $use64 = Math::Prime::Util::prime_get_config->{'maxbits'} > 32;
#my $usexs = Math::Prime::Util::prime_get_config->{'xs'};
#my $usegmp= Math::Prime::Util::prime_get_config->{'gmp'};
#$use64 = 0 if $use64 && 18446744073709550592 == ~0;

my @crts = (
  [ [], 0 ],
  [ [[4,5]], 4 ],
  [ [[77,11]], 0 ],
  [ [[0,5],[0,6]], 0 ],
  [ [[14,5],[0,6]], 24 ],
  [ [[10,11],[4,22],[9,19]], undef ],
  [ [[77,13],[79,17]], 181 ],
  [ [[2,3],[3,5],[2,7]], 23 ],
  [ [[10,11],[4,12],[12,13]], 1000 ],
  [ [[42,127],[24,128]], 2328 ],             # Some tests from Mod::Int
  [ [[32,126],[23,129]], 410 ],
  [ [[2328,16256],[410,5418]], 28450328 ],
  [ [[1,10],[11,100]], 11 ],
  [ [[11,100],[22,100]], undef ],
  [ [[1753051086,3243410059],[2609156951,2439462460]], "6553408220202087311"],
  [ [ ["6325451203932218304","2750166238021308"],
      ["5611464489438299732","94116455416164094"] ],
    "1433171050835863115088946517796" ],
  [ [ ["1762568892212871168","8554171181844660224"],
      ["2462425671659520000","2016911328009584640"] ],
    "188079320578009823963731127992320" ],
  [ [ ["856686401696104448","11943471150311931904"],
      ["6316031051955372032","13290002569363587072"] ],
    "943247297188055114646647659888640" ],
  [ [[-3105579549,3743000622],[-1097075646,1219365911]], "2754322117681955433"],
  [ [ ["-925543788386357567","243569243147991"],
      ["-1256802905822510829","28763455974459440"] ],
    "837055903505897549759994093811" ],
  [ [ ["-2155972909982577461","8509855219791386062"],
      ["-5396280069505638574","6935743629860450393"] ],
    "12941173114744545542549046204020289525" ],
  [ [[3,5],[2,0]], undef ],       # three tests that we handle zeros.
  [ [[3,0],[2,3]], undef ],
  [ [[3,5],[3,0],[2,3]], undef ],
  [ [[5,0],[15,1]], undef ],      # two more test for zeros
  [ [[15,1],[5,0]], undef ],
  # Tests to make IV_MAX < lcm < UV_MAX
  [ [[14,44381], [87,48473], [19,59467], [74,118751]], "6441035217555187414"],
  [ [[2,181], [3,193], [5,227], [30,383]], 2205672518],
);

plan tests => 0 + scalar(@crts);

###### chinese
foreach my $carg (@crts) {
  my($aref, $exp) = @$carg;
  my $crt = chinese(@$aref);
  is( $crt, $exp, "crt(".join(",",map { "[@$_]" } @$aref).") = " . ((defined $exp) ? $exp : "<undef>") );
}

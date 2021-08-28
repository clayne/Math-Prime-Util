package Math::Prime::Util::PP;
use strict;
use warnings;
use Carp qw/carp croak confess/;

BEGIN {
  $Math::Prime::Util::PP::AUTHORITY = 'cpan:DANAJ';
  $Math::Prime::Util::PP::VERSION = '0.73';
}

BEGIN {
  do { require Math::BigInt;  Math::BigInt->import(try=>"GMP,Pari"); }
    unless defined $Math::BigInt::VERSION;
}

# The Pure Perl versions of all the Math::Prime::Util routines.
#
# Some of these will be relatively similar in performance, some will be
# very slow in comparison.
#
# Most of these are pretty simple.  Also, you really should look at the C
# code for more detailed comments, including references to papers.

BEGIN {
  use constant OLD_PERL_VERSION=> $] < 5.008;
  use constant MPU_MAXBITS     => (~0 == 4294967295) ? 32 : 64;
  use constant MPU_64BIT       => MPU_MAXBITS == 64;
  use constant MPU_32BIT       => MPU_MAXBITS == 32;
 #use constant MPU_MAXPARAM    => MPU_32BIT ? 4294967295 : 18446744073709551615;
 #use constant MPU_MAXDIGITS   => MPU_32BIT ? 10 : 20;
  use constant MPU_MAXPRIME    => MPU_32BIT ? 4294967291 : 18446744073709551557;
  use constant MPU_MAXPRIMEIDX => MPU_32BIT ?  203280221 :  425656284035217743;
  use constant MPU_HALFWORD    => MPU_32BIT ? 65536 : OLD_PERL_VERSION ? 33554432 : 4294967296;
  use constant UVPACKLET       => MPU_32BIT ? 'L' : 'Q';
  use constant MPU_INFINITY    => (65535 > 0+'inf') ? 20**20**20 : 0+'inf';
  use constant BZERO           => Math::BigInt->bzero;
  use constant BONE            => Math::BigInt->bone;
  use constant BTWO            => Math::BigInt->new(2);
  use constant INTMAX          => (!OLD_PERL_VERSION || MPU_32BIT) ? ~0 : 562949953421312;
  use constant INTMIN          => (MPU_32BIT ? -2147483648 : !OLD_PERL_VERSION ? -9223372036854775808 : -562949953421312);
  use constant SINTMAX         => (INTMAX >> 1);
  use constant BMAX            => Math::BigInt->new('' . INTMAX);
  use constant BMIN            => Math::BigInt->new('' . INTMIN);
  use constant B_PRIM767       => Math::BigInt->new("261944051702675568529303");
  use constant B_PRIM235       => Math::BigInt->new("30");
  use constant PI_TIMES_8      => 25.13274122871834590770114707;
}

# By using these aliases, we call into the main code instead of
# to the PP function.
#
# If we have turned off XS, then this will call the PPFE or direct function.
# This might be the same, but if the PPFE does input validation it will
# be slower (albeit every call will be validated).
#
# Otherwise, we'll go to the XS function, which will either handle it
# directly (e.g. we've broken down the input into smaller values which
# the XS code can handle), or call the GMP backend, otherwise call here.
#
# For the usual case where we have XS, this is significantly faster.  The
# aliases make the code here much easier to read.  An alternate
# implementation would be to make the perl subs here use a pp_{...} prefix.


*Maddint = \&Math::Prime::Util::addint;
*Msubint = \&Math::Prime::Util::subint;
*Mmulint = \&Math::Prime::Util::mulint;
*Mdivint = \&Math::Prime::Util::divint;
*Mpowint = \&Math::Prime::Util::powint;
*Mmodint = \&Math::Prime::Util::modint;
*Msqrtint = \&Math::Prime::Util::sqrtint;
*Mrootint = \&Math::Prime::Util::rootint;
*Mlogint = \&Math::Prime::Util::logint;
*Mnegint = \&Math::Prime::Util::negint;
*Mlshiftint = \&Math::Prime::Util::lshiftint;
*Mrshiftint = \&Math::Prime::Util::rshiftint;

*Maddmod = \&Math::Prime::Util::addmod;
*Msubmod = \&Math::Prime::Util::submod;
*Mmulmod = \&Math::Prime::Util::mulmod;
*Mdivmod = \&Math::Prime::Util::divmod;
*Mpowmod = \&Math::Prime::Util::powmod;
*Minvmod = \&Math::Prime::Util::invmod;
*Mrootmod = \&Math::Prime::Util::rootmod;

*Mgcd = \&Math::Prime::Util::gcd;
*Mfactor = \&Math::Prime::Util::factor;
*Mfactor_exp = \&Math::Prime::Util::factor_exp;
*Mis_prime = \&Math::Prime::Util::is_prime;
*Mchinese = \&Math::Prime::Util::chinese;
*Mvaluation = \&Math::Prime::Util::valuation;
*Mkronecker = \&Math::Prime::Util::kronecker;
*Mmoebius = \&Math::Prime::Util::moebius;
*Mfactorial = \&Math::Prime::Util::factorial;
*Mprimorial = \&Math::Prime::Util::primorial;
*Mpn_primorial = \&Math::Prime::Util::pn_primorial;
*Mbinomial = \&Math::Prime::Util::binomial;
*Murandomm = \&Math::Prime::Util::urandomm;
*Murandomb = \&Math::Prime::Util::urandomb;
*Mnext_prime = \&Math::Prime::Util::next_prime;
*Mprev_prime = \&Math::Prime::Util::prev_prime;
*Mprime_count = \&Math::Prime::Util::prime_count;

*Mvecall = \&Math::Prime::Util::vecall;
*Mvecany = \&Math::Prime::Util::vecany;
*Mvecnone = \&Math::Prime::Util::vecnone;
*Mvecsum = \&Math::Prime::Util::vecsum;
*Mvecprod = \&Math::Prime::Util::vecprod;
*Mvecmax = \&Math::Prime::Util::vecmax;

*Mfordivisors = \&Math::Prime::Util::fordivisors;
*Mforprimes = \&Math::Prime::Util::forprimes;

my $_precalc_size = 0;
sub prime_precalc {
  my($n) = @_;
  croak "Parameter '$n' must be a non-negative integer" unless _is_nonneg_int($n);
  $_precalc_size = $n if $n > $_precalc_size;
}
sub prime_memfree {
  $_precalc_size = 0;
  eval { Math::Prime::Util::GMP::_GMP_memfree(); }
    if defined $Math::Prime::Util::GMP::VERSION && $Math::Prime::Util::GMP::VERSION >= 0.49;
}
sub _get_prime_cache_size { $_precalc_size }
sub _prime_memfreeall { prime_memfree; }


sub _is_nonneg_int {
  ((defined $_[0]) && $_[0] ne '' && ($_[0] !~ tr/0123456789//c));
}

sub _bigint_to_int {
  #if (OLD_PERL_VERSION) {
  #  my $pack = ($_[0] < 0) ? lc(UVPACKLET) : UVPACKLET;
  #  return unpack($pack,pack($pack,"$_[0]"));
  #}
  int("$_[0]");
}

sub _upgrade_to_float {
  do { require Math::BigFloat; Math::BigFloat->import(); }
    if !defined $Math::BigFloat::VERSION;
  Math::BigFloat->new(@_);
}

# Get the accuracy of variable x, or the max default from BigInt/BigFloat
# One might think to use ref($x)->accuracy() but numbers get upgraded and
# downgraded willy-nilly, and it will do the wrong thing from the user's
# perspective.
sub _find_big_acc {
  my($x) = @_;
  my $b;

  $b = $x->accuracy() if ref($x) =~ /^Math::Big/;
  return $b if defined $b;

  my ($i,$f) = (Math::BigInt->accuracy(), Math::BigFloat->accuracy());
  return (($i > $f) ? $i : $f)   if defined $i && defined $f;
  return $i if defined $i;
  return $f if defined $f;

  ($i,$f) = (Math::BigInt->div_scale(), Math::BigFloat->div_scale());
  return (($i > $f) ? $i : $f)   if defined $i && defined $f;
  return $i if defined $i;
  return $f if defined $f;
  return 18;
}

sub _bfdigits {
  my($wantbf, $xdigits) = (0, 17);
  if (defined $bignum::VERSION || ref($_[0]) =~ /^Math::Big/) {
    do { require Math::BigFloat; Math::BigFloat->import(); }
      if !defined $Math::BigFloat::VERSION;
    if (ref($_[0]) eq 'Math::BigInt') {
      my $xacc = ($_[0])->accuracy();
      $_[0] = Math::BigFloat->new($_[0]);
      ($_[0])->accuracy($xacc) if $xacc;
    }
    $_[0] = Math::BigFloat->new("$_[0]") if ref($_[0]) ne 'Math::BigFloat';
    $wantbf = _find_big_acc($_[0]);
    $xdigits = $wantbf;
  }
  ($wantbf, $xdigits);
}


sub _validate_num {
  my($n, $min, $max) = @_;
  croak "Parameter must be defined" if !defined $n;
  return 0 if ref($n);
  croak "Parameter '$n' must be a non-negative integer"
          if $n eq '' || ($n =~ tr/0123456789//c && $n !~ /^\+\d+$/);
  croak "Parameter '$n' must be >= $min" if defined $min && $n < $min;
  croak "Parameter '$n' must be <= $max" if defined $max && $n > $max;
  substr($_[0],0,1,'') if substr($n,0,1) eq '+';
  return 0 unless $n < ~0 || int($n) eq ''.~0;
  1;
}

sub _validate_positive_integer {
  my($n, $min, $max) = @_;
  croak "Parameter must be defined" if !defined $n;
  if (ref($n) eq 'CODE') {
    $_[0] = $_[0]->();
    $n = $_[0];
  }
  if (ref($n) eq 'Math::BigInt') {
    croak "Parameter '$n' must be a non-negative integer"
      if $n->sign() ne '+' || !$n->is_int();
    $_[0] = _bigint_to_int($_[0]) if $n <= BMAX;
  } elsif (ref($n) eq 'Math::GMPz') {
    croak "Parameter '$n' must be a non-negative integer" if Math::GMPz::Rmpz_sgn($n) < 0;
    $_[0] = _bigint_to_int($_[0]) if $n <= INTMAX;
  } else {
    my $strn = "$n";
    if ($strn eq '-0') { $_[0] = 0; $strn = '0'; }
    croak "Parameter '$strn' must be a non-negative integer"
      if $strn eq '' || ($strn =~ tr/0123456789//c && $strn !~ /^\+?\d+$/);
    # TODO: look into using cmp or cmpint
    if (ref($n) || $n >= INTMAX) {      # Looks like a bigint
      $n = Math::BigInt->new($strn);    # Make n a bigint
      $_[0] = $n if $n > INTMAX;        # input becomes bigint if needed
    }
  }
  $_[0]->upgrade(undef) if ref($_[0]) eq 'Math::BigInt' && $_[0]->upgrade();
  croak "Parameter '$_[0]' must be >= $min" if defined $min && $_[0] < $min;
  croak "Parameter '$_[0]' must be <= $max" if defined $max && $_[0] > $max;
  1;
}

sub _validate_integer {
  my($n) = @_;
  croak "Parameter must be defined" if !defined $n;
  if (ref($n) eq 'CODE') {
    $_[0] = $_[0]->();
    $n = $_[0];
  }
  if (ref($n) eq 'Math::BigInt') {
    croak "Parameter '$n' must be an integer" if !$n->is_int();
    $_[0] = _bigint_to_int($_[0]) if $n <= INTMAX && $n >= INTMIN;
  } else {
    my $strn = "$n";
    if ($strn eq '-0') { $_[0] = 0; $strn = '0'; }
    croak "Parameter '$strn' must be an integer"
      if $strn eq '' || ($strn =~ tr/-0123456789//c && $strn !~ /^[-+]?\d+$/);
    if (ref($n) || $n >= INTMAX || $n <= INTMIN) {  # Looks like a bigint
      $n = Math::BigInt->new($strn);
      $_[0] = $n if $n > INTMAX || $n < INTMIN;
    }
  }
  $_[0]->upgrade(undef) if ref($_[0]) && $_[0]->upgrade();
  1;
}

# If we try to call the function in any normal way, just loading this module
# will auto-vivify an empty sub.  So we do a string eval to keep it hidden.
sub _gmpcall {
  my($fname, @args) = @_;
  my $call = "Math::Prime::Util::GMP::$fname(".join(",",map {"\"$_\""} @args).");";
  return eval $call ## no critic qw(ProhibitStringyEval)
}

sub _binary_search {
  my($n, $lo, $hi, $sub, $exitsub) = @_;
  while ($lo < $hi) {
    my $mid = $lo + int(($hi-$lo) >> 1);
    return $mid if defined $exitsub && $exitsub->($n,$lo,$hi);
    if ($sub->($mid) < $n) { $lo = $mid+1; }
    else                   { $hi = $mid;   }
  }
  return $lo-1;
}

my @_primes_small = (0,2);
{
  my($n, $s, $sieveref) = (7-2, 3, _sieve_erat_string(5003));
  push @_primes_small, 2*pos($$sieveref)-1 while $$sieveref =~ m/0/g;
}
my @_prime_next_small = (
   2,2,3,5,5,7,7,11,11,11,11,13,13,17,17,17,17,19,19,23,23,23,23,
   29,29,29,29,29,29,31,31,37,37,37,37,37,37,41,41,41,41,43,43,47,
   47,47,47,53,53,53,53,53,53,59,59,59,59,59,59,61,61,67,67,67,67,67,67,71);

# For wheel-30
my @_prime_indices = (1, 7, 11, 13, 17, 19, 23, 29);
my @_nextwheel30 = (1,7,7,7,7,7,7,11,11,11,11,13,13,17,17,17,17,19,19,23,23,23,23,29,29,29,29,29,29,1);
my @_prevwheel30 = (29,29,1,1,1,1,1,1,7,7,7,7,11,11,13,13,13,13,17,17,19,19,19,19,23,23,23,23,23,23);
my @_wheeladvance30 = (1,6,5,4,3,2,1,4,3,2,1,2,1,4,3,2,1,2,1,4,3,2,1,6,5,4,3,2,1,2);
my @_wheelretreat30 = (1,2,1,2,3,4,5,6,1,2,3,4,1,2,1,2,3,4,1,2,1,2,3,4,1,2,3,4,5,6);

sub _tiny_prime_count {
  my($n) = @_;
  return if $n >= $_primes_small[-1];
  my $j = $#_primes_small;
  my $i = 1 + ($n >> 4);
  while ($i < $j) {
    my $mid = ($i+$j)>>1;
    if ($_primes_small[$mid] <= $n) { $i = $mid+1; }
    else                            { $j = $mid;   }
  }
  return $i-1;
}

sub _is_prime7 {  # n must not be divisible by 2, 3, or 5
  my($n) = @_;

  $n = _bigint_to_int($n) if ref($n) eq 'Math::BigInt' && $n <= BMAX;
  if (ref($n) eq 'Math::BigInt') {
    return 0 unless Math::BigInt::bgcd($n, B_PRIM767)->is_one;
    return 0 unless _miller_rabin_2($n);
    my $is_esl_prime = is_extra_strong_lucas_pseudoprime($n);
    return ($is_esl_prime)  ?  (($n <= "18446744073709551615") ? 2 : 1)  :  0;
  }

  if ($n < 61*61) {
    foreach my $i (qw/7 11 13 17 19 23 29 31 37 41 43 47 53 59/) {
      return 2 if $i*$i > $n;
      return 0 if !($n % $i);
    }
    return 2;
  }

  return 0 if !($n %  7) || !($n % 11) || !($n % 13) || !($n % 17) ||
              !($n % 19) || !($n % 23) || !($n % 29) || !($n % 31) ||
              !($n % 37) || !($n % 41) || !($n % 43) || !($n % 47) ||
              !($n % 53) || !($n % 59);

  # We could do:
  #   return is_strong_pseudoprime($n, (2,299417)) if $n < 19471033;
  # or:
  #   foreach my $p (@_primes_small[18..168]) {
  #     last if $p > $limit;
  #     return 0 unless $n % $p;
  #   }
  #   return 2;

  if ($n <= 1_500_000) {
    my $limit = int(sqrt($n));
    my $i = 61;
    while (($i+30) <= $limit) {
      return 0 unless ($n% $i    ) && ($n%($i+ 6)) &&
                      ($n%($i+10)) && ($n%($i+12)) &&
                      ($n%($i+16)) && ($n%($i+18)) &&
                      ($n%($i+22)) && ($n%($i+28));
      $i += 30;
    }
    for my $inc (6,4,2,4,2,4,6,2) {
      last if $i > $limit;
      return 0 if !($n % $i);
      $i += $inc;
    }
    return 2;
  }

  if ($n < 47636622961201) {   # BPSW seems to be faster after this
    # Deterministic set of Miller-Rabin tests.  If the MR routines can handle
    # bases greater than n, then this can be simplified.
    my @bases;
    # n > 1_000_000 because of the previous block.
    if    ($n <         19471033) { @bases = ( 2,  299417); }
    elsif ($n <         38010307) { @bases = ( 2,  9332593); }
    elsif ($n <        316349281) { @bases = ( 11000544, 31481107); }
    elsif ($n <       4759123141) { @bases = ( 2, 7, 61); }
    elsif ($n <     154639673381) { @bases = ( 15, 176006322, 4221622697); }
    elsif ($n <   47636622961201) { @bases = ( 2, 2570940, 211991001, 3749873356); }
    elsif ($n < 3770579582154547) { @bases = ( 2, 2570940, 880937, 610386380, 4130785767); }
    else                          { @bases = ( 2, 325, 9375, 28178, 450775, 9780504, 1795265022); }
    return is_strong_pseudoprime($n, @bases)  ?  2  :  0;
  }

  # Inlined BPSW
  return 0 unless _miller_rabin_2($n);
  return is_almost_extra_strong_lucas_pseudoprime($n) ? 2 : 0;
}

sub is_prime {
  my($n) = @_;
  return 0 if defined($n) && int($n) < 0;
  _validate_positive_integer($n);

  if (ref($n) eq 'Math::BigInt') {
    return 0 unless Math::BigInt::bgcd($n, B_PRIM235)->is_one;
  } else {
    if ($n < 7) { return ($n == 2) || ($n == 3) || ($n == 5) ? 2 : 0; }
    return 0 if !($n % 2) || !($n % 3) || !($n % 5);
  }
  return _is_prime7($n);
}

# is_prob_prime is the same thing for us.
*is_prob_prime = \&is_prime;

# BPSW probable prime.  No composites are known to have passed this test
# since it was published in 1980, though we know infinitely many exist.
# It has also been verified that no 64-bit composite will return true.
# Slow since it's all in PP and uses bigints.
sub is_bpsw_prime {
  my($n) = @_;
  return 0 if defined($n) && int($n) < 0;
  _validate_positive_integer($n);
  return 0 unless _miller_rabin_2($n);
  if ($n <= 18446744073709551615) {
    return is_almost_extra_strong_lucas_pseudoprime($n) ? 2 : 0;
  }
  return is_extra_strong_lucas_pseudoprime($n) ? 1 : 0;
}

sub is_provable_prime {
  my($n) = @_;
  return 0 if defined $n && $n < 2;
  _validate_positive_integer($n);
  if ($n <= 18446744073709551615) {
    return 0 unless _miller_rabin_2($n);
    return 0 unless is_almost_extra_strong_lucas_pseudoprime($n);
    return 2;
  }
  my($is_prime, $cert) = Math::Prime::Util::is_provable_prime_with_cert($n);
  $is_prime;
}

# Possible sieve storage:
#   1) vec with mod-30 wheel:   8 bits  / 30
#   2) vec with mod-2 wheel :  15 bits  / 30
#   3) str with mod-30 wheel:   8 bytes / 30
#   4) str with mod-2 wheel :  15 bytes / 30
#
# It looks like using vecs is about 2x slower than strs, and the strings also
# let us do some fast operations on the results.  E.g.
#   Count all primes:
#      $count += $$sieveref =~ tr/0//;
#   Loop over primes:
#      foreach my $s (split("0", $$sieveref, -1)) {
#        $n += 2 + 2 * length($s);
#        .. do something with the prime $n
#      }
#
# We're using method 4, though sadly it is memory intensive relative to the
# other methods.  I will point out that it is 30-60x less memory than sieves
# using an array, and the performance of this function is over 10x that
# of naive sieves.

sub _sieve_erat_string {
  my($end) = @_;
  $end-- if ($end & 1) == 0;
  my $s_end = $end >> 1;

  my $whole = int( $s_end / 15);   # Prefill with 3 and 5 already marked.
  croak "Sieve too large" if $whole > 1_145_324_612;  # ~32 GB string
  my $sieve = '100010010010110' . '011010010010110' x $whole;
  substr($sieve, $s_end+1) = '';   # Ensure we don't make too many entries
  my ($n, $limit) = ( 7, int(sqrt($end)) );
  while ( $n <= $limit ) {
    for (my $s = ($n*$n) >> 1; $s <= $s_end; $s += $n) {
      substr($sieve, $s, 1) = '1';
    }
    do { $n += 2 } while substr($sieve, $n>>1, 1);
  }
  return \$sieve;
}

# TODO: this should be plugged into precalc, memfree, etc. just like the C code
{
  my $primary_size_limit = 15000;
  my $primary_sieve_size = 0;
  my $primary_sieve_ref;
  sub _sieve_erat {
    my($end) = @_;

    return _sieve_erat_string($end) if $end > $primary_size_limit;

    if ($primary_sieve_size == 0) {
      $primary_sieve_size = $primary_size_limit;
      $primary_sieve_ref = _sieve_erat_string($primary_sieve_size);
    }
    my $sieve = substr($$primary_sieve_ref, 0, ($end+1)>>1);
    return \$sieve;
  }
}


sub _sieve_segment {
  my($beg,$end,$limit) = @_;
  ($beg, $end) = map { _bigint_to_int($_) } ($beg, $end)
    if ref($end) && $end <= BMAX;
  croak "Internal error: segment beg is even" if ($beg % 2) == 0;
  croak "Internal error: segment end is even" if ($end % 2) == 0;
  croak "Internal error: segment end < beg" if $end < $beg;
  croak "Internal error: segment beg should be >= 3" if $beg < 3;
  my $range = int( ($end - $beg) / 2 ) + 1;

  # Prefill with 3 and 5 already marked, and offset to the segment start.
  my $whole = int( ($range+14) / 15);
  my $startp = ($beg % 30) >> 1;
  my $sieve = substr('011010010010110', $startp) . '011010010010110' x $whole;
  # Set 3 and 5 to prime if we're sieving them.
  substr($sieve,0,2) = '00' if $beg == 3;
  substr($sieve,0,1) = '0'  if $beg == 5;
  # Get rid of any extra we added.
  substr($sieve, $range) = '';

  # If the end value is below 7^2, then the pre-sieve is all we needed.
  return \$sieve if $end < 49;

  my $sqlimit = ref($end) ? $end->copy->bsqrt() : int(sqrt($end)+0.0000001);
  $limit = $sqlimit if !defined $limit || $sqlimit < $limit;
  # For large value of end, it's a huge win to just walk primes.

  my($p, $s, $primesieveref) = (7-2, 3, _sieve_erat($limit));
  while ( (my $nexts = 1 + index($$primesieveref, '0', $s)) > 0 ) {
    $p += 2 * ($nexts - $s);
    $s = $nexts;
    my $p2 = $p*$p;
    if ($p2 < $beg) {
      my $f = 1+int(($beg-1)/$p);
      $f++ unless $f % 2;
      $p2 = $p * $f;
    }
    # With large bases and small segments, it's common to find we don't hit
    # the segment at all.  Skip all the setup if we find this now.
    if ($p2 <= $end) {
      # Inner loop marking multiples of p
      # (everything is divided by 2 to keep inner loop simpler)
      my $filter_end = ($end - $beg) >> 1;
      my $filter_p2  = ($p2  - $beg) >> 1;
      while ($filter_p2 <= $filter_end) {
        substr($sieve, $filter_p2, 1) = "1";
        $filter_p2 += $p;
      }
    }
  }
  \$sieve;
}

sub trial_primes {
  my($low,$high) = @_;
  if (!defined $high) {
    $high = $low;
    $low = 2;
  }
  _validate_positive_integer($low);
  _validate_positive_integer($high);
  return if $low > $high;
  my @primes;

  # For a tiny range, just use next_prime calls
  if (($high-$low) < 1000) {
    $low-- if $low >= 2;
    my $curprime = Mnext_prime($low);
    while ($curprime <= $high) {
      push @primes, $curprime;
      $curprime = Mnext_prime($curprime);
    }
    return \@primes;
  }

  # Sieve to 10k then BPSW test
  push @primes, 2  if ($low <= 2) && ($high >= 2);
  push @primes, 3  if ($low <= 3) && ($high >= 3);
  push @primes, 5  if ($low <= 5) && ($high >= 5);
  $low = 7 if $low < 7;
  $low++ if ($low % 2) == 0;
  $high-- if ($high % 2) == 0;
  my $sieveref = _sieve_segment($low, $high, 10000);
  my $n = $low-2;
  while ($$sieveref =~ m/0/g) {
    my $p = $n+2*pos($$sieveref);
    push @primes, $p if _miller_rabin_2($p) && is_extra_strong_lucas_pseudoprime($p);
  }
  return \@primes;
}

sub primes {
  my($low,$high) = @_;
  if (scalar @_ > 1) {
    _validate_positive_integer($low);
    _validate_positive_integer($high);
    $low = 2 if $low < 2;
  } else {
    ($low,$high) = (2, $low);
    _validate_positive_integer($high);
  }
  my $sref = [];
  return $sref if ($low > $high) || ($high < 2);
  return [grep { $_ >= $low && $_ <= $high } @_primes_small]
    if $high <= $_primes_small[-1];

  return [ Math::Prime::Util::GMP::sieve_primes($low, $high, 0) ]
    if $Math::Prime::Util::_GMPfunc{"sieve_primes"} && $Math::Prime::Util::GMP::VERSION >= 0.34;

  # At some point even the pretty-fast pure perl sieve is going to be a
  # dog, and we should move to trials.  This is typical with a small range
  # on a large base.  More thought on the switchover should be done.
  return trial_primes($low, $high) if ref($low)  eq 'Math::BigInt'
                                   || ref($high) eq 'Math::BigInt'
                                   || ($low > 1_000_000_000_000 && ($high-$low) < int($low/1_000_000));

  push @$sref, 2  if ($low <= 2) && ($high >= 2);
  push @$sref, 3  if ($low <= 3) && ($high >= 3);
  push @$sref, 5  if ($low <= 5) && ($high >= 5);
  $low = 7 if $low < 7;
  $low++ if ($low % 2) == 0;
  $high-- if ($high % 2) == 0;
  return $sref if $low > $high;

  my($n,$sieveref);
  if ($low == 7) {
    $n = 0;
    $sieveref = _sieve_erat($high);
    substr($$sieveref,0,3,'111');
  } else {
    $n = $low-1;
    $sieveref = _sieve_segment($low,$high);
  }
  push @$sref, $n+2*pos($$sieveref)-1 while $$sieveref =~ m/0/g;
  $sref;
}

sub sieve_range {
  my($n, $width, $depth) = @_;
  _validate_positive_integer($n);
  _validate_positive_integer($width);
  _validate_positive_integer($depth);

  my @candidates;
  my $start = $n;

  if ($n < 5) {
    push @candidates, (2-$n) if $n <= 2 && $n+$width-1 >= 2;
    push @candidates, (3-$n) if $n <= 3 && $n+$width-1 >= 3;
    push @candidates, (4-$n) if $n <= 4 && $n+$width-1 >= 4 && $depth < 2;
    $start = 5;
    $width -= ($start - $n);
  }

  return @candidates, map {$start+$_-$n } 0 .. $width-1 if $depth < 2;
  return @candidates, map { $_ - $n }
                      grep { ($_ & 1) && ($depth < 3 || ($_ % 3)) }
                      map { $start+$_ }
                      0 .. $width-1                     if $depth < 5;

  if (!($start & 1)) { $start++; $width--; }
  $width-- if !($width&1);
  return @candidates if $width < 1;

  my $sieveref = _sieve_segment($start, $start+$width-1, $depth);
  my $offset = $start - $n - 2;
  while ($$sieveref =~ m/0/g) {
    push @candidates, $offset + (pos($$sieveref) << 1);
  }
  return @candidates;
}

sub sieve_prime_cluster {
  my($lo,$hi,@cl) = @_;
  my $_verbose = Math::Prime::Util::prime_get_config()->{'verbose'};
  _validate_positive_integer($lo);
  _validate_positive_integer($hi);

  if ($Math::Prime::Util::_GMPfunc{"sieve_prime_cluster"}) {
    return map { ($_ > ''.~0) ? Math::BigInt->new(''.$_) : $_ }
           Math::Prime::Util::GMP::sieve_prime_cluster($lo,$hi,@cl);
  }

  return @{primes($lo,$hi)} if scalar(@cl) == 0;

  unshift @cl, 0;
  for my $i (1 .. $#cl) {
    _validate_positive_integer($cl[$i]);
    croak "sieve_prime_cluster: values must be even" if $cl[$i] & 1;
    croak "sieve_prime_cluster: values must be increasing" if $cl[$i] <= $cl[$i-1];
  }
  my($p,$sievelim,@p) = (17, 2000);
  $p = 13 if ($hi-$lo) < 50_000_000;
  $p = 11 if ($hi-$lo) <  1_000_000;
  $p =  7 if ($hi-$lo) <     20_000 && $lo < INTMAX;

  # Add any cases under our sieving point.
  if ($lo <= $sievelim) {
    $sievelim = $hi if $sievelim > $hi;
    for my $n (@{primes($lo,$sievelim)}) {
      my $ac = 1;
      for my $ci (1 .. $#cl) {
        if (!Mis_prime($n+$cl[$ci])) { $ac = 0; last; }
      }
      push @p, $n if $ac;
    }
    $lo = Mnext_prime($sievelim);
  }
  return @p if $lo > $hi;

  # Compute acceptable residues.
  my $pr = Mprimorial($p);
  my $startpr = _bigint_to_int($lo % $pr);

  my @acc = grep { ($_ & 1) && $_%3 }  ($startpr .. $startpr + $pr - 1);
  for my $c (@cl) {
    if ($p >= 7) {
      @acc = grep { (($_+$c)%3) && (($_+$c)%5) && (($_+$c)%7) } @acc;
    } else {
      @acc = grep { (($_+$c)%3)  && (($_+$c)%5) } @acc;
    }
  }
  for my $c (@cl) {
    @acc = grep { Mgcd($_+$c,$pr) == 1 } @acc;
  }
  @acc = map { $_-$startpr } @acc;

  print "cluster sieve using ",scalar(@acc)," residues mod $pr\n" if $_verbose;
  return @p if scalar(@acc) == 0;

  # Prepare table for more sieving.
  my @mprimes = @{primes( $p+1, $sievelim)};
  my @vprem;
  for my $p (@mprimes) {
    for my $c (@cl) {
      $vprem[$p]->[ ($p-($c%$p)) % $p ] = 1;
    }
  }

  # Walk the range in primorial chunks, doing primality tests.
  my($nummr, $numlucas) = (0,0);
  while ($lo <= $hi) {

    my @racc = @acc;

    # Make sure we don't do anything past the limit
    if (($lo+$acc[-1]) > $hi) {
      my $max = _bigint_to_int($hi-$lo);
      @racc = grep { $_ <= $max } @racc;
    }

    # Sieve more values using native math
    foreach my $p (@mprimes) {
      my $rem = _bigint_to_int( $lo % $p );
      @racc = grep { !$vprem[$p]->[ ($rem+$_) % $p ] } @racc;
      last unless scalar(@racc);
    }

    # Do final primality tests.
    if ($lo < 1e13) {
      for my $r (@racc) {
        my($good, $p) = (1, $lo + $r);
        for my $c (@cl) {
          $nummr++;
          if (!Mis_prime($p+$c)) { $good = 0; last; }
        }
        push @p, $p if $good;
      }
    } else {
      for my $r (@racc) {
        my($good, $p) = (1, $lo + $r);
        for my $c (@cl) {
          $nummr++;
          if (!Math::Prime::Util::is_strong_pseudoprime($p+$c,2)) { $good = 0; last; }
        }
        next unless $good;
        for my $c (@cl) {
          $numlucas++;
          if (!Math::Prime::Util::is_extra_strong_lucas_pseudoprime($p+$c)) { $good = 0; last; }
        }
        push @p, $p if $good;
      }
    }

    $lo += $pr;
  }
  print "cluster sieve ran $nummr MR and $numlucas Lucas tests\n" if $_verbose;
  @p;
}

sub prime_powers {
  my($low,$high) = @_;
  if (scalar @_ > 1) {
    _validate_positive_integer($low);
    _validate_positive_integer($high);
    $low = 2 if $low < 2;
  } else {
    ($low,$high) = (2, $low);
    _validate_positive_integer($high);
  }
  my $sref = [];
  while ($low <= $high) {
    push @$sref, $low if Math::Prime::Util::is_prime_power($low);
    $low = Maddint($low, 1);
  }
  $sref;
}

sub _n_ramanujan_primes {
  my($n) = @_;
  return [] if $n <= 0;
  my $max = nth_prime_upper(int(48/19*$n)+1);
  my @L = (2, (0) x $n-1);
  my $s = 1;
  for (my $k = 7; $k <= $max; $k += 2) {
    $s++ if Mis_prime($k);
    $L[$s] = $k+1 if $s < $n;
    $s-- if ($k&3) == 1 && Mis_prime(($k+1)>>1);
    $L[$s] = $k+2 if $s < $n;
  }
  \@L;
}

sub _ramanujan_primes {
  my($low,$high) = @_;
  ($low,$high) = (2, $low) unless defined $high;
  return [] if ($low > $high) || ($high < 2);
  my $nn = prime_count_upper($high) >> 1;
  my $L = _n_ramanujan_primes($nn);
  shift @$L while @$L && $L->[0] < $low;
  pop @$L while @$L && $L->[-1] > $high;
  $L;
}

sub is_ramanujan_prime {
  my($n) = @_;
  return 1 if $n == 2;
  return 0 if $n < 11;
  my $L = _ramanujan_primes($n,$n);
  return (scalar(@$L) > 0) ? 1 : 0;
}

sub nth_ramanujan_prime {
  my($n) = @_;
  return undef if $n <= 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  my $L = _n_ramanujan_primes($n);
  return $L->[$n-1];
}

sub next_prime {
  my($n) = @_;
  _validate_positive_integer($n);
  return $_prime_next_small[$n] if $n <= $#_prime_next_small;
  # This turns out not to be faster.
  # return $_primes_small[1+_tiny_prime_count($n)] if $n < $_primes_small[-1];

  return Math::BigInt->new(MPU_32BIT ? "4294967311" : "18446744073709551629")
    if ref($n) ne 'Math::BigInt' && $n >= MPU_MAXPRIME;
  # n is now either 1) not bigint and < maxprime, or (2) bigint and >= uvmax

  if ($n > 4294967295 && Math::Prime::Util::prime_get_config()->{'gmp'}) {
    return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::next_prime($n));
  }

  if (ref($n) eq 'Math::BigInt') {
    do {
      $n += $_wheeladvance30[$n%30];
    } while !Math::BigInt::bgcd($n, B_PRIM767)->is_one ||
            !_miller_rabin_2($n) || !is_extra_strong_lucas_pseudoprime($n);
  } else {
    do {
      $n += $_wheeladvance30[$n%30];
    } while !($n%7) || !_is_prime7($n);
  }
  $n;
}

sub prev_prime {
  my($n) = @_;
  _validate_positive_integer($n);
  return (undef,undef,undef,2,3,3,5,5,7,7,7,7)[$n] if $n <= 11;
  if ($n > 4294967295 && Math::Prime::Util::prime_get_config()->{'gmp'}) {
    return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::prev_prime($n));
  }

  if (ref($n) eq 'Math::BigInt') {
    do {
      $n -= $_wheelretreat30[$n%30];
    } while !Math::BigInt::bgcd($n, B_PRIM767)->is_one ||
            !_miller_rabin_2($n) || !is_extra_strong_lucas_pseudoprime($n);
  } else {
    do {
      $n -= $_wheelretreat30[$n%30];
    } while !($n%7) || !_is_prime7($n);
  }
  $n;
}

sub next_prime_power {
  my($n) = @_;
  _validate_positive_integer($n);
  return (2,2,3,4,5,7,7,8,9)[$n] if $n <= 8;
  while (1) {
    $n = Maddint($n, 1);
    return $n if is_prime_power($n);
  }
}
sub prev_prime_power {
  my($n) = @_;
  _validate_positive_integer($n);
  return (undef,undef,undef,2,3,4,5,5,7)[$n] if $n <= 8;
  while (1) {
    $n = Msubint($n, 1);
    return $n if is_prime_power($n);
  }
}

sub partitions {
  my $n = shift;

  my $d = int(sqrt($n+1));
  my @pent = (1, map { (($_*(3*$_+1))>>1, (($_+1)*(3*$_+2))>>1) } 1 .. $d);
  my $ZERO = ($n >= ((~0 > 4294967295) ? 400 : 270)) ? BZERO : 0;
  my @part = ($ZERO+1);
  foreach my $j (scalar @part .. $n) {
    my ($psum1, $psum2, $k) = ($ZERO, $ZERO, 1);
    foreach my $p (@pent) {
      last if $p > $j;
      if ((++$k) & 2) { $psum1 += $part[ $j - $p ] }
      else            { $psum2 += $part[ $j - $p ] }
    }
    $part[$j] = $psum1 - $psum2;
  }
  return $part[$n];
}

my @_lf63 = (0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,0,0,1,0,0,1,1,1,1,0,0,1,0,0,1,0,0,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,1,1,1,0,0);

sub lucky_numbers {
  my $n = shift;
  return [] if $n <= 0;

  my @lucky;
  # This wheel handles the evens and every 3rd by a mod 6 wheel,
  # then uses the mask to skip every 7th and 9th remaining value.
  for (my $k = 1;  $k <= $n;  $k += 6) {
    my $m63 = $k % 63;
    push @lucky, $k unless $_lf63[$m63];
    push @lucky, $k+2 unless $_lf63[$m63+2];
  }
  delete $lucky[-1] if $lucky[-1] > $n;

  # Do the standard lucky sieve.
  for (my $k = 4; $k <= $#lucky && $lucky[$k]-1 <= $#lucky; $k++) {
    for (my $skip = my $index = $lucky[$k]-1;  $index <= $#lucky;  $index += $skip) {
      splice(@lucky, $index, 1);
    }
  }
  \@lucky;
}
sub nth_lucky {
  my $n = shift;
  return (undef,1,3,7,9)[$n] if $n <= 4;
  my $k = $n-1;
  my $l = lucky_numbers($n);
  shift @$l;
  $k += int($k / ($_-1)) for reverse @$l;
  2*$k+1;
}
sub is_lucky {
  my $n = shift;

  # Pretests
  return 0 if $n <= 0 || !($n % 2) || ($n % 6) == 5 || $_lf63[$n % 63];
  return 1 if $n < 45;

  # Really simple but slow:
  # return lucky_numbers($n)->[-1] == $n;

  my $upper = int(200 + 0.994 * $n / log($n));
  my $lucky = lucky_numbers($upper);
  my $pos = ($n+1) >> 1;
  my $i = 1;
  while (1) {
    my $l = ($i <= $#$lucky) ? $lucky->[$i++] : nth_lucky($i++);
    return 1 if $pos < $l;
    my $quo = int($pos / $l);
    return 0 if $pos == $quo * $l;
    $pos -= $quo;
  }
}

sub primorial {
  my $n = shift;

  my @plist = @{primes($n)};
  my $max = (MPU_32BIT) ? 29 : (OLD_PERL_VERSION) ? 43 : 53;

  # If small enough, multiply the small primes.
  if ($n < $max) {
    my $pn = 1;
    $pn *= $_ for @plist;
    return $pn;
  }

  # Otherwise, combine them as UVs, then combine using product tree.
  my $i = 0;
  while ($i < $#plist) {
    my $m = $plist[$i] * $plist[$i+1];
    if ($m <= INTMAX) { splice(@plist, $i, 2, $m); }
    else              { $i++;                      }
  }
  Mvecprod(@plist);
}

sub pn_primorial {
  my $n = shift;
  return (1,2,6,30,210,2310,30030,510510,9699690,223092870)[$n] if $n < 10;
  Mprimorial(nth_prime($n));
}

sub consecutive_integer_lcm {
  my $n = shift;

  my $max = (MPU_32BIT) ? 22 : (OLD_PERL_VERSION) ? 37 : 46;
  my $pn = ref($n) ? ref($n)->new(1) : ($n >= $max) ? Math::BigInt->bone() : 1;
  for (my $p = 2; $p <= $n; $p = Mnext_prime($p)) {
    my($p_power, $pmin) = ($p, int($n/$p));
    $p_power *= $p while $p_power <= $pmin;
    $pn *= $p_power;
  }
  $pn = _bigint_to_int($pn) if $pn <= BMAX;
  return $pn;
}

sub jordan_totient {
  my($k, $n) = @_;
  return ($n == 1) ? 1 : 0  if $k == 0;
  return euler_phi($n)      if $k == 1;
  return ($n == 1) ? 1 : 0  if $n <= 1;

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::jordan_totient($k, $n))
    if $Math::Prime::Util::_GMPfunc{"jordan_totient"};


  my @pe = Mfactor_exp($n);
  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  my $totient = BONE->copy;
  foreach my $f (@pe) {
    my ($p, $e) = @$f;
    $p = Math::BigInt->new("$p")->bpow($k);
    $totient->bmul($p->copy->bdec());
    $totient->bmul($p) for 2 .. $e;
  }
  $totient = _bigint_to_int($totient) if $totient->bacmp(BMAX) <= 0;
  return $totient;
}

sub euler_phi {
  return euler_phi_range(@_) if scalar @_ > 1;
  my($n) = @_;
  return 0 if defined $n && $n < 0;

  return Math::Prime::Util::_reftyped($_[0],Math::Prime::Util::GMP::totient($n))
    if $Math::Prime::Util::_GMPfunc{"totient"};

  _validate_positive_integer($n);
  return $n if $n <= 1;

  my $totient = $n - $n + 1;

  # Fast reduction of multiples of 2, may also reduce n for factoring
  if (ref($n) eq 'Math::BigInt') {
    my $s = 0;
    if ($n->is_even) {
      do { $n->brsft(BONE); $s++; } while $n->is_even;
      $totient->blsft($s-1) if $s > 1;
    }
  } else {
    while (($n % 4) == 0) { $n >>= 1;  $totient <<= 1; }
    if (($n % 2) == 0) { $n >>= 1; }
  }

  my @pe = Mfactor_exp($n);

  if ($#pe == 0 && $pe[0]->[1] == 1) {
    if (ref($n) ne 'Math::BigInt') { $totient *= $n-1; }
    else                           { $totient->bmul($n->bdec()); }
  } elsif (ref($n) ne 'Math::BigInt') {
    foreach my $f (@pe) {
      my ($p, $e) = @$f;
      $totient *= $p - 1;
      $totient *= $p for 2 .. $e;
    }
  } else {
    my $zero = $n->copy->bzero;
    foreach my $f (@pe) {
      my ($p, $e) = @$f;
      $p = $zero->copy->badd("$p");
      $totient->bmul($p->copy->bdec());
      $totient->bmul($p) for 2 .. $e;
    }
  }
  $totient = _bigint_to_int($totient) if ref($totient) eq 'Math::BigInt'
                                      && $totient->bacmp(BMAX) <= 0;
  return $totient;
}

sub inverse_totient {
  my($n) = @_;
  _validate_positive_integer($n);

  return wantarray ? (1,2) : 2 if $n == 1;
  return wantarray ? () : 0 if $n < 1 || ($n & 1);

  $n = Math::Prime::Util::_to_bigint("$n") if !ref($n) && $n > 2**49;
  my $do_bigint = ref($n);

  if (Mis_prime($n >> 1)) {   # Coleman Remark 3.3 (Thm 3.1) and Prop 6.2
    return wantarray ? () : 0             if !Mis_prime($n+1);
    return wantarray ? ($n+1, 2*$n+2) : 2 if $n >= 10;
  }

  if (!wantarray) {
    my %r = ( 1 => 1 );
    Mfordivisors(sub { my $d = $_;
      $d = $do_bigint->new("$d") if $do_bigint;
      my $p = $d+1;
      if (Mis_prime($p)) {
        my($dp,@sumi,@sumv) = ($d);
        for my $v (1 .. 1 + Mvaluation($n, $p)) {
          Mfordivisors(sub { my $d2 = $_;
            if (defined $r{$d2}) { push @sumi, $d2*$dp; push @sumv, $r{$d2}; }
          }, $n / $dp);
          $dp *= $p;
        }
        $r{ $sumi[$_] } += $sumv[$_]  for 0 .. $#sumi;
      }
    }, $n);
    return (defined $r{$n}) ? $r{$n} : 0;
  } else {
    my %r = ( 1 => [1] );
    Mfordivisors(sub { my $d = $_;
      $d = $do_bigint->new("$d") if $do_bigint;
      my $p = $d+1;
      if (Mis_prime($p)) {
        my($dp,$pp,@T) = ($d,$p);
        for my $v (1 .. 1 + Mvaluation($n, $p)) {
          Mfordivisors(sub { my $d2 = $_;
            push @T, [ $d2*$dp, [map { $_ * $pp } @{ $r{$d2} }] ] if defined $r{$d2};
          }, $n / $dp);
          $dp *= $p;
          $pp *= $p;
        }
        push @{$r{$_->[0]}}, @{$_->[1]} for @T;
      }
    }, $n);
    return () unless defined $r{$n};
    delete @r{ grep { $_ != $n } keys %r };  # Delete all intermediate results
    my @result = sort { $a <=> $b } @{$r{$n}};
    return @result;
  }
}

sub euler_phi_range {
  my($lo, $hi) = @_;
  _validate_integer($lo);
  _validate_integer($hi);

  my @totients;
  while ($lo < 0 && $lo <= $hi) {
    push @totients, 0;
    $lo++;
  }
  return @totients if $hi < $lo;

  if ($hi > 2**30 || $hi-$lo < 100) {
    while ($lo <= $hi) {
      push @totients, euler_phi($lo++);
    }
  } else {
    my @tot = (0 .. $hi);
    foreach my $i (2 .. $hi) {
      next unless $tot[$i] == $i;
      $tot[$i] = $i-1;
      foreach my $j (2 .. int($hi / $i)) {
        $tot[$i*$j] -= $tot[$i*$j]/$i;
      }
    }
    splice(@tot, 0, $lo) if $lo > 0;
    push @totients, @tot;
  }
  @totients;
}

sub prime_bigomega {
  return scalar(Mfactor($_[0]));
}
sub prime_omega {
  return scalar(Mfactor_exp($_[0]));
}

sub moebius {
  return moebius_range(@_) if scalar @_ > 1;
  my($n) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_num($n) || _validate_positive_integer($n);
  return ($n == 1) ? 1 : 0  if $n <= 1;
  return 0 if ($n >= 49) && (!($n % 4) || !($n % 9) || !($n % 25) || !($n%49) );
  my @factors = Mfactor($n);
  foreach my $i (1 .. $#factors) {
    return 0 if $factors[$i] == $factors[$i-1];
  }
  return ((scalar @factors) % 2) ? -1 : 1;
}
sub is_square_free {
  return (Mmoebius($_[0]) != 0) ? 1 : 0;
}

sub is_smooth {
  my($n, $k) = @_;
  _validate_positive_integer($n);
  _validate_positive_integer($k);

  return 1 if $n <= 1;
  return 0 if $k <= 1;
  return 1 if $n <= $k;

  return _gmpcall("is_smooth",$n,$k)
    if $Math::Prime::Util::_GMPfunc{"is_smooth"};

  if ($k <= 10000000 && $Math::Prime::Util::_GMPfunc{"trial_factor"}) {
    my @f;
    while (1) {
      @f = Math::Prime::Util::GMP::trial_factor($n, $k);
      last if scalar(@f) <= 1;
      return 0 if $f[-2] > $k;
      $n = $f[-1];
    }
    return 0 + ($f[0] <= $k);
  }

  return (Mvecnone(sub { $_ > $k }, Mfactor($n))) ? 1 : 0;
}
sub is_rough {
  my($n, $k) = @_;
  _validate_positive_integer($n);
  _validate_positive_integer($k);

  return 0+($k == 0) if $n == 0;
  return 1 if $n == 1;
  return 1 if $k <= 1;
  return 0+($n >= 1) if $k == 2;

  return _gmpcall("is_rough",$n,$k)
    if $Math::Prime::Util::_GMPfunc{"is_rough"};

  if ($k < 10000 && $Math::Prime::Util::_GMPfunc{"trial_factor"}) {
    my @f = Math::Prime::Util::GMP::trial_factor($n, $k);
    return 0 + ($f[0] >= $k);
  }

  return (Mvecnone(sub { $_ < $k }, Mfactor($n))) ? 1 : 0;
}
sub is_powerful {
  my($n, $k) = @_;
  _validate_positive_integer($n);
  if (defined $k && $k != 0) {
    _validate_positive_integer($k);
  } else {
    $k = 2;
  }

  return 1 if $n <= 1 || $k <= 1;

  return _gmpcall("is_powerful",$n,$k)
    if $Math::Prime::Util::_GMPfunc{"is_powerful"};

  # First quick checks for inadmissibility.
  if ($k == 2) {
    return 0 if ($n%3)  == 0 && ($n%9) != 0;
    return 0 if ($n%5)  == 0 && ($n%25) != 0;
    return 0 if ($n%7)  == 0 && ($n%49) != 0;
    return 0 if ($n%11) == 0 && ($n%121) != 0;
  } else {
    return 0 if ($n%3)  == 0 && ($n%27) != 0;
    return 0 if ($n%5)  == 0 && ($n%125) != 0;
    return 0 if ($n%7)  == 0 && ($n%343) != 0;
    return 0 if ($n%11) == 0 && ($n%1331) != 0;
  }

  # Next, check and remove all primes under 149 with three 64-bit gcds.
  for my $GCD ("614889782588491410","3749562977351496827","4343678784233766587") {
    my $g = Mgcd($n, $GCD);
    if ($g != 1) {
      # Check anything that divides n also divides k times (and remove).
      my $gk = Mpowint($g, $k);
      return 0 if ($n % $gk) != 0;
      $n = Mdivint($n, $gk);
      # Now remove any possible further amounts of these divisors.
      $g = Mgcd($n, $g);
      while ($n > 1 && $g > 1) {
        $n = Mdivint($n, $g);
        $g = Mgcd($n, $g);
      }
      return 1 if $n == 1;
    }
  }

  # For small primes, check for perfect powers and thereby limit the search
  # to divisibiilty conditions on primes less than n^(1/(2k)).  This is
  # usually faster than full factoring.
  #
  # But ... it's possible this will take far too long (e.g. n=2^256+1).  So
  # limit to something reasonable.

  return 1 if $n == 1 || is_power($n) >= $k;
  return 0 if $n < Mpowint(149, 2*$k);

  my $lim_actual = Mrootint($n, 2*$k);
  my $lim_effect = ($lim_actual > 10000) ? 10000 : $lim_actual;

  if ($Math::Prime::Util::_GMPfunc{"trial_factor"}) {
    while (1) {
      my @fac = Math::Prime::Util::GMP::trial_factor($n, $lim_effect);
      last if scalar(@fac) <= 1;
      my $f = $fac[0];
      my $fk = ($k==2) ? $f*$f : Mpowint($f,$k);
      return 0 if ($n % $fk) != 0;
      $n = Mdivint($n, $fk);
      $n = Mdivint($n, $f) while !($n % $f);
      return 1 if $n == 1 || is_power($n) >= $k;
      return 0 if $n < $fk*$fk;
    }
  } else {
    Mforprimes( sub {
      my $pk = ($k==2) ? $_*$_ : Mpowint($_,$k);
      Math::Prime::Util::lastfor(),return if $n < $pk*$pk;
      if (($n%$_) == 0) {
        Math::Prime::Util::lastfor(),return if ($n % $pk) != 0;
        $n = Mdivint($n, $pk);
        $n = Mdivint($n, $_) while ($n % $_) == 0;
        Math::Prime::Util::lastfor(),return if $n == 1 || is_power($n) >= $k;
      }
    }, 149, $lim_effect);
  }
  return 1 if $n == 1 || is_power($n) >= $k;
  return 0 if $n <= Mpowint($lim_effect, 2*$k);

  # Taking too long.  Factor what is left.
  return (Mvecall(sub { $_->[1] >= $k }, Mfactor_exp($n))) ? 1 : 0;
}

sub _powerful_count_recurse {
  my($n, $k, $m, $r) = @_;
  my $lim = Mrootint(Mdivint($n, $m), $r);

  return $lim if $r <= $k;

  my $sum = 0;
  for my $i (1 .. $lim) {
    if (Mgcd($m,$i) == 1 && Math::Prime::Util::is_square_free($i)) {
      $sum += _powerful_count_recurse($n, $k, Mmulint($m, Mpowint($i,$r)), $r-1)
    }
  }
  $sum;
}

sub powerful_count {
  my($n, $k) = @_;
  _validate_positive_integer($n);
  if (defined $k && $k != 0) {
    _validate_positive_integer($k);
  } else {
    $k = 2;
  }

  return $n if $k == 1 || $n <= 1;

  if ($k == 2) {
    my $sum = 0;
    for my $i (1 .. Mrootint($n,3)) {
      $sum += Msqrtint(Mdivint($n,Mpowint($i,3)))
        if Math::Prime::Util::is_square_free($i);
    }
    return $sum;
  }

  _powerful_count_recurse($n, $k, 1, 2*$k-1);
}

sub nth_powerful {
  my($n, $k) = @_;
  _validate_positive_integer($n);
  if (defined $k && $k != 0) {
    _validate_positive_integer($k);
  } else {
    $k = 2;
  }
  return undef if $n == 0;
  return $n if $k == 1 || $n <= 1;
  return Mpowint(2,$k) if $n == 2;
  return Mpowint(2,$k+1) if $n == 3;

  # For small n, we can generate k-powerful numbers rapidly.  But without
  # a reasonable upper limit, it's not clear how to effectively do it.
  # E.g. nth_powerful(100,60) = 11972515182562019788602740026717047105681

  my $lo = Mpowint(2, $k+1);
  my $hi = ~0;
  if ($k == 2) {
    $lo = int( $n*$n/4.72303430688484 + 0.3 * $n**(5/3) );
    $hi = int( $n*$n/4.72303430688484 + 0.5 * $n**(5/3) );  # for n >= 170
    $hi = ~0 if $hi > ~0;
    $lo = $hi >> 1 if $lo > $hi;
  }

  # hi could be too low.
  while (Math::Prime::Util::powerful_count($hi,$k) < $n) {
    $lo = $hi+1;
    $hi = Mmulint($k, $hi);
  }

  # Simple binary search
  while ($lo < $hi) {
    my $mid = $lo + (($hi-$lo) >> 1);
    if (Math::Prime::Util::powerful_count($mid,$k) < $n) { $lo = $mid+1; }
    else                                                 { $hi = $mid; }
  }
  $hi;
}

sub is_powerfree {
  my($n, $k) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_positive_integer($n);
  if (defined $k) { _validate_positive_integer($k); }
  else            { $k = 2; }

  return (($n == 1) ? 1 : 0)  if $k < 2 || $n <= 1;
  #return 1 if $n < Mpowint(2,$k);
  return 1 if $n < 4;

  if ($k == 2) {
    return 0 if !($n % 4) || !($n % 9) || !($n % 25);
    return 1 if $n < 49;   # 7^2
  } elsif ($k == 3) {
    return 0 if !($n % 8) || !($n % 27) || !($n % 125);
    return 1 if $n < 343;  # 7^3
  }

  # return (Mvecall(sub { $_->[1] < $k }, Mfactor_exp($n))) ? 1 : 0;
  for my $pe (Mfactor_exp($n)) {
    return 0 if $pe->[1] >= $k;
  }
  1;
}

sub powerfree_count {
  my($n, $k) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_positive_integer($n);
  if (defined $k) { _validate_positive_integer($k); }
  else            { $k = 2; }

  return (($n >= 1) ? 1 : 0)  if $k < 2 || $n <= 1;

  my $count = $n;
  my $nk = Mrootint($n, $k);

  if ($nk < 100 || $nk > 1e8) {
    Math::Prime::Util::forsquarefree(
      sub {
        $count += ((scalar(@_) & 1) ? -1 : 1) * Mdivint($n, Mpowint($_, $k));
      },
      2, $nk
    );
  } else {
    my @mu = (0, Mmoebius(1, $nk));
    foreach my $i (2 .. $nk) {
      next if $mu[$i] == 0;
      $count += $mu[$i] * Mdivint($n, Mpowint($i, $k));
    }
  }
  $count;
}

sub powerfree_sum {
  my($n, $k) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_positive_integer($n);
  if (defined $k) { _validate_positive_integer($k); }
  else            { $k = 2; }

  return (($n >= 1) ? 1 : 0)  if $k < 2 || $n <= 1;

  my $sum = 0;
  my($ik, $nik, $T);
  Math::Prime::Util::forsquarefree(
    sub {
      $ik = Mpowint($_, $k);
      $nik = Mdivint($n, $ik);
      $T = Mrshiftint(Mmulint($nik, Maddint($nik,1)), 1);
      $sum = Maddint($sum, ((scalar(@_) & 1) ? -1 : 1) * Mmulint($ik, $T));
    },
    Mrootint($n, $k)
  );
  $sum;
}

sub powerfree_part {
  my($n, $k) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_positive_integer($n);
  if (defined $k) { _validate_positive_integer($k); }
  else            { $k = 2; }

  return (($n == 1) ? 1 : 0)  if $k < 2 || $n <= 1;

  #return Mvecprod(map { Mpowint($_->[0], $_->[1] % $k) } Mfactor_exp($n));

  # Rather than build with k-free section, we will remove excess powers
  my $P = $n;
  for my $pe (Mfactor_exp($n)) {
    if ($pe->[1] >= $k) {
      $P = Mdivint($P, Mpowint($pe->[0], $pe->[1] - ($pe->[1] % $k)));
    }
  }
  $P;
}

sub _T {
  my($n)=shift;
  Mdivint(Mmulint($n, Maddint($n, 1)), 2);
}
sub _fprod {
  my($n,$k)=@_;
  Mvecprod(map { 1 - Mpowint($_->[0], $k) } Mfactor_exp($n));
}

sub powerfree_part_sum {
  my($n, $k) = @_;
  $n = -$n if defined $n && $n < 0;
  _validate_positive_integer($n);
  if (defined $k) { _validate_positive_integer($k); }
  else            { $k = 2; }

  return (($n >= 1) ? 1 : 0)  if $k < 2 || $n <= 1;

  my $sum = _T($n);
  for (2 .. Mrootint($n,$k)) {
    $sum = Maddint($sum, Mmulint(_fprod($_,$k), _T(Mdivint($n, Mpowint($_, $k)))));
  }
  $sum;
}

sub perfect_power_count {
  my($n) = @_;
  _validate_positive_integer($n);
  return $n if $n <= 1;
  my @T = (1);

  my $log2n = Mlogint($n,2);
  for my $k (2 .. $log2n) {
    my $m = Mmoebius($k);
    next if $m == 0;
    push @T, Mmulint(-$m, Msubint(Mrootint($n,$k),1));
  }
  Mvecsum(@T);
}

sub prime_power_count {
  my($n) = @_;
  _validate_positive_integer($n);
  return 0 if $n == 0;
  return $n-1 if $n <= 5;

  Mvecsum(
    map { Mprime_count( Mrootint($n, $_)) }  1 .. Mlogint($n,2)
  );
}

sub smooth_count {
  my($n, $k) = @_;
  return 0 if $n < 1;
  return 1 if $k <= 1;
  return $n if $k >= $n;

  my $sum = 1 + Mlogint($n,2);
  if ($k >= 3) {
    my $n3 = Mdivint($n, 3);
    while ($n3 > 3) {
      $sum += 1 + Mlogint($n3,2);
      $n3 = Mdivint($n3, 3);
    }
    $sum += $n3;
  }
  if ($k >= 5) {
    my $n5 = Mdivint($n, 5);
    while ($n5 > 5) {
      $sum += 1 + Mlogint($n5,2);
      my $n3 = Mdivint($n5, 3);
      while ($n3 > 3) {
        $sum += 1 + Mlogint($n3,2);
        $n3 = Mdivint($n3, 3);
      }
      $sum += $n3;
      $n5 = Mdivint($n5, 5);
    }
    $sum += $n5;
  }
  my $p = 7;
  while ($p <= $k) {
    my $np = Mdivint($n, $p);
    $sum += ($p >= $np) ? $np : Math::Prime::Util::smooth_count($np, $p);
    $p = Mnext_prime($p);
  }
  $sum;
}

sub rough_count {
  my($n, $k) = @_;
  return $n if $k <= 2;
  return $n-($n>>1) if $k <= 3;
  Math::Prime::Util::legendre_phi($n, Mprime_count($k-1));
}

sub almost_primes {
  my($k, $low, $high) = @_;

  my $minlow = Mpowint(2,$k);
  $low = $minlow if $low < $minlow;
  return [] unless $low <= $high;

  my $ap = [];
  Math::Prime::Util::forfactored(
    sub { push @$ap, $_ if scalar(@_) == $k; },
    $low, $high
  );
  $ap;
}

sub _rec_omega_primes {
  my($k, $lo, $hi, $m, $p, $opl) = @_;
  my $s = Mrootint(Mdivint($hi, $m), $k);
  foreach my $q (@{primes($p, $s)}) {
    next if Mmodint($m,$q) == 0;
    for (my $v = Mmulint($m, $q); $v <= $hi ; $v = Mmulint($v, $q)) {
      if ($k == 1) {
        push @$opl, $v  if $v >= $lo;
      } else {
        _rec_omega_primes($k-1,$lo,$hi,$v,$q,$opl)  if Mmulint($v,$q) <= $hi;
      }
    }
  }
}

sub omega_primes {
  my($k, $low, $high) = @_;

  $low = Mvecmax($low, Mpn_primorial($k));
  return [] unless $low <= $high;
  return ($low <= 1 && $high >= 1) ? [1] : []  if $k == 0;

  my @opl;

  # Simple iteration
  #  while ($low <= $high) {
  #    push @opl, $low if Math::Prime::Util::prime_omega($low) == $k;
  #    $low++;
  #  }

  # Recursive method from trizen
  _rec_omega_primes($k, $low, $high, 1, 2, \@opl);
  @opl = sort { $a <=> $b } @opl;

  \@opl;
}

sub is_semiprime {
  my($n) = @_;
  _validate_positive_integer($n);
  return ($n == 4) if $n < 6;
  if ($n > 15) {
    return 0 if ($n %  4) == 0 || ($n %  6) == 0 || ($n %  9) == 0
             || ($n % 10) == 0 || ($n % 14) == 0 || ($n % 15) == 0;
  }
  return (Math::Prime::Util::is_prob_prime($n>>1) ? 1 : 0) if ($n % 2) == 0;
  return (Math::Prime::Util::is_prob_prime($n/3)  ? 1 : 0) if ($n % 3) == 0;
  return (Math::Prime::Util::is_prob_prime($n/5)  ? 1 : 0) if ($n % 5) == 0;

  # TODO: Something with GMP.  If nothing else, just factor.
  {
    my @f = trial_factor($n, 4999);
    return 0 if @f > 2;
    return (_is_prime7($f[1]) ? 1 : 0) if @f == 2;
  }
  return 0 if _is_prime7($n);
  {
    my @f = pminus1_factor ($n, 250_000);
    return 0 if @f > 2;
    return (_is_prime7($f[1]) ? 1 : 0) if @f == 2;
  }
  {
    my @f = pbrent_factor ($n, 128*1024, 3, 1);
    return 0 if @f > 2;
    return (_is_prime7($f[1]) ? 1 : 0) if @f == 2;
  }
  return (scalar(Mfactor($n)) == 2) ? 1 : 0;
}

sub is_almost_prime {
  my($k, $n) = @_;
  _validate_positive_integer($k);
  _validate_positive_integer($n);

  return 0+($n==1) if $k == 0;
  return (Mis_prime($n) ? 1 : 0) if $k == 1;
  return Math::Prime::Util::is_semiprime($n) if $k == 2;
  return 0 if ($n >> $k) == 0;

  # TODO: Optimization here

  return (scalar(Mfactor($n)) == $k) ? 1 : 0;
}
sub is_omega_prime {
  my($k, $n) = @_;
  _validate_positive_integer($k);
  _validate_positive_integer($n);

  return 0+($n==1) if $k == 0;

  return (Math::Prime::Util::prime_omega($n) == $k) ? 1 : 0;
}

sub is_practical {
  my($n) = @_;

  return (($n==1) ? 1 : 0) if ($n == 0) || ($n & 1);
  return 1 if ($n & ($n-1)) == 0;
  return 0 if ($n % 6) && ($n % 20) && ($n % 28) && ($n % 88) && ($n % 104) && ($n % 16);

  my $prod = 1;
  my @pe = Mfactor_exp($n);
  for my $i (1 .. $#pe) {
    my($f,$e) = @{$pe[$i-1]};
    my $fmult = $f + 1;
    if ($e >= 2) {
      my $pke = $f;
      for (2 .. $e) {
        $pke = Mmulint($pke, $f);
        $fmult = Maddint($fmult, $pke);
      }
    }
    $prod = Mmulint($prod, $fmult);
    return 0 if $pe[$i]->[0] > (1 + $prod);
  }
  1;
}

sub is_delicate_prime {
  my($n) = @_;

  return 0 if $n < 100;  # Easily seen.
  return 0 unless Mis_prime($n);

  # We'll use a string replacement method, because it's a lot easier with
  # Perl and we can completely ignore all bigint type issues.

  my $ndigits = length($n);
  for my $d (0 .. $ndigits-1) {
    my $N = "$n";
    my $dold = substr($N,$d,1);
    for my $dnew (0 .. 9) {
      next if $dnew == $dold;
      substr($N,$d,1) = $dnew;
      return 0 if Mis_prime($N);
    }
  }
  1;
}

sub _totpred {
  my($n, $maxd) = @_;
  return 0 if $maxd <= 1 || (ref($n) ? $n->is_odd() : ($n & 1));
  $n = Math::BigInt->new("$n") unless ref($n) || $n < INTMAX;
  return 1 if ($n & ($n-1)) == 0;
  $n >>= 1;
  return 1 if $n == 1 || ($n < $maxd && Mis_prime(2*$n+1));
  for my $d (Math::Prime::Util::divisors($n)) {
    last if $d >= $maxd;
    my $p = ($d < (INTMAX >> 2))  ?  ($d << 1) + 1 :
            Maddint(Mlshiftint($d,1),1);
    next unless Mis_prime($p);
    my $r = int($n / $d);
    while (1) {
      return 1 if $r == $p || _totpred($r, $d);
      last if ($r % $p) != 0;
      $r = int($r / $p);
    }
  }
  0;
}
sub is_totient {
  my($n) = @_;
  _validate_positive_integer($n);
  return 1 if $n == 1;
  return 0 if $n <= 0;
  return _totpred($n,$n);
}


sub moebius_range {
  my($lo, $hi) = @_;
  _validate_integer($lo);
  _validate_integer($hi);
  return () if $hi < $lo;
  return moebius($lo) if $lo == $hi;
  if ($lo < 0) {
    if ($hi < 0) {
      return reverse(moebius_range(-$hi,-$lo));
    } else {
      return (reverse(moebius_range(1,-$lo)), moebius_range(0,$hi));
    }
  }
  if ($hi > 2**32) {
    my @mu;
    while ($lo <= $hi) {
      push @mu, moebius($lo++);
    }
    return @mu;
  }
  my @mu = map { 1 } $lo .. $hi;
  $mu[0] = 0 if $lo == 0;
  my($p, $sqrtn) = (2, int(sqrt($hi)+0.5));
  while ($p <= $sqrtn) {
    my $i = $p * $p;
    $i = $i * int($lo/$i) + (($lo % $i)  ? $i : 0)  if $i < $lo;
    while ($i <= $hi) {
      $mu[$i-$lo] = 0;
      $i += $p * $p;
    }
    $i = $p;
    $i = $i * int($lo/$i) + (($lo % $i)  ? $i : 0)  if $i < $lo;
    while ($i <= $hi) {
      $mu[$i-$lo] *= -$p;
      $i += $p;
    }
    $p = Mnext_prime($p);
  }
  foreach my $i ($lo .. $hi) {
    my $m = $mu[$i-$lo];
    $m *= -1 if abs($m) != $i;
    $mu[$i-$lo] = ($m>0) - ($m<0);
  }
  return @mu;
}

sub _omertens {
  my($n) = @_;
  # This is the most basic Deléglise and Rivat algorithm.  u = n^1/2
  # and no segmenting is done.  Their algorithm uses u = n^1/3, breaks
  # the summation into two parts, and calculates those in segments.  Their
  # computation time growth is half of this code.
  return $n if $n <= 1;
  my $u = int(sqrt($n));
  my @mu = (0, Mmoebius(1, $u)); # Hold values of mu for 0-u
  my $musum = 0;
  my @M = map { $musum += $_; } @mu;     # Hold values of M for 0-u
  my $sum = $M[$u];
  foreach my $m (1 .. $u) {
    next if $mu[$m] == 0;
    my $inner_sum = 0;
    my $lower = int($u/$m) + 1;
    my $last_nmk = int($n/($m*$lower));
    my ($denom, $this_k, $next_k) = ($m, 0, int($n/($m*1)));
    for my $nmk (1 .. $last_nmk) {
      $denom += $m;
      $this_k = int($n/$denom);
      next if $this_k == $next_k;
      ($this_k, $next_k) = ($next_k, $this_k);
      $inner_sum += $M[$nmk] * ($this_k - $next_k);
    }
    $sum -= $mu[$m] * $inner_sum;
  }
  return $sum;
}

sub _rmertens {
  my($n, $Mref, $Href, $size) = @_;
  return $Mref->[$n] if $n <= $size;
  return $Href->{$n} if exists $Href->{$n};
  my $s = Msqrtint($n);
  my $ns = int($n/($s+1));

  my ($nk, $nk1) = ($n, $n >> 1);
  my $SUM = 1 - ($nk - $nk1);
  foreach my $k (2 .. $ns) {
    ($nk, $nk1) = ($nk1, int($n/($k+1)));
    $SUM -= ($nk <= $size) ? $Mref->[$nk]
                           : _rmertens($nk, $Mref, $Href, $size);
    $SUM -= $Mref->[$k] * ($nk - $nk1);
  }
  $SUM -= $Mref->[$s] * (int($n/$s) - $ns)  if $s > $ns;

  $Href->{$n} = $SUM;
  $SUM;
}

sub mertens {
  my($n) = @_;

  return _omertens($n) if $n < 20000;

  # Larger size would be faster, but more memory.
  my $size = (Mrootint($n, 3)**2) >> 2;
  $size = Msqrtint($n) if $size < Msqrtint($n);

  my @M = (0);
  push @M, $M[-1] + $_ for Mmoebius(1, $size);

  my %seen;
  return _rmertens($n, \@M, \%seen, $size);
}


sub ramanujan_sum {
  my($k,$n) = @_;
  return 0 if $k < 1 || $n <  1;
  my $g = $k / Mgcd($k,$n);
  my $m = Mmoebius($g);
  return $m if $m == 0 || $k == $g;
  $m * (Math::Prime::Util::euler_phi($k) / Math::Prime::Util::euler_phi($g));
}

sub liouville {
  my($n) = @_;
  my $l = (-1) ** scalar Mfactor($n);
  return $l;
}

sub sumliouville {
  my($n) = @_;
  return (0,1,0,-1,0,-1,0,-1,-2,-1,0,-1,-2,-3,-2,-1)[$n] if $n < 16;

  # Build the Mertens lookup info once.
  my $sqrtn = Msqrtint($n);
  my $size = (Mrootint($n, 3)**2) >> 2;
  $size = $sqrtn if $size < $sqrtn;
  my %seen;
  my @M = (0);
  push @M, $M[-1] + $_ for Mmoebius(1, $size);

  # L(n) = sum[k=1..sqrt(n)](Mertens(n/(k^2)))
  my $L = 0;
  for my $k (1 .. $sqrtn) {
    #my $nk = Mdivint($n, Mmulint($k,$k));
    my $nk = int($n/($k*$k));
    return $L + $sqrtn - $k + 1 if $nk == 1;
    $L += ($nk <= $size)  ?  $M[$nk]  :  _rmertens($nk, \@M, \%seen, $size);
  }
  return $L;
}

# Exponential of Mangoldt function (A014963).
# Return p if n = p^m [p prime, m >= 1], 1 otherwise.
sub exp_mangoldt {
  my($n) = @_;
  my $p;
  return 1 unless Math::Prime::Util::is_prime_power($n,\$p);
  $p;
}

sub carmichael_lambda {
  my($n) = @_;
  return euler_phi($n) if $n < 8;          # = phi(n) for n < 8
  return $n >> 2 if ($n & ($n-1)) == 0;    # = phi(n)/2 = n/4 for 2^k, k>2

  my @pe = Mfactor_exp($n);
  $pe[0]->[1]-- if $pe[0]->[0] == 2 && $pe[0]->[1] > 2;

  my $lcm;
  if (!ref($n)) {
    $lcm = Math::Prime::Util::lcm(
      map { ($_->[0] ** ($_->[1]-1)) * ($_->[0]-1) } @pe
    );
  } else {
    $lcm = Math::BigInt::blcm(
      map { $_->[0]->copy->bpow($_->[1]->copy->bdec)->bmul($_->[0]->copy->bdec) }
      map { [ map { Math::BigInt->new("$_") } @$_ ] }
      @pe
    );
    $lcm = _bigint_to_int($lcm) if $lcm->bacmp(BMAX) <= 0;
  }
  $lcm;
}

sub is_carmichael {
  my($n) = @_;
  _validate_positive_integer($n);

  # This works fine, but very slow
  # return !is_prime($n) && ($n % carmichael_lambda($n)) == 1;

  return 0 if $n < 561 || ($n % 2) == 0;
  return 0 if (!($n % 9) || !($n % 25) || !($n%49) || !($n%121));

  # Check Korselt's criterion for small divisors
  my $fn = $n;
  for my $a (5,7,11,13,17,19,23,29,31,37,41,43) {
    if (($fn % $a) == 0) {
      return 0 if (($n-1) % ($a-1)) != 0;   # Korselt
      $fn /= $a;
      return 0 unless $fn % $a;             # not square free
    }
  }
  return 0 if Mpowmod(2, $n-1, $n) != 1;

  # After pre-tests, it's reasonably likely $n is a Carmichael number or prime

  # Use probabilistic test if too large to reasonably factor.
  if (length($fn) > 50) {
    return 0 if Mis_prime($n);
    for my $t (13 .. 150) {
      my $a = $_primes_small[$t];
      my $gcd = Mgcd($a, $fn);
      if ($gcd == 1) {
        return 0 if Mpowmod($a, $n-1, $n) != 1;
      } else {
        return 0 if $gcd != $a;              # Not square free
        return 0 if (($n-1) % ($a-1)) != 0;  # factor doesn't divide
        $fn /= $a;
      }
    }
    return 1;
  }

  # Verify with factoring.
  my @pe = Mfactor_exp($n);
  return 0 if scalar(@pe) < 3;
  for my $pe (@pe) {
    return 0 if $pe->[1] > 1 || (($n-1) % ($pe->[0]-1)) != 0;
  }
  1;
}

sub is_quasi_carmichael {
  my($n) = @_;
  _validate_positive_integer($n);

  return 0 if $n < 35;
  return 0 if (!($n % 4) || !($n % 9) || !($n % 25) || !($n%49) || !($n%121));

  my @pe = Mfactor_exp($n);
  # Not quasi-Carmichael if prime
  return 0 if scalar(@pe) < 2;
  # Not quasi-Carmichael if not square free
  for my $pe (@pe) {
    return 0 if $pe->[1] > 1;
  }
  my @f = map { $_->[0] } @pe;
  my $nbases = 0;
  if ($n < 2000) {
    # In theory for performance, but mainly keeping to show direct method.
    my $lim = $f[-1];
    $lim = (($n-$lim*$lim) + $lim - 1) / $lim;
    for my $b (1 .. $f[0]-1) {
      my $nb = $n - $b;
      $nbases++ if Mvecall(sub { $nb % ($_-$b) == 0 }, @f);
    }
    if (scalar(@f) > 2) {
      for my $b (1 .. $lim-1) {
        my $nb = $n + $b;
        $nbases++ if Mvecall(sub { $nb % ($_+$b) == 0 }, @f);
      }
    }
  } else {
    my($spf,$lpf) = ($f[0], $f[-1]);
    if (scalar(@f) == 2) {
      foreach my $d (Math::Prime::Util::divisors($n/$spf - 1)) {
        my $k = $spf - $d;
        my $p = $n - $k;
        last if $d >= $spf;
        $nbases++ if Mvecall(sub { my $j = $_-$k;  $j && ($p % $j) == 0 }, @f);
      }
    } else {
      foreach my $d (Math::Prime::Util::divisors($lpf * ($n/$lpf - 1))) {
        my $k = $lpf - $d;
        my $p = $n - $k;
        next if $k == 0 || $k >= $spf;
        $nbases++ if Mvecall(sub { my $j = $_-$k;  $j && ($p % $j) == 0 }, @f);
      }
    }
  }
  $nbases;
}

sub is_pillai {
  my($p) = @_;
  return 0 if defined($p) && int($p) < 0;
  _validate_positive_integer($p);
  return 0 if $p <= 2;

  my $pm1 = $p-1;
  my $nfac = 5040 % $p;
  for (my $n = 8; $n < $p; $n++) {
    $nfac = Mmulmod($nfac, $n, $p);
    return $n if $nfac == $pm1 && ($p % $n) != 1;
  }
  0;
}

sub is_fundamental {
  my($n) = @_;
  _validate_integer($n);
  my $neg = ($n < 0);
  $n = -$n if $neg;
  my $r = $n & 15;
  if ($r) {
    my $r4 = $r & 3;
    if (!$neg) {
      return (($r ==  4) ? 0 : is_square_free($n >> 2)) if $r4 == 0;
      return is_square_free($n) if $r4 == 1;
    } else {
      return (($r == 12) ? 0 : is_square_free($n >> 2)) if $r4 == 0;
      return is_square_free($n) if $r4 == 3;
    }
  }
  0;
}

my @_ds_overflow =  # We'll use BigInt math if the input is larger than this.
  (~0 > 4294967295)
   ? (124, 3000000000000000000, 3000000000, 2487240, 64260, 7026)
   : ( 50,           845404560,      52560,    1548,   252,   84);
sub divisor_sum {
  my($n, $k) = @_;
  return ((defined $k && $k==0) ? 2 : 1) if $n == 0;
  return 1 if $n == 1;

  if (defined $k && ref($k) eq 'CODE') {
    my $sum = $n-$n;
    my $refn = ref($n);
    foreach my $d (Math::Prime::Util::divisors($n)) {
      $sum += $k->( $refn ? $refn->new("$d") : $d );
    }
    return $sum;
  }

  croak "Second argument must be a code ref or number"
    unless !defined $k || _validate_num($k) || _validate_positive_integer($k);
  $k = 1 if !defined $k;

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::sigma($n, $k))
    if $Math::Prime::Util::_GMPfunc{"sigma"};

  my $will_overflow = ($k == 0) ? (length($n) >= $_ds_overflow[0])
                    : ($k <= 5) ? ($n >= $_ds_overflow[$k])
                    : 1;

  # The standard way is:
  #    my $pk = $f ** $k;  $product *= ($pk ** ($e+1) - 1) / ($pk - 1);
  # But we get less overflow using:
  #    my $pk = $f ** $k;  $product *= $pk**E for E in 0 .. e
  # Also separate BigInt and do fiddly bits for better performance.

  my @factors = Mfactor_exp($n);
  my $product = 1;
  my @fm;
  if ($k == 0) {
    $product = Mvecprod(map { $_->[1]+1 } @factors);
  } elsif (!$will_overflow) {
    foreach my $f (@factors) {
      my ($p, $e) = @$f;
      my $pk = $p ** $k;
      my $fmult = $pk + 1;
      foreach my $E (2 .. $e) { $fmult += $pk**$E }
      $product *= $fmult;
    }
  } elsif (ref($n) && ref($n) ne 'Math::BigInt') {
    # This can help a lot for Math::GMP, etc.
    $product = ref($n)->new(1);
    foreach my $f (@factors) {
      my ($p, $e) = @$f;
      my $pk = ref($n)->new($p) ** $k;
      my $fmult = $pk;  $fmult++;
      if ($e >= 2) {
        my $pke = $pk;
        for (2 .. $e) { $pke *= $pk; $fmult += $pke; }
      }
      $product *= $fmult;
    }
  } elsif ($k == 1) {
    foreach my $f (@factors) {
      my ($p, $e) = @$f;
      my $pk = Math::BigInt->new("$p");
      if ($e == 1) { push @fm, $pk->binc; next; }
      my $fmult = $pk->copy->binc;
      my $pke = $pk->copy;
      for my $E (2 .. $e) {
        $pke->bmul($pk);
        $fmult->badd($pke);
      }
      push @fm, $fmult;
    }
    $product = Mvecprod(@fm);
  } else {
    my $bik = Math::BigInt->new("$k");
    foreach my $f (@factors) {
      my ($p, $e) = @$f;
      my $pk = Math::BigInt->new("$p")->bpow($bik);
      if ($e == 1) { push @fm, $pk->binc; next; }
      my $fmult = $pk->copy->binc;
      my $pke = $pk->copy;
      for my $E (2 .. $e) {
        $pke->bmul($pk);
        $fmult->badd($pke);
      }
      push @fm, $fmult;
    }
    $product = Mvecprod(@fm);
  }
  $product;
}

#############################################################################
#                       Lehmer prime count
#
#my @_s0 = (0);
#my @_s1 = (0,1);
#my @_s2 = (0,1,1,1,1,2);
#my @_s3 = (0,1,1,1,1,1,1,2,2,2,2,3,3,4,4,4,4,5,5,6,6,6,6,7,7,7,7,7,7,8);
#my @_s4 = (0,1,1,1,1,1,1,1,1,1,1,2,2,3,3,3,3,4,4,5,5,5,5,6,6,6,6,6,6,7,7,8,8,8,8,8,8,9,9,9,9,10,10,11,11,11,11,12,12,12,12,12,12,13,13,13,13,13,13,14,14,15,15,15,15,15,15,16,16,16,16,17,17,18,18,18,18,18,18,19,19,19,19,20,20,20,20,20,20,21,21,21,21,21,21,21,21,22,22,22,22,23,23,24,24,24,24,25,25,26,26,26,26,27,27,27,27,27,27,27,27,28,28,28,28,28,28,29,29,29,29,30,30,30,30,30,30,31,31,32,32,32,32,33,33,33,33,33,33,34,34,35,35,35,35,35,35,36,36,36,36,36,36,37,37,37,37,38,38,39,39,39,39,40,40,40,40,40,40,41,41,42,42,42,42,42,42,43,43,43,43,44,44,45,45,45,45,46,46,47,47,47,47,47,47,47,47,47,47,48);
my(@_s3,@_s4);
my @_pred5 = (1,0,1,2,3,4,5,0,1,2,3,0,1,0,1,2,3,0,1,0,1,2,3,0,1,2,3,4,5,0);

sub _tablephi {
  my($x, $a) = @_;
  if ($a == 0) { return $x; }
  elsif ($a == 1) { return $x-int($x/2); }
  elsif ($a == 2) { return $x-int($x/2) - int($x/3) + int($x/6); }
  elsif ($a == 3) { return  8 * int($x /  30) + $_s3[$x %  30]; }
  elsif ($a == 4) { return 48 * int($x / 210) + $_s4[$x % 210]; }
  elsif ($a == 5) { my $xp = int($x/11);
                    return ( (48 * int($x   / 210) + $_s4[$x   % 210]) -
                             (48 * int($xp  / 210) + $_s4[$xp  % 210]) ); }
  else            { my ($xp,$x2) = (int($x/11),int($x/13));
                    my $x2p = int($x2/11);
                    return ( (48 * int($x   / 210) + $_s4[$x   % 210]) -
                             (48 * int($xp  / 210) + $_s4[$xp  % 210]) -
                             (48 * int($x2  / 210) + $_s4[$x2  % 210]) +
                             (48 * int($x2p / 210) + $_s4[$x2p % 210]) ); }
}

sub legendre_phi {
  my ($x, $a, $primes) = @_;
  if ($#_s3 == -1) {
    @_s3 = (0,1,1,1,1,1,1,2,2,2,2,3,3,4,4,4,4,5,5,6,6,6,6,7,7,7,7,7,7,8);
    @_s4 = (0,1,1,1,1,1,1,1,1,1,1,2,2,3,3,3,3,4,4,5,5,5,5,6,6,6,6,6,6,7,7,8,8,8,8,8,8,9,9,9,9,10,10,11,11,11,11,12,12,12,12,12,12,13,13,13,13,13,13,14,14,15,15,15,15,15,15,16,16,16,16,17,17,18,18,18,18,18,18,19,19,19,19,20,20,20,20,20,20,21,21,21,21,21,21,21,21,22,22,22,22,23,23,24,24,24,24,25,25,26,26,26,26,27,27,27,27,27,27,27,27,28,28,28,28,28,28,29,29,29,29,30,30,30,30,30,30,31,31,32,32,32,32,33,33,33,33,33,33,34,34,35,35,35,35,35,35,36,36,36,36,36,36,37,37,37,37,38,38,39,39,39,39,40,40,40,40,40,40,41,41,42,42,42,42,42,42,43,43,43,43,44,44,45,45,45,45,46,46,47,47,47,47,47,47,47,47,47,47,48);
  }
  return _tablephi($x,$a) if $a <= 6;
  $primes = primes(Math::Prime::Util::nth_prime_upper($a+1)) unless defined $primes;
  return ($x > 0 ? 1 : 0) if $x < $primes->[$a];

  my $sum = 0;
  my %vals = ( $x => 1 );
  while ($a > 6) {
    my $primea = $primes->[$a-1];
    my %newvals;
    while (my($v,$c) = each %vals) {
      my $sval = int($v / $primea);
      $sval -= $_pred5[$sval % 30];   # Reduce sval to one with same phi.
      if ($sval < $primea) {
        $sum -= $c;
      } else {
        $newvals{$sval} -= $c;
      }
    }
    # merge newvals into vals
    while (my($v,$c) = each %newvals) {
      $vals{$v} += $c;
      delete $vals{$v} if $vals{$v} == 0;
    }
    $a--;
  }
  while (my($v,$c) = each %vals) {
    $sum += $c * _tablephi($v, $a);
  }
  return $sum;
}

sub _sieve_prime_count {
  my $high = shift;
  return (0,0,1,2,2,3,3)[$high] if $high < 7;
  $high-- unless ($high & 1);
  return 1 + ${_sieve_erat($high)} =~ tr/0//;
}

sub _count_with_sieve {
  my ($sref, $low, $high) = @_;
  ($low, $high) = (2, $low) if !defined $high;
  my $count = 0;
  if   ($low < 3) { $low = 3; $count++; }
  else            { $low |= 1; }
  $high-- unless ($high & 1);
  return $count if $low > $high;
  my $sbeg = $low >> 1;
  my $send = $high >> 1;

  if ( !defined $sref || $send >= length($$sref) ) {
    # outside our range, so call the segment siever.
    my $seg_ref = _sieve_segment($low, $high);
    return $count + $$seg_ref =~ tr/0//;
  }
  return $count + substr($$sref, $sbeg, $send-$sbeg+1) =~ tr/0//;
}

sub _lehmer_pi {
  my $x = shift;
  return _sieve_prime_count($x) if $x < 1_000;
  do { require Math::BigFloat; Math::BigFloat->import(); }
    if ref($x) eq 'Math::BigInt';
  my $z = (ref($x) ne 'Math::BigInt')
        ? int(sqrt($x+0.5))
        : int(Math::BigFloat->new($x)->badd(0.5)->bsqrt->bfloor->bstr);
  my $a = _lehmer_pi(int(sqrt($z)+0.5));
  my $b = _lehmer_pi($z);
  my $c = _lehmer_pi(int( (ref($x) ne 'Math::BigInt')
                          ? $x**(1/3)+0.5
                          : Math::BigFloat->new($x)->broot(3)->badd(0.5)->bfloor
                     ));
  ($z, $a, $b, $c) = map { (ref($_) =~ /^Math::Big/) ? _bigint_to_int($_) : $_ }
                     ($z, $a, $b, $c);

  # Generate at least b primes.
  my $bth_prime_upper = ($b <= 10) ? 29 : int($b*(log($b) + log(log($b)))) + 1;
  my $primes = primes( $bth_prime_upper );

  my $sum = int(($b + $a - 2) * ($b - $a + 1) / 2);
  $sum += legendre_phi($x, $a, $primes);

  # Get a big sieve for our primecounts.  The C code compromises with either
  # b*10 or x^3/5, as that cuts out all the inner loop sieves and about half
  # of the big outer loop counts.
  # Our sieve count isn't nearly as optimized here, so error on the side of
  # more primes.  This uses a lot more memory but saves a lot of time.
  my $sref = _sieve_erat( int($x / $primes->[$a] / 5) );

  my ($lastw, $lastwpc) = (0,0);
  foreach my $i (reverse $a+1 .. $b) {
    my $w = int($x / $primes->[$i-1]);
    $lastwpc += _count_with_sieve($sref,$lastw+1, $w);
    $lastw = $w;
    $sum -= $lastwpc;
    #$sum -= _count_with_sieve($sref,$w);
    if ($i <= $c) {
      my $bi = _count_with_sieve($sref,int(sqrt($w)+0.5));
      foreach my $j ($i .. $bi) {
        $sum = $sum - _count_with_sieve($sref,int($w / $primes->[$j-1])) + $j - 1;
      }
    }
  }
  $sum;
}
#############################################################################


sub prime_count {
  my($low,$high) = @_;
  if (!defined $high) {
    $high = $low;
    $low = 2;
  }
  _validate_positive_integer($low);
  _validate_positive_integer($high);

  my $count = 0;

  $count++ if ($low <= 2) && ($high >= 2);   # Count 2
  $low = 3 if $low < 3;

  $low++ if ($low % 2) == 0;   # Make low go to odd number.
  $high-- if ($high % 2) == 0; # Make high go to odd number.
  return $count if $low > $high;

  if (   ref($low) eq 'Math::BigInt' || ref($high) eq 'Math::BigInt'
      || ($high-$low) < 10
      || ($high-$low) < int($low/100_000_000_000) ) {
    # Trial primes seems best.  Needs some tuning.
    my $curprime = Mnext_prime($low-1);
    while ($curprime <= $high) {
      $count++;
      $curprime = Mnext_prime($curprime);
    }
    return $count;
  }

  # TODO: Needs tuning
  if ($high > 50_000) {
    if ( ($high / ($high-$low+1)) < 100 ) {
      $count += _lehmer_pi($high);
      $count -= ($low == 3) ? 1 : _lehmer_pi($low-1);
      return $count;
    }
  }

  return (_sieve_prime_count($high) - 1 + $count) if $low == 3;

  my $sieveref = _sieve_segment($low,$high);
  $count += $$sieveref =~ tr/0//;
  return $count;
}


sub nth_prime {
  my($n) = @_;
  _validate_positive_integer($n);

  return undef if $n <= 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return $_primes_small[$n] if $n <= $#_primes_small;

  if ($n > MPU_MAXPRIMEIDX && ref($n) ne 'Math::BigFloat') {
    do { require Math::BigFloat; Math::BigFloat->import(); }
      if !defined $Math::BigFloat::VERSION;
    $n = Math::BigFloat->new("$n")
  }

  my $prime = 0;
  my $count = 1;
  my $start = 3;

  my $logn = log($n);
  my $loglogn = log($logn);
  my $nth_prime_upper = ($n <= 10) ? 29 : int($n*($logn + $loglogn)) + 1;
  if ($nth_prime_upper > 100000) {
    # Use fast Lehmer prime count combined with lower bound to get close.
    my $nth_prime_lower = int($n * ($logn + $loglogn - 1.0 + (($loglogn-2.10)/$logn)));
    $nth_prime_lower-- unless $nth_prime_lower % 2;
    $count = _lehmer_pi($nth_prime_lower);
    $start = $nth_prime_lower + 2;
  }

  {
    # Make sure incr is an even number.
    my $incr = ($n < 1000) ? 1000 : ($n < 10000) ? 10000 : 100000;
    my $sieveref;
    while (1) {
      $sieveref = _sieve_segment($start, $start+$incr);
      my $segcount = $$sieveref =~ tr/0//;
      last if ($count + $segcount) >= $n;
      $count += $segcount;
      $start += $incr+2;
    }
    # Our count is somewhere in this segment.  Need to look for it.
    $prime = $start - 2;
    while ($count < $n) {
      $prime += 2;
      $count++ if !substr($$sieveref, ($prime-$start)>>1, 1);
    }
  }
  $prime;
}

# The nth prime will be less or equal to this number
sub nth_prime_upper {
  my($n) = @_;
  _validate_positive_integer($n);

  return undef if $n <= 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return $_primes_small[$n] if $n <= $#_primes_small;

  $n = _upgrade_to_float($n) if $n > MPU_MAXPRIMEIDX || $n > 2**45;

  my $flogn  = log($n);
  my $flog2n = log($flogn);  # Note distinction between log_2(n) and log^2(n)

  my $upper;
  if      ($n >= 46254381) {  # Axler 2017 Corollary 1.2
    $upper = $n * ( $flogn  +  $flog2n-1.0  +  (($flog2n-2.00)/$flogn)  -  (($flog2n*$flog2n - 6*$flog2n + 10.667)/(2*$flogn*$flogn)) );
  } elsif ($n >=  8009824) {  # Axler 2013 page viii Korollar G
    $upper = $n * ( $flogn  +  $flog2n-1.0  +  (($flog2n-2.00)/$flogn)  -  (($flog2n*$flog2n - 6*$flog2n + 10.273)/(2*$flogn*$flogn)) );
  } elsif ($n >=  688383) {   # Dusart 2010 page 2
    $upper = $n * ( $flogn  +  $flog2n - 1.0 + (($flog2n-2.00)/$flogn) );
  } elsif ($n >=  178974) {   # Dusart 2010 page 7
    $upper = $n * ( $flogn  +  $flog2n - 1.0 + (($flog2n-1.95)/$flogn) );
  } elsif ($n >=   39017) {   # Dusart 1999 page 14
    $upper = $n * ( $flogn  +  $flog2n - 0.9484 );
  } elsif ($n >=       6) {   # Modified Robin 1983, for 6-39016 only
    $upper = $n * ( $flogn  +  0.6000 * $flog2n );
  } else {
    $upper = $n * ( $flogn  +  $flog2n );
  }

  return int($upper + 1.0);
}

# The nth prime will be greater than or equal to this number
sub nth_prime_lower {
  my($n) = @_;
  _validate_num($n) || _validate_positive_integer($n);

  return undef if $n <= 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return $_primes_small[$n] if $n <= $#_primes_small;

  $n = _upgrade_to_float($n) if $n > MPU_MAXPRIMEIDX || $n > 2**45;

  my $flogn  = log($n);
  my $flog2n = log($flogn);  # Note distinction between log_2(n) and log^2(n)

  # Dusart 1999 page 14, for all n >= 2
  #my $lower = $n * ($flogn + $flog2n - 1.0 + (($flog2n-2.25)/$flogn));
  # Dusart 2010 page 2, for all n >= 3
  #my $lower = $n * ($flogn + $flog2n - 1.0 + (($flog2n-2.10)/$flogn));
  # Axler 2013 page viii Korollar I, for all n >= 2
  #my $lower = $n * ($flogn + $flog2n-1.0 + (($flog2n-2.00)/$flogn) - (($flog2n*$flog2n - 6*$flog2n + 11.847)/(2*$flogn*$flogn)) );
  # Axler 2017 Corollary 1.4
  my $lower = $n * ($flogn + $flog2n-1.0 + (($flog2n-2.00)/$flogn) - (($flog2n*$flog2n - 6*$flog2n + 11.508)/(2*$flogn*$flogn)) );

  return int($lower + 0.999999999);
}

sub inverse_li {
  my($n) = @_;
  _validate_num($n) || _validate_positive_integer($n);

  return (0,2,3,5,6,8)[$n] if $n <= 5;
  $n = _upgrade_to_float($n) if $n > MPU_MAXPRIMEIDX || $n > 2**45;
  my $t = $n * log($n);

  # Iterator Halley's method until error term grows
  my $old_term = MPU_INFINITY;
  for my $iter (1 .. 10000) {
    my $dn = Math::Prime::Util::LogarithmicIntegral($t) - $n;
    my $term = $dn * log($t) / (1.0 + $dn/(2*$t));
    last if abs($term) >= abs($old_term);
    $old_term = $term;
    $t -= $term;
    last if abs($term) < 1e-6;
  }
  if (ref($t)) {
    $t = Math::BigInt->new($t->bceil->bstr);
    $t = _bigint_to_int($t) if $t->bacmp(BMAX) <= 0;
  } else {
    $t = int($t+0.999999);
  }
  $t;
}
sub _inverse_R {
  my($n) = @_;
  _validate_num($n) || _validate_positive_integer($n);

  return (0,2,3,5,6,8)[$n] if $n <= 5;
  $n = _upgrade_to_float($n) if $n > MPU_MAXPRIMEIDX || $n > 2**45;
  my $t = $n * log($n);

  # Iterator Halley's method until error term grows
  my $old_term = MPU_INFINITY;
  for my $iter (1 .. 10000) {
    my $dn = Math::Prime::Util::RiemannR($t) - $n;
    my $term = $dn * log($t) / (1.0 + $dn/(2*$t));
    last if abs($term) >= abs($old_term);
    $old_term = $term;
    $t -= $term;
    last if abs($term) < 1e-6;
  }
  if (ref($t)) {
    $t = Math::BigInt->new($t->bceil->bstr);
    $t = _bigint_to_int($t) if $t->bacmp(BMAX) <= 0;
  } else {
    $t = int($t+0.999999);
  }
  $t;
}

sub nth_prime_approx {
  my($n) = @_;
  _validate_num($n) || _validate_positive_integer($n);

  return undef if $n <= 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return $_primes_small[$n] if $n <= $#_primes_small;

  # Once past 10^12 or so, inverse_li gives better results.
  return Math::Prime::Util::inverse_li($n) if $n > 1e12;

  $n = _upgrade_to_float($n)
    if ref($n) eq 'Math::BigInt' || $n >= MPU_MAXPRIMEIDX;

  my $flogn  = log($n);
  my $flog2n = log($flogn);

  # Cipolla 1902:
  #    m=0   fn * ( flogn + flog2n - 1 );
  #    m=1   + ((flog2n - 2)/flogn) );
  #    m=2   - (((flog2n*flog2n) - 6*flog2n + 11) / (2*flogn*flogn))
  #    + O((flog2n/flogn)^3)
  #
  # Shown in Dusart 1999 page 12, as well as other sources such as:
  #   http://www.emis.de/journals/JIPAM/images/153_02_JIPAM/153_02.pdf
  # where the main issue you run into is that you're doing polynomial
  # interpolation, so it oscillates like crazy with many high-order terms.
  # Hence I'm leaving it at m=2.

  my $approx = $n * ( $flogn + $flog2n - 1
                      + (($flog2n - 2)/$flogn)
                      - ((($flog2n*$flog2n) - 6*$flog2n + 11) / (2*$flogn*$flogn))
                    );

  # Apply a correction to help keep values close.
  my $order = $flog2n/$flogn;
  $order = $order*$order*$order * $n;

  if    ($n <        259) { $approx += 10.4 * $order; }
  elsif ($n <        775) { $approx +=  6.3 * $order; }
  elsif ($n <       1271) { $approx +=  5.3 * $order; }
  elsif ($n <       2000) { $approx +=  4.7 * $order; }
  elsif ($n <       4000) { $approx +=  3.9 * $order; }
  elsif ($n <      12000) { $approx +=  2.8 * $order; }
  elsif ($n <     150000) { $approx +=  1.2 * $order; }
  elsif ($n <   20000000) { $approx +=  0.11 * $order; }
  elsif ($n <  100000000) { $approx +=  0.008 * $order; }
  elsif ($n <  500000000) { $approx += -0.038 * $order; }
  elsif ($n < 2000000000) { $approx += -0.054 * $order; }
  else                    { $approx += -0.058 * $order; }
  # If we want the asymptotic approximation to be >= actual, use -0.010.

  return int($approx + 0.5);
}

#############################################################################

sub prime_count_approx {
  my($x) = @_;
  _validate_num($x) || _validate_positive_integer($x);

  # Turn on high precision FP if they gave us a big number.
  $x = _upgrade_to_float($x) if ref($_[0]) eq 'Math::BigInt' && $x > 1e16;
  #    Method             10^10 %error  10^19 %error
  #    -----------------  ------------  ------------
  #    n/(log(n)-1)        .22%          .058%
  #    n/(ln(n)-1-1/ln(n)) .032%         .0041%
  #    average bounds      .0005%        .0000002%
  #    asymp               .0006%        .00000004%
  #    li(n)               .0007%        .00000004%
  #    li(n)-li(n^.5)/2    .0004%        .00000001%
  #    R(n)                .0004%        .00000001%
  #
  # Also consider: http://trac.sagemath.org/sage_trac/ticket/8135

  # Asymp:
  #   my $l1 = log($x);  my $l2 = $l1*$l1;  my $l4 = $l2*$l2;
  #   my $result = int( $x/$l1 + $x/$l2 + 2*$x/($l2*$l1) + 6*$x/($l4) + 24*$x/($l4*$l1) + 120*$x/($l4*$l2) + 720*$x/($l4*$l2*$l1) + 5040*$x/($l4*$l4) + 40320*$x/($l4*$l4*$l1) + 0.5 );
  # my $result = int( (prime_count_upper($x) + prime_count_lower($x)) / 2);
  # my $result = int( LogarithmicIntegral($x) );
  # my $result = int(LogarithmicIntegral($x) - LogarithmicIntegral(sqrt($x))/2);
  # my $result = RiemannR($x) + 0.5;

  # Make sure we get enough accuracy, and also not too much more than needed
  $x->accuracy(length($x->copy->as_int->bstr())+2) if ref($x) =~ /^Math::Big/;

  my $result;
  if ($Math::Prime::Util::_GMPfunc{"riemannr"} || !ref($x)) {
    # Fast if we have our GMP backend, and ok for native.
    $result = Math::Prime::Util::PP::RiemannR($x);
  } else {
    $x = _upgrade_to_float($x) unless ref($x) eq 'Math::BigFloat';
    $result = Math::BigFloat->new(0);
    $result->accuracy($x->accuracy) if ref($x) && $x->accuracy;
    $result += Math::BigFloat->new(LogarithmicIntegral($x));
    $result -= Math::BigFloat->new(LogarithmicIntegral(sqrt($x))/2);
    my $intx = ref($x) ? Math::BigInt->new($x->bfround(0)) : $x;
    for my $k (3 .. 1000) {
      my $m = moebius($k);
      next unless $m != 0;
      # With Math::BigFloat and the Calc backend, FP root is ungodly slow.
      # Use integer root instead.  For more accuracy (not useful here):
      # my $v = Math::BigFloat->new( "" . Mrootint($x->as_int,$k) );
      # $v->accuracy(length($v)+5);
      # $v = $v - Math::BigFloat->new(($v**$k - $x))->bdiv($k * $v**($k-1));
      # my $term = LogarithmicIntegral($v)/$k;
      my $term = LogarithmicIntegral(Mrootint($intx,$k)) / $k;
      last if $term < .25;
      if ($m == 1) { $result->badd(Math::BigFloat->new($term)) }
      else         { $result->bsub(Math::BigFloat->new($term)) }
    }
  }

  if (ref($result)) {
    return $result unless ref($result) eq 'Math::BigFloat';
    # Math::BigInt::FastCalc 0.19 implements as_int incorrectly.
    return Math::BigInt->new($result->bfround(0)->bstr);
  }
  int($result+0.5);
}

sub prime_count_lower {
  my($x) = @_;
  _validate_num($x) || _validate_positive_integer($x);

  return _tiny_prime_count($x) if $x < $_primes_small[-1];

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::prime_count_lower($x))
    if $Math::Prime::Util::_GMPfunc{"prime_count_lower"};

  $x = _upgrade_to_float($x)
    if ref($x) eq 'Math::BigInt' || ref($_[0]) eq 'Math::BigInt';

  my($result,$a);
  my $fl1 = log($x);
  my $fl2 = $fl1*$fl1;
  my $one = (ref($x) eq 'Math::BigFloat') ? $x->copy->bone : $x-$x+1.0;

  # Chebyshev            1*x/logx       x >= 17
  # Rosser & Schoenfeld  x/(logx-1/2)   x >= 67
  # Dusart 1999          x/logx*(1+1/logx+1.8/logxlogx)  x >= 32299
  # Dusart 2010          x/logx*(1+1/logx+2.0/logxlogx)  x >= 88783
  # Axler 2014 (1.2)     ""+...                          x >= 1332450001
  # Axler 2014 (1.2)     x/(logx-1-1/logx-...)           x >= 1332479531
  # Büthe 2015 (1.9)     li(x)-(sqrtx/logx)*(...)        x <= 10^19
  # Büthe 2014 Th 2      li(x)-logx*sqrtx/8Pi    x > 2657, x <= 1.4*10^25

  if ($x < 599) {                         # Decent for small numbers
    $result = $x / ($fl1 - 0.7);
  } elsif ($x < 52600000) {               # Dusart 2010 tweaked
    if    ($x <       2700) { $a = 0.30; }
    elsif ($x <       5500) { $a = 0.90; }
    elsif ($x <      19400) { $a = 1.30; }
    elsif ($x <      32299) { $a = 1.60; }
    elsif ($x <      88783) { $a = 1.83; }
    elsif ($x <     176000) { $a = 1.99; }
    elsif ($x <     315000) { $a = 2.11; }
    elsif ($x <    1100000) { $a = 2.19; }
    elsif ($x <    4500000) { $a = 2.31; }
    else                    { $a = 2.35; }
    $result = ($x/$fl1) * ($one + $one/$fl1 + $a/$fl2);
  } elsif ($x < 1.4e25 || Math::Prime::Util::prime_get_config()->{'assume_rh'}){
                                          # Büthe 2014/2015
    my $lix = LogarithmicIntegral($x);
    my $sqx = sqrt($x);
    if ($x < 1e19) {
      $result = $lix - ($sqx/$fl1) * (1.94 + 3.88/$fl1 + 27.57/$fl2);
    } else {
      if (ref($x) eq 'Math::BigFloat') {
        my $xdigits = _find_big_acc($x);
        $result = $lix - ($fl1*$sqx / (Math::BigFloat->bpi($xdigits)*8));
      } else {
        $result = $lix - ($fl1*$sqx / PI_TIMES_8);
      }
    }
  } else {                                # Axler 2014 1.4
    my($fl3,$fl4) = ($fl2*$fl1,$fl2*$fl2);
    my($fl5,$fl6) = ($fl4*$fl1,$fl4*$fl2);
    $result = $x / ($fl1 - $one - $one/$fl1 - 2.65/$fl2 - 13.35/$fl3 - 70.3/$fl4 - 455.6275/$fl5 - 3404.4225/$fl6);
  }

  return Math::BigInt->new($result->bfloor->bstr()) if ref($result) eq 'Math::BigFloat';
  return int($result);
}

sub prime_count_upper {
  my($x) = @_;
  _validate_num($x) || _validate_positive_integer($x);

  # Give an exact answer for what we have in our little table.
  return _tiny_prime_count($x) if $x < $_primes_small[-1];

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::prime_count_upper($x))
    if $Math::Prime::Util::_GMPfunc{"prime_count_upper"};

  $x = _upgrade_to_float($x)
    if ref($x) eq 'Math::BigInt' || ref($_[0]) eq 'Math::BigInt';

  # Chebyshev:            1.25506*x/logx       x >= 17
  # Rosser & Schoenfeld:  x/(logx-3/2)         x >= 67
  # Panaitopol 1999:      x/(logx-1.112)       x >= 4
  # Dusart 1999:          x/logx*(1+1/logx+2.51/logxlogx)   x >= 355991
  # Dusart 2010:          x/logx*(1+1/logx+2.334/logxlogx)  x >= 2_953_652_287
  # Axler 2014:           x/(logx-1-1/logx-3.35/logxlogx...) x >= e^3.804
  # Büthe 2014 7.4        Schoenfeld bounds hold to x <= 1.4e25
  # Axler 2017 Prop 2.2   Schoenfeld bounds hold to x <= 5.5e25
  # Skewes                li(x)                x < 1e14

  my($result,$a);
  my $fl1 = log($x);
  my $fl2 = $fl1 * $fl1;
  my $one = (ref($x) eq 'Math::BigFloat') ? $x->copy->bone : $x-$x+1.0;

  if ($x < 15900) {              # Tweaked Rosser-type
    $a = ($x < 1621) ? 1.048 : ($x < 5000) ? 1.071 : 1.098;
    $result = ($x / ($fl1 - $a)) + 1.0;
  } elsif ($x < 821800000) {     # Tweaked Dusart 2010
    if    ($x <      24000) { $a = 2.30; }
    elsif ($x <      59000) { $a = 2.48; }
    elsif ($x <     350000) { $a = 2.52; }
    elsif ($x <     355991) { $a = 2.54; }
    elsif ($x <     356000) { $a = 2.51; }
    elsif ($x <    3550000) { $a = 2.50; }
    elsif ($x <    3560000) { $a = 2.49; }
    elsif ($x <    5000000) { $a = 2.48; }
    elsif ($x <    8000000) { $a = 2.47; }
    elsif ($x <   13000000) { $a = 2.46; }
    elsif ($x <   18000000) { $a = 2.45; }
    elsif ($x <   31000000) { $a = 2.44; }
    elsif ($x <   41000000) { $a = 2.43; }
    elsif ($x <   48000000) { $a = 2.42; }
    elsif ($x <  119000000) { $a = 2.41; }
    elsif ($x <  182000000) { $a = 2.40; }
    elsif ($x <  192000000) { $a = 2.395; }
    elsif ($x <  213000000) { $a = 2.390; }
    elsif ($x <  271000000) { $a = 2.385; }
    elsif ($x <  322000000) { $a = 2.380; }
    elsif ($x <  400000000) { $a = 2.375; }
    elsif ($x <  510000000) { $a = 2.370; }
    elsif ($x <  682000000) { $a = 2.367; }
    elsif ($x < 2953652287) { $a = 2.362; }
    else                    { $a = 2.334; } # Dusart 2010, page 2
    $result = ($x/$fl1) * ($one + $one/$fl1 + $a/$fl2) + $one;
  } elsif ($x < 1e19) {                     # Skewes number lower limit
    $a = ($x < 110e7) ? 0.032 : ($x < 1001e7) ? 0.027 : ($x < 10126e7) ? 0.021 : 0.0;
    $result = LogarithmicIntegral($x) - $a * $fl1*sqrt($x)/PI_TIMES_8;
  } elsif ($x < 5.5e25 || Math::Prime::Util::prime_get_config()->{'assume_rh'}) {
                                            # Schoenfeld / Büthe 2014 Th 7.4
    my $lix = LogarithmicIntegral($x);
    my $sqx = sqrt($x);
    if (ref($x) eq 'Math::BigFloat') {
      my $xdigits = _find_big_acc($x);
      $result = $lix + ($fl1*$sqx / (Math::BigFloat->bpi($xdigits)*8));
    } else {
      $result = $lix + ($fl1*$sqx / PI_TIMES_8);
    }
  } else {                                  # Axler 2014 1.3
    my($fl3,$fl4) = ($fl2*$fl1,$fl2*$fl2);
    my($fl5,$fl6) = ($fl4*$fl1,$fl4*$fl2);
    $result = $x / ($fl1 - $one - $one/$fl1 - 3.35/$fl2 - 12.65/$fl3 - 71.7/$fl4 - 466.1275/$fl5 - 3489.8225/$fl6);
  }

  return Math::BigInt->new($result->bfloor->bstr()) if ref($result) eq 'Math::BigFloat';
  return int($result);
}

sub twin_prime_count {
  my($low,$high) = @_;
  if (defined $high) { _validate_positive_integer($low); }
  else               { ($low,$high) = (2, $low);         }
  _validate_positive_integer($high);
  my $sum = 0;
  while ($low <= $high) {
    my $seghigh = ($high-$high) + $low + 1e7 - 1;
    $seghigh = $high if $seghigh > $high;
    $sum += scalar(@{Math::Prime::Util::twin_primes($low,$seghigh)});
    $low = $seghigh + 1;
  }
  $sum;
}
sub _semiprime_count {
  my $n = shift;
  my($sum,$pc) = (0,0);
  Mforprimes( sub {
    $sum += Mprime_count(int($n/$_))-$pc++;
  }, Msqrtint($n));
  $sum;
}
sub semiprime_count {
  my($lo,$hi) = @_;
  if (defined $hi) { _validate_positive_integer($lo); }
  else             { ($lo,$hi) = (2, $lo);            }
  _validate_positive_integer($hi);
  # todo: threshold of fast count vs. walk
  if (($hi-$lo+1) < $hi / (sqrt($hi)/4)) {
    my $sum = 0;
    while ($lo <= $hi) {
      $sum++ if Math::Prime::Util::is_semiprime($lo);
      $lo++;
    }
    return $sum;
  }
  my $sum = _semiprime_count($hi) - (($lo < 4) ? 0 : semiprime_count($lo-1));
  $sum;
}

sub _kap_reduce_count {   # returns new k and n
  my($k, $n) = @_;

  my $pow3k = Mpowint(3, $k);
  while ($n  < $pow3k) {
    $n = Mdivint($n, 2);
    $k--;
    $pow3k = Mdivint($pow3k, 3);
  }
  ($k, $n);
}
sub _kapc_count {
  my($n, $pdiv, $lo, $k) = @_;
  my $hi = Mrootint(Mdivint($n,$pdiv),$k);
  my $sum = 0;

  if ($k == 2) {
    my $pc = Mprime_count($lo) - 1;
    Mforprimes( sub {
      $sum += Mprime_count(int($n/($pdiv*$_)))-$pc++;
    }, $lo, $hi);
  } else {
    Mforprimes( sub {
      $sum += _kapc_count($n, Mmulint($pdiv,$_), $_, $k-1);
    }, $lo, $hi);
  }
  $sum;
}
sub almost_prime_count {
  my($k,$n) = @_;
  _validate_positive_integer($k);
  _validate_positive_integer($n);
  return ($n >= 1) if $k == 0;
  ($k, $n) = _kap_reduce_count($k, $n);
  return Mprime_count($n) if $k == 1;
  return Math::Prime::Util::semiprime_count($n) if $k == 2;
  return 0 if ($n >> $k) == 0;

  _kapc_count($n, 1, 2, $k);
}

sub _omega_prime_count_rec {
  my($k, $n,  $m, $p, $s, $j) = @_;
  $s = Mrootint(Mdivint($n,$m),$k) unless defined $s;
  $j = 1 unless defined $j;
  my $count = 0;

  if ($k == 2) {

    for (;  $p <= $s  ;  ++$j) {
      my $r = Mnext_prime($p);
      for (my $t = Mmulint($m, $p) ; $t <= $n ; $t = Mmulint($t, $p)) {
        my $w = Mdivint($n, $t);
        last if $r > $w;
        $count += Mprime_count($w) - $j;
        for (my $r2 = $r ; $r2 <= $w ; $r2 = Mnext_prime($r2)) {
          my $u = Mvecprod($t, $r2, $r2);
          last if $u > $n;
          for (; $u <= $n ; $u = Mmulint($u, $r2)) {
             ++$count;
          }
        }
      }
      $p = $r;
    }

  }  else  {

    for (;  $p <= $s  ;  ++$j) {
      my $r = Mnext_prime($p);
      for (my $t = Mmulint($m, $p) ; $t <= $n ; $t = Mmulint($t, $p)) {
        my $s = Mrootint(Mdivint($n, $t), $k - 1);
        last if $r > $s;
        $count += _omega_prime_count_rec($k-1, $n,  $t, $r, $s, $j+1);
      }
      $p = $r;
    }

  }
  $count;
}
sub omega_prime_count {
  my($k,$n) = @_;
  _validate_positive_integer($k);
  _validate_positive_integer($n);

  return ($n >= 1) ? 1 : 0 if $k == 0;
  return prime_power_count($n) if $k == 1;
  # find a simple formula for k=2.

  # Naive method
  # my ($sum, $low) = (0, Mpn_primorial($k));
  # for (my $i = $low; $i <= $n; $i++) {
  #   $sum++ if Math::Prime::Util::prime_omega($i) == $k;
  # }
  # return $sum;

  # Recursive method from trizen
  return _omega_prime_count_rec($k, $n,  1, 2);
}
sub ramanujan_prime_count {
  my($low,$high) = @_;
  if (defined $high) { _validate_positive_integer($low); }
  else               { ($low,$high) = (2, $low);         }
  _validate_positive_integer($high);
  my $sum = 0;
  while ($low <= $high) {
    my $seghigh = ($high-$high) + $low + 1e9 - 1;
    $seghigh = $high if $seghigh > $high;
    $sum += scalar(@{Math::Prime::Util::ramanujan_primes($low,$seghigh)});
    $low = $seghigh + 1;
  }
  $sum;
}

sub twin_prime_count_approx {
  my($n) = @_;
  return twin_prime_count(3,$n) if $n < 2000;
  $n = _upgrade_to_float($n) if ref($n);
  my $logn = log($n);
  # The loss of full Ei precision is a few orders of magnitude less than the
  # accuracy of the estimate, so save huge time and don't bother.
  my $li2 = Math::Prime::Util::ExponentialIntegral("$logn") + 2.8853900817779268147198494 - ($n/$logn);

  # Empirical correction factor
  my $fm;
  if    ($n <     4000) { $fm = 0.2952; }
  elsif ($n <     8000) { $fm = 0.3151; }
  elsif ($n <    16000) { $fm = 0.3090; }
  elsif ($n <    32000) { $fm = 0.3096; }
  elsif ($n <    64000) { $fm = 0.3100; }
  elsif ($n <   128000) { $fm = 0.3089; }
  elsif ($n <   256000) { $fm = 0.3099; }
  elsif ($n <   600000) { my($x0, $x1, $y0, $y1) = (1e6, 6e5, .3091, .3059);
                          $fm = $y0 + ($n - $x0) * ($y1-$y0) / ($x1 - $x0); }
  elsif ($n <  1000000) { my($x0, $x1, $y0, $y1) = (6e5, 1e6, .3062, .3042);
                          $fm = $y0 + ($n - $x0) * ($y1-$y0) / ($x1 - $x0); }
  elsif ($n <  4000000) { my($x0, $x1, $y0, $y1) = (1e6, 4e6, .3067, .3041);
                          $fm = $y0 + ($n - $x0) * ($y1-$y0) / ($x1 - $x0); }
  elsif ($n < 16000000) { my($x0, $x1, $y0, $y1) = (4e6, 16e6, .3033, .2983);
                          $fm = $y0 + ($n - $x0) * ($y1-$y0) / ($x1 - $x0); }
  elsif ($n < 32000000) { my($x0, $x1, $y0, $y1) = (16e6, 32e6, .2980, .2965);
                          $fm = $y0 + ($n - $x0) * ($y1-$y0) / ($x1 - $x0); }
  $li2 *= $fm * log(12+$logn)  if defined $fm;

  return int(1.32032363169373914785562422 * $li2 + 0.5);
}

sub semiprime_count_approx {
  my($n) = @_;
  return 0 if $n < 4;
  _validate_positive_integer($n);
  $n = "$n" + 0.00000001;
  my $l1 = log($n);
  my $l2 = log($l1);
  #my $est = $n * $l2 / $l1;
  #my $est = $n * ($l2 + 0.302) / $l1;
  my $est = ($n/$l1) * (0.11147910114 + 0.00223801350*$l1 + 0.44233207922*$l2 + 1.65236647896*log($l2));
  int(0.5+$est);
}

sub almost_prime_count_approx {
  my($k,$n) = @_;
  _validate_positive_integer($k);
  _validate_positive_integer($n);
  return ($n >= 1) if $k == 0;
  return Math::Prime::Util::prime_count_approx($n) if $k == 1;
  return Math::Prime::Util::semiprime_count_approx($n) if $k == 2;
  return 0 if ($n >> $k) == 0;

  if ($k <= 4) {
    my $lo = Math::Prime::Util::almost_prime_count_lower($k, $n);
    my $hi = Math::Prime::Util::almost_prime_count_upper($k, $n);
    return $lo + (($hi - $lo) >> 1);
  } else {
    return int(0.5 + _almost_prime_count_asymptotic($k,$n));
    #my $est = Math::Prime::Util::prime_count_approx($n);
    #my $loglogn = log(log(0.0 + "$n"));
    #for my $i (1 .. $k-1) { $est *= ($loglogn/$i); }
    #return int(0.5+$est);
  }
}

sub nth_twin_prime {
  my($n) = @_;
  return undef if $n < 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return (undef,3,5,11,17,29,41)[$n] if $n <= 6;

  my $p = Math::Prime::Util::nth_twin_prime_approx($n+200);
  my $tp = Math::Prime::Util::twin_primes($p);
  while ($n > scalar(@$tp)) {
    $n -= scalar(@$tp);
    $tp = Math::Prime::Util::twin_primes($p+1,$p+1e5);
    $p += 1e5;
  }
  return $tp->[$n-1];
}

sub nth_twin_prime_approx {
  my($n) = @_;
  _validate_positive_integer($n);
  return nth_twin_prime($n) if $n < 6;
  $n = _upgrade_to_float($n) if ref($n) || $n > 127e14;   # TODO lower for 32-bit
  my $logn = log($n);
  my $nlogn2 = $n * $logn * $logn;

  return int(5.158 * $nlogn2/log(9+log($n*$n))) if $n > 59 && $n <= 1092;

  my $lo = int(0.7 * $nlogn2);
  my $hi = int( ($n > 1e16) ? 1.1 * $nlogn2
              : ($n >  480) ? 1.7 * $nlogn2
                            : 2.3 * $nlogn2 + 3 );

  _binary_search($n, $lo, $hi,
                 sub{Math::Prime::Util::twin_prime_count_approx(shift)},
                 sub{ ($_[2]-$_[1])/$_[1] < 1e-15 } );
}

sub nth_semiprime {
  my $n = shift;
  return undef if $n < 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  return (undef,4,6,9,10,14,15,21,22)[$n] if $n <= 8;
  my $x = "$n" + 0.000000001; # Get rid of bigint so we can safely call log
  my $logx = log($x);
  my $loglogx = log($logx);
  my $a = ($n < 1000) ? 1.027 : ($n < 10000) ? 0.995 : 0.966;
  my $est = $a * $x * $logx / $loglogx;
  my $lo = ($n < 20000) ? int(0.97*$est)-1 : int(0.98*$est)-1;
  my $hi = ($n < 20000) ? int(1.07*$est)+1 : int(1.02*$est)+1;
  1+_binary_search($n,$lo,$hi, sub{Math::Prime::Util::semiprime_count(shift)});
}

sub nth_semiprime_approx {
  my $n = shift;
  return undef if $n < 0;  ## no critic qw(ProhibitExplicitReturnUndef)
  _validate_positive_integer($n);
  return (undef,4,6,9,10,14,15,21,22)[$n] if $n <= 8;
  $n = "$n" + 0.00000001;
  my $l1 = log($n);
  my $l2 = log($l1);
  my $est = 0.966 * $n * $l1 / $l2;
  return  ($est < INTMAX)  ?  int(0.5+$est)  :  Math::BigInt->new($est+0.5);
}

sub _almost_prime_count_asymptotic {
  my($k, $n) = @_;
  return 0 if ($n >> $k) == 0;
  return ($n >= 1) if $k == 0;

  my $x;
  if (ref($n) || $n > ~0) {
    require Math::BigFloat;
    Math::BigFloat->import();
    $x = Math::BigFloat->new($n);
  } else {
    $x = 0.0 + "$n";
  }
  my $logx = log($x);
  my $loglogx = log($logx);
  my $est = $x / $logx;
  $est *= ($loglogx/$_) for 1 .. $k-1;
  $est;  # Returns FP
}
sub _almost_prime_nth_asymptotic {
  my($k, $n) = @_;
  return 0 if $k == 0 || $n == 0;
  return Mpowint(2,$k) if $n == 1;

  my $x;
  if (ref($n) || $n > ~0) {
    require Math::BigFloat;
    Math::BigFloat->import();
    $x = Math::BigFloat->new($n);
  } else {
    $x = 0.0 + "$n";
  }
  my $logx = log($x);
  my $loglogx = log($logx);
  my $est = $x * $logx;
  $est *= ($_/$loglogx) for 1 .. $k-1;
  $est;  # Returns FP
}

sub almost_prime_count_lower {
  my($k, $n) = @_;

  return 0 if ($n >> $k) == 0;
  ($k, $n) = _kap_reduce_count($k, $n);
  return ($n >= 1) if $k == 0;
  return Math::Prime::Util::prime_count_lower($n) if $k == 1;

  my $bound = 0;
  my $x = 0.0 + "$n";
  my $logx = log($x);
  my $loglogx = log($logx);
  my $logplus = $loglogx + 0.26153;

  if ($k == 2) {
    if ($x <= 1e12) {
      $bound = 0.7716 * $x * ($loglogx + 0.261536) / $logx;
    } else {
      # Bayless Theorem 5.2
      $bound = ($x * ($loglogx+0.1769)/$logx) * (1 + 0.4232/$logx);
    }
  } elsif ($k == 3) {
    # Kinlaw Theorem 1 (with multiplier = 1 -- using 1.04 is not proven)
    $bound = $x * $loglogx * $loglogx / (2*$logx);
    $bound *= ($x <= 500194) ? 0.8418 : ($x <= 3184393786) ? 1.0000 : 1.04;
  } elsif ($k == 4) {
    $bound = 0.4999 * $x * $logplus*$logplus*$logplus / (6*$logx);
  } else {
    # TODO this is not correct!
    $bound = 0.8 * _almost_prime_count_asymptotic($k,$n);
  }
  $bound = 1 if $bound < 1;  # We would have returned zero earlier
  int($bound);
}
sub almost_prime_count_upper {
  my($k, $n) = @_;

  return 0 if ($n >> $k) == 0;
  ($k, $n) = _kap_reduce_count($k, $n);
  return ($n >= 1) if $k == 0;
  return Math::Prime::Util::prime_count_upper($n) if $k == 1;

  my $bound = 0;
  my $x = 0.0 + "$n";
  my $logx = log($x);
  my $loglogx = log($logx);
  my $logplus = $loglogx + 0.26153;

  if ($k == 2) {
    # Bayless Corollary 5.1
    $bound = 1.028 * $x * ($loglogx + 0.261536) / $logx;
  } elsif ($k == 3) {
    # Bayless Theorem 5.3
    $bound = $x * ($logplus * $logplus + 1.055852) / (2*$logx);
    $bound *= ($x < 2**20) ? 0.7385 : ($x < 2**32) ? 0.8095 : 1.028;
  } elsif ($k == 4) {
    # Bayless Theorem 5.4
    if ($x <= 1e12) {
      $bound = $x * $logplus*$logplus*$logplus / (6*$logx);
      $bound *= ($x < 2**20) ? 0.6830 : ($x < 2**32) ? 0.7486 : 1.3043;
    } else {
      $bound = 1.028 * $x * $logplus*$logplus*$logplus / (6*$logx)
             + 1.028 * 0.511977 * $x * (log(log($x/4)) + 0.261536) / $logx;
    }
  } else {
    # A proven upper bound for all k and n doesn't exist as far as I know.
    # We will end up with something correct, but also *really* slow for
    # high k as well as estimating far too high.

    # TODO: This is insanely slow.  This has to be fixed.

    # Bayless (2018) Theorem 3.5.
    # First we have Pi_k(x) -- the upper bound for the square free kaps.
    $bound = 1.028 * $x / $logx;
    $bound *= ($logplus/$_) for 1..$k-1;
    # Second, we need to turn this into Tau_k(x).
    # We use the definition paragraph before Theorem 5.4.
    my $sigmalim = Msqrtint(Mdivint($n, Mpowint(2,$k-2)));
    my $ix = Math::BigInt->new("$x");
    Mforprimes( sub {
      $bound += almost_prime_count_upper($k-2, Mdivint($ix,Mmulint($_,$_)));
    }, 2, $sigmalim);
  }
  int($bound+1);
}

sub _kap_reduce_nth {   # returns reduction amount r
  my($k, $n) = @_;
  return 0 if $k <= 1;

  # We could calculate new values as needed.
  my @A078843 = (1, 2, 3, 5, 8, 14, 23, 39, 64, 103, 169, 269, 427, 676, 1065, 1669, 2628, 4104, 6414, 10023, 15608, 24281, 37733, 58503, 90616, 140187, 216625, 334527, 516126, 795632, 1225641, 1886570, 2901796, 4460359, 6851532, 10518476, 16138642, 24748319, 37932129, 58110457, 88981343, 136192537, 208364721, 318653143, 487128905, 744398307, 1137129971, 1736461477, 2650785552, 4045250962, 6171386419, 9412197641, 14350773978, 21874583987, 33334053149, 50783701654, 77348521640, 117780873397, 179306456282, 272909472119, 415284741506);
  my $r = 0;
  if ($k > $#A078843) {
    return 0 if $n >= $A078843[-1];
    $r = $k - $#A078843;
  }
  $r++ while $n < $A078843[$k-$r];
  $r;
}
sub _fast_small_nth_almost_prime {
  my($k,$n) = @_;
  croak "Internal kap out of range error" if $n >= 8 || $k < 2;
  return (0, 4,  6,  9, 10, 14, 15, 21)[$n] if $k == 2;
  return (0, 8, 12, 18, 20, 27, 28, 30)[$n] * (1 << ($k-3));
}

sub nth_almost_prime_upper {
  my($k, $n) = @_;
  return 0 if $n == 0;
  return (($n == 1) ? 1 : 0) if $k == 0;
  return Math::Prime::Util::nth_prime_upper($n) if $k == 1;
  return _fast_small_nth_almost_prime($k,$n) if $n < 8;

  my $r = _kap_reduce_nth($k,$n);
  if ($r > 0) {
    my $nth = Math::Prime::Util::nth_almost_prime_upper($k-$r, $n);
    return Mmulint($nth, Mpowint(2,$r));
  }

  my $lo = 5 * (1 << $k);   # $k >= 1, $n >= 8
  my $hi = 1 + _almost_prime_nth_asymptotic($k, $n);
  # We just guessed at hi, so bump it up until it's in range
  my $rhi = almost_prime_count_lower($k, $hi);
  while ($rhi < $n) {
    $lo = $hi+1;
    $hi = $hi + int(1.02 * ($hi/$rhi) * ($n - $rhi)) + 100;
    $rhi = almost_prime_count_lower($k, $hi);
  }
  while ($lo < $hi) {
    my $mid = $lo + (($hi-$lo) >> 1);
    if (almost_prime_count_lower($k,$mid) < $n) { $lo = $mid+1; }
    else                                        { $hi = $mid; }
  }
  $lo;
}
sub nth_almost_prime_lower {
  my($k, $n) = @_;
  return 0 if $n == 0;
  return (($n == 1) ? 1 : 0) if $k == 0;
  return Math::Prime::Util::nth_prime_lower($n) if $k == 1;
  return _fast_small_nth_almost_prime($k,$n) if $n < 8;

  my $r = _kap_reduce_nth($k,$n);
  if ($r > 0) {
    my $nth = Math::Prime::Util::nth_almost_prime_lower($k-$r, $n);
    return Mmulint($nth, Mpowint(2,$r));
  }

  my $lo = 5 * (1 << $k);   # $k >= 1, $n >= 8
  my $hi = 1 + _almost_prime_nth_asymptotic($k, $n);
  # We just guessed at hi, so bump it up until it's in range
  my $rhi = almost_prime_count_upper($k, $hi);
  while ($rhi < $n) {
    $lo = $hi+1;
    $hi = $hi + int(1.02 * ($hi/$rhi) * ($n - $rhi)) + 100;
    $rhi = almost_prime_count_upper($k, $hi);
  }

  while ($lo < $hi) {
    my $mid = $lo + (($hi-$lo) >> 1);
    if (almost_prime_count_upper($k,$mid) < $n) { $lo = $mid+1; }
    else                                        { $hi = $mid; }
  }
  $lo;
}

sub nth_almost_prime_approx {
  my($k, $n) = @_;
  return undef if $n == 0;
  return 1 << $k if $n == 1;
  return undef if $k == 0;  # n==1 already returned
  return Math::Prime::Util::nth_prime_approx($n) if $k == 1;
  return Math::Prime::Util::nth_semiprime_approx($n) if $k == 2;
  return _fast_small_nth_almost_prime($k,$n) if $n < 8;

  my $r = _kap_reduce_nth($k,$n);
  if ($r > 0) {
    my $nth = Math::Prime::Util::nth_almost_prime_approx($k-$r, $n);
    return Mmulint($nth, Mpowint(2,$r));
  }

  my $lo = Math::Prime::Util::nth_almost_prime_lower($k, $n);
  my $hi = Math::Prime::Util::nth_almost_prime_upper($k, $n);

  # TODO: Add interpolation speedup steps

  while ($lo < $hi) {
    my $mid = $lo + (($hi-$lo) >> 1);
    if (almost_prime_count_approx($k,$mid) < $n) { $lo = $mid+1; }
    else                                         { $hi = $mid; }
  }
  $lo;
}

sub nth_almost_prime {
  my($k, $n) = @_;
  return undef if $n == 0;
  return 1 << $k if $n == 1;
  return undef if $k == 0;  # n==1 already returned
  return Math::Prime::Util::nth_prime($n) if $k == 1;
  return Math::Prime::Util::nth_semiprime($n) if $k == 2;
  return _fast_small_nth_almost_prime($k,$n) if $n < 8;

  my $r = _kap_reduce_nth($k,$n);
  if ($r > 0) {
    my $nth = Math::Prime::Util::nth_almost_prime($k-$r, $n);
    return Mmulint($nth, Mpowint(2,$r));
  }

  my $lo = Math::Prime::Util::nth_almost_prime_lower($k, $n);
  my $hi = Math::Prime::Util::nth_almost_prime_upper($k, $n);

  # TODO: Add interpolation speedup steps

  while ($lo < $hi) {
    my $mid = $lo + (($hi-$lo) >> 1);
    if (almost_prime_count($k,$mid) < $n) { $lo = $mid+1; }
    else                                  { $hi = $mid; }
  }
  $lo;

  # Brutally inefficient algorithm.
  #my $i = 1 << $k;
  #while (1) {
  #  $i++ while !Math::Prime::Util::is_almost_prime($k,$i);
  #  return $i if --$n == 0;
  #  $i++;
  #}
}

sub nth_omega_prime {
  my($k, $n) = @_;
  return undef if $n == 0;
  return Mpn_primorial($k) if $n == 1;
  return undef if $k == 0;  # n==1 already returned

  # Very inefficient algorithm.
  my $i = Mpn_primorial($k);
  while (1) {
    $i++ while Math::Prime::Util::prime_omega($i) != $k;
    return $i if --$n == 0;
    $i++;
  }
}

sub nth_ramanujan_prime_upper {
  my $n = shift;
  return (0,2,11)[$n] if $n <= 2;
  $n = Math::BigInt->new("$n") if $n > (~0/3);
  my $nth = nth_prime_upper(3*$n);
  return $nth if $n < 10000;
  $nth = Math::BigInt->new("$nth") if $nth > (~0/177);
  if ($n < 1000000) { $nth = (177 * $nth) >> 8; }
  elsif ($n < 1e10) { $nth = (175 * $nth) >> 8; }
  else              { $nth = (133 * $nth) >> 8; }
  $nth = _bigint_to_int($nth) if ref($nth) && $nth->bacmp(BMAX) <= 0;
  $nth;
}
sub nth_ramanujan_prime_lower {
  my $n = shift;
  return (0,2,11)[$n] if $n <= 2;
  $n = Math::BigInt->new("$n") if $n > (~0/2);
  my $nth = nth_prime_lower(2*$n);
  $nth = Math::BigInt->new("$nth") if $nth > (~0/275);
  if ($n < 10000)   { $nth = (275 * $nth) >> 8; }
  elsif ($n < 1e10) { $nth = (262 * $nth) >> 8; }
  $nth = _bigint_to_int($nth) if ref($nth) && $nth->bacmp(BMAX) <= 0;
  $nth;
}
sub nth_ramanujan_prime_approx {
  my $n = shift;
  return (0,2,11)[$n] if $n <= 2;
  my($lo,$hi) = (nth_ramanujan_prime_lower($n),nth_ramanujan_prime_upper($n));
  $lo + (($hi-$lo)>>1);
}
sub ramanujan_prime_count_upper {
  my $n = shift;
  return (($n < 2) ? 0 : 1) if $n < 11;
  my $lo = int(prime_count_lower($n) / 3);
  my $hi = prime_count_upper($n) >> 1;
  1+_binary_search($n, $lo, $hi,
                   sub{Math::Prime::Util::nth_ramanujan_prime_lower(shift)});
}
sub ramanujan_prime_count_lower {
  my $n = shift;
  return (($n < 2) ? 0 : 1) if $n < 11;
  my $lo = int(prime_count_lower($n) / 3);
  my $hi = prime_count_upper($n) >> 1;
  _binary_search($n, $lo, $hi,
                 sub{Math::Prime::Util::nth_ramanujan_prime_upper(shift)});
}
sub ramanujan_prime_count_approx {
  my $n = shift;
  return (($n < 2) ? 0 : 1) if $n < 11;
  #$n = _upgrade_to_float($n) if ref($n) || $n > 2e16;
  my $lo = ramanujan_prime_count_lower($n);
  my $hi = ramanujan_prime_count_upper($n);
  _binary_search($n, $lo, $hi,
                 sub{Math::Prime::Util::nth_ramanujan_prime_approx(shift)},
                 sub{ ($_[2]-$_[1])/$_[1] < 1e-15 } );
}

sub _sum_primes_n {
  my $n = shift;
  return (0,0,2,5,5)[$n] if $n < 5;
  my $r = Msqrtint($n);
  my $r2 = $r + Mdivint($n, $r+1);
  my(@V,@S);
  for my $k (0 .. $r2) {
    my $v = ($k <= $r) ? $k : Mdivint($n,($r2-$k+1));
    $V[$k] = $v;
    $S[$k] = Maddint(
              Mrshiftint(Mmulint($v, $v-1)),
              $v-1);
  }
  for my $p (2 .. $r) {
    next unless $S[$p] > $S[$p-1];
    my $sp = $S[$p-1];
    my $p2 = Mmulint($p,$p);
    for my $v (reverse @V) {
      last if $v < $p2;
      my($a,$b) = ($v,Mdivint($v,$p));
      $a = $r2 - Mdivint($n,$a) + 1 if $a > $r;
      $b = $r2 - Mdivint($n,$b) + 1 if $b > $r;
      $S[$a] -= Mmulint($p, $S[$b]-$sp);
      #$S[$a] = Msubint($S[$a], Mmulint($p, Msubint($S[$b],$sp)));
    }
  }
  $S[$r2];
}
sub sum_primes {
  my($low,$high) = @_;
  if (defined $high) { _validate_positive_integer($low); }
  else               { ($low,$high) = (2, $low);         }
  _validate_positive_integer($high);
  my $sum = 0;

  return $sum if $high < $low;

  # It's very possible we're here because they've counted too high.  Skip fwd.
  if ($low <= 2 && $high >= 29505444491) {
    ($low, $sum) = (29505444503, Math::BigInt->new("18446744087046669523"));
  }

  return $sum if $low > $high;

  # Easy, not unreasonable, but seems slower than the windowed sum.
  # return _sum_primes_n($high) if $low <= 2;

  # Performance decision, which to use.  TODO: This needs tuning!
  if ($high <= ~0 && $high > 10_000_000 && ($high-$low) > $high/50 && !Math::Prime::Util::prime_get_config()->{'xs'}) {
    my $hsum = _sum_primes_n($high);
    my $lsum = ($low <= 2) ? 0 : _sum_primes_n($low - 1);
    return $hsum - $lsum;
  }

  # Sum in windows.
  # TODO: consider some skipping forward with small tables.
  my $xssum = (MPU_64BIT && $high < 6e14 && Math::Prime::Util::prime_get_config()->{'xs'});
  my $step = ($xssum && $high > 5e13) ? 1_000_000 : 11_000_000;
  Math::Prime::Util::prime_precalc(Msqrtint($high));
  while ($low <= $high) {
    my $next = Maddint($low, $step) - 1;
    $next = $high if $next > $high;
    $sum = Maddint($sum,
            ($xssum) ? Math::Prime::Util::sum_primes($low,$next)
                     : Mvecsum( @{Math::Prime::Util::primes($low,$next)} ));
    last if $next == $high;
    $low = Maddint($next,1);
  }
  $sum;
}

sub print_primes {
  my($low,$high,$fd) = @_;
  if (defined $high) { _validate_positive_integer($low); }
  else               { ($low,$high) = (2, $low);         }
  _validate_positive_integer($high);

  $fd = fileno(STDOUT) unless defined $fd;
  open(my $fh, ">>&=", $fd);  # TODO .... or die

  if ($high >= $low) {
    my $p1 = $low;
    while ($p1 <= $high) {
      my $p2 = $p1 + 15_000_000 - 1;
      $p2 = $high if $p2 > $high;
      if ($Math::Prime::Util::_GMPfunc{"sieve_primes"}) {
        print $fh "$_\n" for Math::Prime::Util::GMP::sieve_primes($p1,$p2,0);
      } else {
        print $fh "$_\n" for @{primes($p1,$p2)};
      }
      $p1 = $p2+1;
    }
  }
  close($fh);
}


#############################################################################

sub _mulmod {
  my($x, $y, $n) = @_;
  return (($x * $y) % $n) if ($x|$y) < MPU_HALFWORD;
  #return (($x * $y) % $n) if ($x|$y) < MPU_HALFWORD || $y == 0 || $x < int(~0/$y);
  my $r = 0;
  $x %= $n if $x >= $n;
  $y %= $n if $y >= $n;
  ($x,$y) = ($y,$x) if $x < $y;
  if ($n <= (~0 >> 1)) {
    while ($y > 1) {
      if ($y & 1) { $r += $x;  $r -= $n if $r >= $n; }
      $y >>= 1;
      $x += $x;  $x -= $n if $x >= $n;
    }
    if ($y & 1) { $r += $x;  $r -= $n if $r >= $n; }
  } else {
    while ($y > 1) {
      if ($y & 1) { $r = $n-$r;  $r = ($x >= $r) ? $x-$r : $n-$r+$x; }
      $y >>= 1;
      $x = ($x > ($n - $x))  ?  ($x - $n) + $x  :  $x + $x;
    }
    if ($y & 1) { $r = $n-$r;  $r = ($x >= $r) ? $x-$r : $n-$r+$x; }
  }
  $r;
}
sub _addmod {
  my($x, $y, $n) = @_;
  $x %= $n if $x >= $n;
  $y %= $n if $y >= $n;
  if (($n-$x) <= $y) {
    ($x,$y) = ($y,$x) if $y > $x;
    $x -= $n;
  }
  $x + $y;
}

# Note that Perl 5.6.2 with largish 64-bit numbers will break.  As usual.
sub _native_powmod {
  my($n, $power, $m) = @_;
  my $t = 1;
  $n = $n % $m;
  while ($power) {
    $t = ($t * $n) % $m if ($power & 1);
    $power >>= 1;
    $n = ($n * $n) % $m if $power;
  }
  $t;
}

sub _powmod {
  my($n, $power, $m) = @_;
  my $t = 1;

  $n %= $m if $n >= $m;
  if ($m < MPU_HALFWORD) {
    while ($power) {
      $t = ($t * $n) % $m if ($power & 1);
      $power >>= 1;
      $n = ($n * $n) % $m if $power;
    }
  } else {
    while ($power) {
      $t = _mulmod($t, $n, $m) if ($power & 1);
      $power >>= 1;
      $n = _mulmod($n, $n, $m) if $power;
    }
  }
  $t;
}

sub powint {
  my($a, $b) = @_;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::powint($a,$b))
    if $Math::Prime::Util::_GMPfunc{"powint"};
  croak "powint: exponent must be >= 0" if $b < 0;

  # Special cases for small a and b
  if ($a >= -1 && $a <= 4) {
    return ($b == 0) ? 1 : 0 if $a == 0;
    return 1 if $a == 1;
    return ($b % 2) ? -1 : 1 if $a == -1;
    return 1 << $b if $a == 2 && $b < MPU_MAXBITS;
    return 1 << (2*$b) if $a == 4 && $b < MPU_MAXBITS/2;
  }
  return 1 if $b == 0;
  return $a if $b == 1;

  return $a ** $b if ref($a) || ref($b);

  # Try normal integer exponentiation (floating point)
  my $ires = "" . int($a ** $b);
  return $ires if abs($ires) < (1 << 53);

  my $res = Math::BigInt->new($a)->bpow($b);
  $res = _bigint_to_int($res) if $res->bacmp(BMAX) <= 0 && $res->bcmp(-(BMAX>>1)) > 0;
  $res;
}

sub mulint {
  my($a, $b) = @_;
  return 0 if $a == 0 || $b == 0;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::mulint($a,$b))
    if $Math::Prime::Util::_GMPfunc{"mulint"};
  my $prod = $a*$b;
  return $prod if ref($a) || ref($b);
  return $prod if $a > 0 && $b > 0 && int(INTMAX/$a) > $b;
  # return Mvecprod($a,$b);
  my $res = Math::BigInt->new("$a")->bmul("$b");
  $res = _bigint_to_int($res) if $res->bacmp(BMAX) <= 0 && $res->bcmp(-(BMAX>>1)) > 0;
  $res;
}
sub addint {
  my($a, $b) = @_;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::addint($a,$b))
    if $Math::Prime::Util::_GMPfunc{"addint"};
  my $sum = $a+$b;
  return $sum if ref($a) || ref($b);
  return $sum if $a >= 0 && $b >= 0 && int(INTMAX-$a) >= $b;
  # return Mvecsum(@_);
  my $res = Math::BigInt->new("$a")->badd("$b");
  $res = _bigint_to_int($res) if $res->bacmp(BMAX) <= 0 && $res->bcmp(-(BMAX>>1)) > 0;
  $res;
}
sub subint {
  my($a, $b) = @_;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::subint($a,$b))
    if $Math::Prime::Util::_GMPfunc{"subint"};
  my $sum = $a-$b;
  return $sum if ref($a) || ref($b);
  my $res = Math::BigInt->new("$a")->bsub("$b");
  $res = _bigint_to_int($res) if $res->bacmp(BMAX) <= 0 && $res->bcmp(-(BMAX>>1)) > 0;
  $res;
}
sub add1int {
  my($n) = @_;
  _validate_integer($n);
  return (!ref($n) && $n >= INTMAX)  ?  Math::BigInt->new("$n")->binc  :  $n+1;
}
sub sub1int {
  my($n) = @_;
  _validate_integer($n);
  return (!ref($n) && $n <= INTMIN)  ?  Math::BigInt->new("$n")->bdec  :  $n-1;
}

# For division / modulo, see:
#
# https://www.researchgate.net/publication/234829884_The_Euclidean_definition_of_the_functions_div_and_mod
#
# https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/divmodnote-letter.pdf

sub _tquotient {
  my($a,$b) = @_;
  return $a if $b == 1;

  # Large unsigned values cause all sorts of consistency issues, so => bigint.
  $a = Math::BigInt->new("$a") if !ref($a) && ($a > SINTMAX || $b > SINTMAX);

  return -$a if $b == -1;  # $a is always able to be safely negated now

  if (ref($a) || ref($b)) {
    $a = Math::BigInt->new("$a") unless ref($a);
    # Earlier versions of Math::BigInt did not use floor division for bdiv.
    return $a->copy->btdiv($b) if $Math::BigInt::VERSION >= 1.999716;
    $b = Math::BigInt->new("$b") unless ref($b);
    my $A = $a->copy->babs;
    my $B = $b->copy->babs;
    my $Q = $A->bdiv($B);
    return -$Q if ($a < 0 && $b > 0) || ($b < 0 && $a > 0);
    return $Q;
  } else {
    use integer;  # Beware: this is >>> SIGNED <<< integer.
    # Don't trust native division for negative inputs.  C89 impl defined.
    return -(-$a /  $b)  if $a < 0 && $b > 0;
    return -( $a / -$b)  if $b < 0 && $a > 0;
    return  (-$a / -$b)  if $a < 0 && $b < 0;
    return  ( $a /  $b);
  }
}
# Truncated Division
sub tdivrem {
  my($a,$b) = @_;
  _validate_integer($a);
  _validate_integer($b);
  croak "tdivrem: divide by zero" if $b == 0;
  my($q,$r);
  if (!ref($a) && !ref($b) && $a>=0 && $b>=0 && $a<SINTMAX && $b<SINTMAX) {
    use integer; $q = $a / $b;
  } else {
    $q = _tquotient($a, $b);
  }
  $r = $a - $b * $q;
  ($q,$r);
}
# Floored Division
sub fdivrem {
  my($a,$b) = @_;
  _validate_integer($a);
  _validate_integer($b);
  croak "fdivrem: divide by zero" if $b == 0;
  my($q,$r);
  if (!ref($a) && !ref($b) && $a>=0 && $b>=0 && $a<SINTMAX && $b<SINTMAX) {
    use integer; $q = $a / $b;
  } else {
    $q = _tquotient($a, $b);
  }
  $r = $a - $b * $q;
  # qe = qt-I     re = rt+I*d    I = (rt >= 0) ? 0 : (b>0) ? 1 : -1;
  # qf = qt-I     rf = rt+I*d    I = (signum(rt) = -signum(b)) 1 : 0
  if ( ($r < 0 && $b > 0) || ($r > 0 && $b < 0) )
    { $q--; $r += $b; }
  $q = _bigint_to_int($q) if ref($q) && $q->bcmp(BMAX) <= 0 && $q->bcmp(BMIN) >= 0;
  $r = _bigint_to_int($r) if ref($r) && $r->bcmp(BMAX) <= 0 && $r->bcmp(BMIN) >= 0;
  ($q,$r);
}
# Euclidean Division
sub divrem {
  my($a,$b) = @_;
  _validate_integer($a);
  _validate_integer($b);
  croak "divrem: divide by zero" if $b == 0;
  my($q,$r);
  if (!ref($a) && !ref($b) && $a>=0 && $b>=0 && $a<SINTMAX && $b<SINTMAX) {
    use integer; $q = $a / $b;
  } else {
    $q = _tquotient($a, $b);
  }
  $r = $a - $b * $q;
  if ($r <0) {
    if ($b > 0) { $q--; $r += $b; }
    else        { $q++; $r -= $b; }
  }
  $q = _bigint_to_int($q) if ref($q) && $q->bcmp(BMAX) <= 0 && $q->bcmp(BMIN) >= 0;
  $r = _bigint_to_int($r) if ref($r) && $r->bcmp(BMAX) <= 0 && $r->bcmp(BMIN) >= 0;
  ($q,$r);
}

sub divint {
  (fdivrem(@_))[0];
}
sub modint {
  (fdivrem(@_))[1];
}

sub absint {
  my($n) = @_;
  _validate_integer($n);
  return (($n >= 0) ? $n : -$n) if ref($n);
  $n =~ s/^-// if $n <= 0;
  Math::Prime::Util::_reftyped($_[0], $n);
}
sub negint {
  my($n) = @_;
  _validate_integer($n);
  return 0 if $n == 0;  # Perl 5.6 has to have this: if $n=0 => -$n = -0
  return -$n if ref($n) || $n < (~0 >> 1);
  if ($n > 0) { $n = "-$n"; }
  else        { $n =~ s/^-//; }
  Math::Prime::Util::_reftyped($_[0], $n);
}
sub signint {
  my($n) = @_;
  _validate_integer($n);
  $n <=> 0;
}
sub cmpint {
  my($a, $b) = @_;
  _validate_integer($a);
  _validate_integer($b);
  $a <=> $b;
}

sub lshiftint {
  my($n, $k) = @_;
  my $k2 = (!defined $k) ? 2 : ($k < MPU_MAXBITS) ? (1<<$k) : Mpowint(2,$k);
  Mmulint($n, $k2);
}
sub rshiftint {
  my($n, $k) = @_;
  my $k2 = (!defined $k) ? 2 : ($k < MPU_MAXBITS) ? (1<<$k) : Mpowint(2,$k);
  (Math::Prime::Util::tdivrem($n, $k2))[0];
}

sub rashiftint {
  my($n, $k) = @_;
  my $k2 = (!defined $k) ? 2 : ($k < MPU_MAXBITS) ? (1<<$k) : Mpowint(2,$k);
  Mdivint($n, $k2);
}

# Make sure to work around RT71548, Math::BigInt::Lite,
# and use correct lcm semantics.
sub gcd {
  # First see if all inputs are non-bigints  5-10x faster if so.
  if (0 == scalar(grep { ref($_) } @_)) {
    my($x,$y) = (shift || 0, 0);
    $x = -$x if $x < 0;
    while (@_) {
      $y = shift;
      while ($y) {  ($x,$y) = ($y, $x % $y);  }
      $x = -$x if $x < 0;
    }
    return $x;
  }
  my $gcd = Math::BigInt::bgcd( map {
    my $v = (($_ < 2147483647 && !ref($_)) || ref($_) eq 'Math::BigInt') ? $_ : "$_";
    $v;
  } @_ );
  $gcd = _bigint_to_int($gcd) if $gcd->bacmp(BMAX) <= 0;
  return $gcd;
}
sub lcm {
  return 0 unless @_;
  my $lcm = Math::BigInt::blcm( map {
    my $v = (($_ < 2147483647 && !ref($_)) || ref($_) eq 'Math::BigInt') ? $_ : "$_";
    return 0 if $v == 0;
    $v = -$v if $v < 0;
    $v;
  } @_ );
  $lcm = _bigint_to_int($lcm) if $lcm->bacmp(BMAX) <= 0;
  return $lcm;
}
sub gcdext {
  my($x,$y) = @_;
  if ($x == 0) { return (0, (-1,0,1)[($y>=0)+($y>0)], abs($y)); }
  if ($y == 0) { return ((-1,0,1)[($x>=0)+($x>0)], 0, abs($x)); }

  if ($Math::Prime::Util::_GMPfunc{"gcdext"}) {
    my($a,$b,$g) = Math::Prime::Util::GMP::gcdext($x,$y);
    $a = Math::Prime::Util::_reftyped($_[0], $a);
    $b = Math::Prime::Util::_reftyped($_[0], $b);
    $g = Math::Prime::Util::_reftyped($_[0], $g);
    return ($a,$b,$g);
  }

  my($a,$b,$g,$u,$v,$w);
  if (abs($x) < (~0>>1) && abs($y) < (~0>>1)) {
    $x = _bigint_to_int($x) if ref($x) eq 'Math::BigInt';
    $y = _bigint_to_int($y) if ref($y) eq 'Math::BigInt';
    ($a,$b,$g,$u,$v,$w) = (1,0,$x,0,1,$y);
    while ($w != 0) {
      my $r = $g % $w;
      my $q = int(($g-$r)/$w);
      ($a,$b,$g,$u,$v,$w) = ($u,$v,$w,$a-$q*$u,$b-$q*$v,$r);
    }
  } else {
    ($a,$b,$g,$u,$v,$w) = (BONE->copy,BZERO->copy,Math::BigInt->new("$x"),
                           BZERO->copy,BONE->copy,Math::BigInt->new("$y"));
    while ($w != 0) {
      # Using the array bdiv is logical, but is the wrong sign.
      my $r = $g->copy->bmod($w);
      my $q = $g->copy->bsub($r)->bdiv($w);
      ($a,$b,$g,$u,$v,$w) = ($u,$v,$w,$a-$q*$u,$b-$q*$v,$r);
    }
    $a = _bigint_to_int($a) if $a->bacmp(BMAX) <= 0;
    $b = _bigint_to_int($b) if $b->bacmp(BMAX) <= 0;
    $g = _bigint_to_int($g) if $g->bacmp(BMAX) <= 0;
  }
  if ($g < 0) { ($a,$b,$g) = (-$a,-$b,-$g); }
  return ($a,$b,$g);
}

sub chinese {
  return 0 unless scalar @_;
  my($lcm, $sum);

  if ($Math::Prime::Util::_GMPfunc{"chinese"} && $Math::Prime::Util::GMP::VERSION >= 0.42) {
    $sum = Math::Prime::Util::GMP::chinese(@_);
    if (defined $sum) {
      $sum = Math::BigInt->new("$sum");
      $sum = _bigint_to_int($sum) if ref($sum) && $sum->bacmp(BMAX) <= 0;
    }
    return $sum;
  }

  # Validate, copy, and do abs on the inputs.
  my @items;
  foreach my $aref (@_) {
    die "chinese arguments are two-element array references"
      unless ref($aref) eq 'ARRAY' && scalar @$aref == 2;
    my($a,$n) = @$aref;
    _validate_integer($a);
    _validate_integer($n);
    return if $n == 0;
    $n = -$n if $n < 0;
    push @items, [$a,$n];
  }
  return Mmodint($items[0]->[0], $items[0]->[1]) if scalar @items == 1;
  @items = sort { $b->[1] <=> $a->[1] } @items;
  foreach my $aref (@items) {
    my($ai, $ni) = @$aref;
    $ai = Math::BigInt->new("$ai") if !ref($ai) && (abs($ai) > (~0>>1) || OLD_PERL_VERSION);
    $ni = Math::BigInt->new("$ni") if !ref($ni) && (abs($ni) > (~0>>1) || OLD_PERL_VERSION);
    if (!defined $lcm) {
      ($sum,$lcm) = ($ai % $ni, $ni);
      next;
    }
    # gcdext
    my($u,$v,$g,$s,$t,$w) = (1,0,$lcm,0,1,$ni);
    while ($w != 0) {
      my $r = $g % $w;
      my $q = ref($g)  ?  $g->copy->bsub($r)->bdiv($w)  :  int(($g-$r)/$w);
      ($u,$v,$g,$s,$t,$w) = ($s,$t,$w,$u-$q*$s,$v-$q*$t,$r);
    }
    ($u,$v,$g) = (-$u,-$v,-$g)  if $g < 0;
    return if $g != 1 && ($sum % $g) != ($ai % $g);  # Not co-prime
    $s = -$s if $s < 0;
    $t = -$t if $t < 0;
    # Convert to bigint if necessary.  Performance goes to hell.
    if (!ref($lcm) && ($lcm*$s) > ~0) { $lcm = Math::BigInt->new("$lcm"); }
    if (ref($lcm)) {
      $lcm->bmul("$s");
      my $m1 = Math::BigInt->new("$v")->bmul("$s")->bmod($lcm);
      my $m2 = Math::BigInt->new("$u")->bmul("$t")->bmod($lcm);
      $m1->bmul("$sum")->bmod($lcm);
      $m2->bmul("$ai")->bmod($lcm);
      $sum = $m1->badd($m2)->bmod($lcm);
    } else {
      $lcm *= $s;
      $u += $lcm if $u < 0;
      $v += $lcm if $v < 0;
      my $vs = _mulmod($v,$s,$lcm);
      my $ut = _mulmod($u,$t,$lcm);
      my $m1 = _mulmod($sum,$vs,$lcm);
      my $m2 = _mulmod($ut,$ai % $lcm,$lcm);
      $sum = _addmod($m1, $m2, $lcm);
    }
  }
  $sum = _bigint_to_int($sum) if ref($sum) && $sum->bacmp(BMAX) <= 0;
  $sum;
}

sub _from_128 {
  my($hi, $lo) = @_;
  return 0 unless defined $hi && defined $lo;
  #print "hi $hi lo $lo\n";
  (Math::BigInt->new("$hi") << MPU_MAXBITS) + $lo;
}

sub vecsum {
  return Math::Prime::Util::_reftyped($_[0], @_ ? $_[0] : 0)  if @_ <= 1;

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::vecsum(@_))
    if $Math::Prime::Util::_GMPfunc{"vecsum"};
  my $sum = 0;
  foreach my $v (@_) {
    $sum += $v;
    if ($sum > (INTMAX-250) || $sum < (INTMIN+250)) {
      # Sum again from the start using bigint sum
      $sum = BZERO->copy;
      $sum->badd("$_") for @_;
      return $sum;
    }
  }
  $sum;
}

sub vecprod {
  return 1 unless @_;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::vecprod(@_))
    if $Math::Prime::Util::_GMPfunc{"vecprod"};
  # Product tree:
  my $prod = _product(0, $#_, [map { Math::BigInt->new("$_") } @_]);
  # Linear:
  # my $prod = BONE->copy;  $prod *= "$_" for @_;
  $prod = _bigint_to_int($prod) if $prod->bacmp(BMAX) <= 0 && $prod->bcmp(-(BMAX>>1)) > 0;
  $prod;
}

sub vecmin {
  return unless @_;
  my $min = shift;
  for (@_) { $min = $_ if $_ < $min; }
  $min;
}
sub vecmax {
  return unless @_;
  my $max = shift;
  for (@_) { $max = $_ if $_ > $max; }
  $max;
}

sub vecextract {
  my($aref, $mask) = @_;

  return @$aref[@$mask] if ref($mask) eq 'ARRAY';

  # This is concise but very slow.
  # map { $aref->[$_] }  grep { $mask & (1 << $_) }  0 .. $#$aref;

  my($i, @v) = (0);
  while ($mask) {
    push @v, $i if $mask & 1;
    $mask >>= 1;
    $i++;
  }
  @$aref[@v];
}

sub vecequal {
  my($aref, $bref) = @_;
  croak "vecequal element not scalar or array reference"
    unless ref($aref) eq 'ARRAY' && ref($bref) eq 'ARRAY';
  return 0 unless $#$aref == $#$bref;
  my $i = 0;
  for my $av (@$aref) {
    my $bv = $bref->[$i++];
    next if !defined $av && !defined $bv;
    return 0 if !defined $av || !defined $bv;
    if ( (ref($av) =~ /^(ARRAY|HASH|CODE|FORMAT|IO|REGEXP)$/i) ||
         (ref($bv) =~ /^(ARRAY|HASH|CODE|FORMAT|IO|REGEXP)$/i) ) {
      next if (ref($av) eq ref($bv)) && vecequal($av, $bv);
      return 0;
    }
    # About 7x faster if we skip the validates.
    # _validate_integer($av);
    # _validate_integer($bv);
    return 0 unless $av eq $bv;
  }
  1;
}

sub sumdigits {
  my($n,$base) = @_;
  my $sum = 0;
  $base =  2 if !defined $base && $n =~ s/^0b//;
  $base = 16 if !defined $base && $n =~ s/^0x//;
  if (!defined $base || $base == 10) {
    $n =~ tr/0123456789//cd;
    $sum += $_ for (split(//,$n));
  } else {
    croak "sumdigits: invalid base $base" if $base < 2;
    my $cmap = substr("0123456789abcdefghijklmnopqrstuvwxyz",0,$base);
    for my $c (split(//,lc($n))) {
      my $p = index($cmap,$c);
      $sum += $p if $p > 0;
    }
  }
  $sum;
}

sub invmod {
  my($a,$n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  return if $a == 0;
  if ($n > ~0) {
    my $invmod = Math::BigInt->new("$a")->bmodinv("$n");
    return if !defined $invmod || $invmod->is_nan;
    $invmod = _bigint_to_int($invmod) if $invmod->bacmp(BMAX) <= 0;
    return $invmod;
  }
  my($t,$nt,$r,$nr) = (0, 1, $n, $a % $n);
  while ($nr != 0) {
    # Use mod before divide to force correct behavior with high bit set
    my $quot = int( ($r-($r % $nr))/$nr );
    ($nt,$t) = ($t-$quot*$nt,$nt);
    ($nr,$r) = ($r-$quot*$nr,$nr);
  }
  return if $r > 1;
  $t += $n if $t < 0;
  $t;
}



# Tonelli-Shanks
sub _sqrtmod_prime {
  my($a, $p) = @_;
  my($x, $q, $e, $t, $z, $r, $m, $b);
  my $Q = Msubint($p,1);

  if (($p % 4) == 3) {
    $r = Mpowmod($a, Mrshiftint(Maddint($p,1),2), $p);
    return undef unless Mmulmod($r,$r,$p) == $a;
    return $r;
  }
  if (($p % 8) == 5) {
    $m = Maddmod($a,$a,$p);
    $t = Mpowmod($m, Mrshiftint(Msubint($p,5),3), $p);
    $z = Mmulmod($m, Mmulmod($t,$t,$p), $p);
    $r = Mmulmod($t, Mmulmod($a, Msubmod($z,1,$p), $p), $p);
    return undef unless Mmulmod($r,$r,$p) == $a;
    return $r;
  }

  # Verify Euler's criterion for odd p
  return undef if $p != 2 && Mpowmod($a, Mrshiftint($Q,1), $p) != 1;

  # Cohen Algorithm 1.5.1.  Tonelli-Shanks.
  $e = Mvaluation($Q, 2);
  $q = Mdivint($Q, Mpowint(2,$e));
  $t = 3;
  while (Mkronecker($t,$p) != -1) {
    $t += 2;
    return undef if $t == 201 && !Mis_prime($p);
  }
  $z = Mpowmod($t, $q, $p);
  $b = Mpowmod($a, $q, $p);
  $r = $e;
  $q = ($q+1) >> 1;
  $x = Mpowmod($a, $q, $p);
  while ($b != 1) {
    $t = $b;
    for ($m = 0;  $m < $r && $t != 1;  $m++) {
      $t = Mmulmod($t, $t, $p);
    }
    $t = Mpowmod($z, Mlshiftint(1, $r-$m-1), $p);
    $x = Mmulmod($x, $t, $p);
    $z = Mmulmod($t, $t, $p);
    $b = Mmulmod($b, $z, $p);
    $r = $m;
  }
  # Expected to always be true.
  return undef unless Mmulmod($x,$x,$p) == $a;
  return $x;
}

sub _sqrtmod_prime_power {
  my($a,$p,$e) = @_;
  my($r,$s);

  if ($e == 1) {
    $a %= $p if $a >= $p;
    return $a if $p == 2 || $a == 0;
    $r = _sqrtmod_prime($a,$p);
    return (defined $r && (Mmulmod($r,$r,$p) == $a) ? $r : undef);
  }

  my $n = Mpowint($p,$e);
  my $pk = Mmulint($p,$p);

  return 0 if ($a % $n) == 0;

  if (($a % $pk) == 0) {
    my $apk = Mdivint($a, $pk);
    $s = _sqrtmod_prime_power($apk, $p, $e-2);
    return undef unless defined $s;
    return Mmulint($s,$p);
  }

  return undef if ($a % $p) == 0;

  my $ered = ($p > 2 || $e < 5)  ?  ($e+1) >> 1  :  ($e+3) >> 1;
  $s = _sqrtmod_prime_power($a,$p,$ered);
  return undef unless defined $s;

  my $np  = ($p == 2)  ?  Mmulint($n,$p)  :  $n;
  my $t1  = Msubmod($a, Mmulmod($s,$s,$np), $np);
  my $t2  = Maddmod($s, $s, $np);
  my $gcd = Mgcd($t1, $t2);
  $r = Maddmod($s, Mdivmod(Mdivint($t1,$gcd),Mdivint($t2,$gcd),$n), $n);
  return ((Mmulmod($r,$r,$n) == ($a % $n)) ? $r : undef);
}

sub _sqrtmod_composite {
  my($a,$n) = @_;

  return undef if $n <= 0;
  $a %= $n if $a >= $n;
  return $a if $n <= 2 || $a <= 1;
  return Msqrtint($a) if _is_perfect_square($a);

  my $N = 1;
  my $r = 0;
  foreach my $F (Mfactor_exp($n)) {
    my($f,$e) = @$F;
    my $fe = Mpowint($f, $e);
    my $s = _sqrtmod_prime_power($a, $f, $e);
    return undef unless defined $s;
    my $inv = Minvmod($N, $fe);
    my $t = Mmulmod($inv, Msubmod($s % $fe, $r % $fe, $fe), $fe);
    $r = Maddmod($r, Mmulmod($N,$t,$n), $n);
    $N = Mmulint($N, $fe);
  }
  #croak "Bad _sqrtmod_composite root $a,$n" unless Mmulmod($r,$r,$n) == $a;
  $r;
}

sub sqrtmod {
  my($a,$n) = @_;
  _validate_integer($a);
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  $a = Mmodint($a,$n);

  my $r = _sqrtmod_composite($a,$n);
  if (defined $r) {
    $r = $n-$r if $n-$r < $r;
    #croak "Bad _sqrtmod_composite root $a,$n" unless Mmulmod($r,$r,$n) == $a;
  }
  return $r;
}




# helper function for allsqrtmod() - return list of all square roots of
# a (mod p^k), assuming a integer, p prime, k positive integer.
sub _allsqrtmodpk {
  my($a,$p,$k) = @_;
  my $pk = Mpowint($p,$k);
  unless ($a % $p) {
    unless ($a % ($pk)) {
      # if p^k divides a, we need the square roots of zero, satisfied by
      # ip^j with 0 <= i < p^{floor(k/2)}, j = p^{ceil(k/2)}
      my $low = Mpowint($p,$k >> 1);
      my $high = ($k & 1)  ?  Mmulint($low, $p)  :  $low;
      return map Mmulint($high, $_), 0 .. $low - 1;
    }
    # p divides a, p^2 does not
    my $a2 = Mdivint($a,$p);
    return () if $a2 % $p;
    my $pj = Mdivint($pk, $p);
    return map {
      my $qp = Mmulint($_,$p);
      map Maddint($qp,Mmulint($_,$pj)), 0 .. $p - 1;
    } _allsqrtmodpk(Mdivint($a2,$p), $p, $k - 2);
  }
  my $q = _sqrtmod_prime_power($a,$p,$k);
  return () unless defined $q;
  return ($q, $pk - $q) if $p != 2;
  return ($q) if $k == 1;
  return ($q, $pk - $q) if $k == 2;
  my $pj = Mdivint($pk,$p);
  my $q2 = ($q * ($pj - 1)) % $pk;
  return ($q, $pk - $q, $q2, $pk - $q2);
}

# helper function for allsqrtmod() - return list of all square roots of
# a (mod p^k), assuming a integer, n positive integer > 1, f arrayref
# of [ p, k ] pairs representing factorization of n. Destroys f.
sub _allsqrtmodfact {
  my($a,$n,$f) = @_;
  my($p,$k) = @{ shift @$f };
  my @q = _allsqrtmodpk($a, $p, $k);
  return @q unless @$f;
  my $pk = Mpowint($p, $k);
  my $n2 = Mdivint($n, $pk);
  return map {
    my $q2 = $_;
    map Mchinese([ $q2, $n2 ], [ $_, $pk ]), @q;
  } _allsqrtmodfact($a, $n2, $f);
}

sub allsqrtmod {
  my($A,$n) = @_;
  _validate_integer($A);
  _validate_integer($n);
  $n = -$n if $n < 0;
  return $n ? (0) : () if $n <= 1;
  $A = Mmodint($A,$n);
  my @roots = sort { $a <=> $b }
              _allsqrtmodfact($A, $n, [ Mfactor_exp($n) ]);
  return @roots;
}


###############################################################################
#       Tonelli-Shanks kth roots
###############################################################################

# Algorithm 3.3, step 2 "Find generator"
sub _find_ts_generator {
  my ($a, $k, $p) = @_;
  # Assume:  k > 2,  1 < a < p,  p > 2,  k prime,  p prime

  my($e,$r) = (0, $p-1);
  while (!($r % $k)) {
    $e++;
    $r /= $k;
  }
  my $ke1 = Mpowint($k, $e-1);
  my($x,$m,$y) = (2,1);
  while ($m == 1) {
    $y = Mpowmod($x, $r, $p);
    $m = Mpowmod($y, $ke1, $p) if $y != 1;
    croak "bad T-S input" if $x >= $p;
    $x++;
  }
  ($y, $m);
}

sub _ts_rootmod {
  my($a, $k, $p, $y, $m) = @_;

  my($e,$r) = (0, $p-1);
  while (!($r % $k)) {
    $e++;
    $r /= $k;
  }
  # p-1 = r * k^e
  my $x = Mpowmod($a, Minvmod($k % $r, $r), $p);
  my $A = ($a == 0) ? 0 : Mmulmod(Mpowmod($x,$k,$p), Minvmod($a,$p), $p);

  ($y,$m) = _find_ts_generator($a,$k,$p) if $y == 0 && $A != 1;

  while ($A != 1) {
    my ($l,$T,$z) = (1,$A);
    while ($T != 1) {
      return 0 if $l >= $e;
      $z = $T;
      $T = Mpowmod($T, $k, $p);
      $l++;
    }
    # We want a znlog that takes gorder as well (k=znorder(m,p))
    my $kz = _negmod(znlog($z, $m, $p), $k);
    $m = Mpowmod($m, $kz, $p);
    $T = Mpowmod($y, Mmulint($kz,Mpowint($k,$e-$l)), $p);
    # In the loop we always end with l < e, so e always gets smaller
    $e = $l-1;
    $x = Mmulmod($x, $T, $p);
    $y = Mpowmod($T, $k, $p);
    return 0 if $y <= 1;  # In theory this will never be hit.
    $A = Mmulmod($A, $y, $p);
  }
  $x;
}

sub _compute_generator {
  my($l, $e, $r, $p) = @_;
  my($m, $lem1, $y) = (1, Mpowint($l, $e-1));
  for (my $x = 2; $m == 1; $x++) {
    $y = Mpowmod($x, $r, $p);
    next if $y == 1;
    $m = Mpowmod($y, $lem1, $p);
  }
  $y;
}

sub _rootmod_prime_splitk {
  my($a, $k, $p, $refzeta) = @_;

  $$refzeta = 1 if defined $refzeta;
  $a = Mmodint($a, $p) if $a >= $p;
  return $a if $a == 0 || ($a == 1 && !defined $refzeta);
  my $p1 = Msubint($p,1);

  if ($k == 2) {
    my $r = _sqrtmod_prime($a,$p);
    $$refzeta = (defined $r) ? $p1 : 0     if defined $refzeta;
    return $r;
  }

  # See Algorithm 2.1 of van de Woestijne (2006), or Lindhurst (1997).
  # The latter's proposition 7 generalizes to composite p.

  my $g = Mgcd($k, $p1);
  my $r = $a;

  if ($g != 1) {
    foreach my $fac (Mfactor_exp($g)) {
      my($F,$E) = @$fac;
      last if $r == 0;
      if (defined $refzeta) {
        my $V   = Mvaluation($p1, $F);
        my $REM = Mdivint($p1, Mpowint($F,$V));
        my $Y   = _compute_generator($F, $V, $REM, $p);
        $$refzeta = Mmulmod($$refzeta, Mpowmod($Y, Mpowint($F, $V-$E), $p), $p);
      }
      my ($y,$m) = _find_ts_generator($r, $F, $p);
      while ($E-- > 0) {
        $r = _ts_rootmod($r, $F, $p,  $y, $m);
      }
    }
  }
  if ($g != $k) {
    my($kg, $pg) = (Mdivint($k,$g), Mdivint($p1,$g));
    $r = Mpowmod($r, Minvmod($kg % $pg, $pg), $p);
  }
  return $r if Mpowmod($r, $k, $p) == $a;
  $$refzeta = 0 if defined $refzeta;
  undef;
}

sub _rootmod_composite1 {
  my($a,$k,$n) = @_;
  my $r;

  croak "_rootmod_composite1 bad parameters" if $a < 1 || $k < 2 || $n < 2;

  if (Math::Prime::Util::is_power($a, $k, \$r)) {
    return $r;
  }

  if (Mis_prime($n)) {
    return _rootmod_prime_splitk($a,$k,$n,undef);
  }

  # We should do this iteratively using cprod
  my @rootmap;
  foreach my $fac (Mfactor_exp($n)) {
    my($F,$E) = @$fac;
    my $FE = Mpowint($F,$E);
    my $A = $a % $FE;
    if ($E == 1) {
      $r = _rootmod_prime_splitk($A,$k,$F,undef)
    } else {
      # TODO: Fix this.  We should do this directly.
      $r = (allrootmod($A, $k, $FE))[0];
    }
    return undef unless defined $r && Mpowmod($r, $k, $FE) == $A;
    push @rootmap, [ $r, $FE ];
  }
  $r = Mchinese(@rootmap) if @rootmap > 1;

  #return (defined $r && Mpowmod($r, $k, $n) == ($a % $n))  ?  $r  :  undef;
  croak "Bad _rootmod_composite1 root $a,$k,$n" unless defined $r && Mpowmod($r,$k,$n) == ($a % $n);
  $r;
}

###############################################################################
#       Tonelli-Shanks kth roots  alternate version
###############################################################################

sub _ts_prime {
  my($a, $k, $p, $refzeta) = @_;

  my($e,$r) = (0, $p-1);
  while (!($r % $k)) {
    $e++;
    $r /= $k;
  }
  my $ke = Mdivint($p-1, $r);

  my $x = Mpowmod($a, Minvmod($k % $r, $r), $p);
  my $B = Mmulmod(Mpowmod($x, $k, $p), Minvmod($a, $p), $p);

  my($T,$y,$t,$A) = (2,1);
  while ($y == 1) {
    $t = Mpowmod($T, $r, $p);
    $y = Mpowmod($t, Mdivint($ke,$k), $p);
    $T++;
  }
  while ($ke != $k) {
    $ke = Mdivint($ke, $k);
    $T = $t;
    $t = Mpowmod($t, $k, $p);
    $A = Mpowmod($B, Mdivint($ke,$k), $p);
    while ($A != 1) {
      $x = Mmulmod($x, $T, $p);
      $B = Mmulmod($B, $t, $p);
      $A = Mmulmod($A, $y, $p);
    }
  }
  $$refzeta = $t if defined $refzeta;
  $x;
}

sub _rootmod_prime {
  my($a, $k, $p) = @_;

  # p must be a prime, k must be a prime.  Otherwise UNDEFINED.
  $a %= $p if $a >= $p;

  return $a if $p == 2 || $a == 0;
  return _sqrtmod_prime($a, $p) if $k == 2;

  # If co-prime, there is exactly one root.
  my $g = Mgcd($k, $p-1);
  return Mpowmod($a, Minvmod($k % ($p-1), $p-1), $p)  if $g == 1;
  # Check generalized Euler's criterion
  return undef if Mpowmod($a, Mdivint($p-1, $g), $p) != 1;

  _ts_prime($a, $k, $p);
}

sub _rootmod_prime_power {
  my($a,$k,$p,$e) = @_;        # prime k, prime p

  return _sqrtmod_prime_power($a, $p, $e) if $k == 2;
  return _rootmod_prime($a, $k, $p)       if $e == 1;

  my $n = Mpowint($p,$e);
  my $pk = Mpowint($p,$k);

  return 0 if ($a % $n) == 0;

  if (($a % $pk) == 0) {
    my $apk = Mdivint($a, $pk);
    my $s = _rootmod_prime_power($apk, $k, $p, $e-$k);
    return (defined $s)  ?  Mmulint($s,$p)  :  undef;
  }

  return undef if ($a % $p) == 0;

  my $ered = ($p > 2 || $e < 5)  ?  ($e+1) >> 1  :  ($e+3) >> 1;
  my $s = _rootmod_prime_power($a, $k, $p, $ered);
  return undef if !defined $s;

  my $np  = ($p == $k)  ?  Mmulint($n,$p)  :  $n;
  my $t = Mpowmod($s, $k-1, $np);
  my $t1  = Msubmod($a, Mmulmod($t,$s,$np), $np);
  my $t2  = Mmulmod($k, $t, $np);
  my $gcd = Mgcd($t1, $t2);
  my $r   = Maddmod($s,Mdivmod(Mdivint($t1,$gcd),Mdivint($t2,$gcd),$n),$n);
  return ((Mpowmod($r,$k,$n) == ($a % $n)) ? $r : undef);
}

sub _rootmod_kprime {
  my($a,$k,$n,@nf) = @_;       # k prime, n factored into f^e,f^e,...

  my($N,$r) = (1,0);
  foreach my $F (@nf) {
    my($f,$e) = @$F;
    my $fe = Mpowint($f, $e);
    my $s = _rootmod_prime_power($a, $k, $f, $e);
    return undef unless defined $s;
    my $inv = Minvmod($N, $fe);
    my $t = Mmulmod($inv, Msubmod($s % $fe, $r % $fe, $fe), $fe);
    $r = Maddmod($r, Mmulmod($N,$t,$n), $n);
    $N = Mmulint($N, $fe);
  }
  $r;
}

sub _rootmod_composite2 {
  my($a,$k,$n) = @_;

  croak "_rootmod_composite2 bad parameters" if $a < 1 || $k < 2 || $n < 2;

  my @nf = Mfactor_exp($n);

  return _rootmod_kprime($a, $k, $n, @nf) if Mis_prime($k);

  my $r = $a;
  foreach my $kf (Mfactor($k)) {
    $r = _rootmod_kprime($r, $kf, $n, @nf);
    if (!defined $r) {
      # Choose one.  The former is faster but makes more intertwined code.
      return _rootmod_composite1($a,$k,$n);
      #return (allrootmod($a,$k,$n))[0];
    }
  }
  croak "Bad _rootmod_composite2 root $a,$k,$n" unless defined $r && Mpowmod($r,$k,$n) == ($a % $n);
  $r;
}


###############################################################################
#       Modular k-th root
###############################################################################

sub rootmod {
  my($a,$k,$n) = @_;
  _validate_integer($a);
  _validate_integer($k);
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  $a = Mmodint($a,$n);

  # Be careful with zeros, as we can't divide or invert them.
  if ($a == 0) {
    return ($k <= 0) ? undef : 0;
  }
  if ($k < 0) {
    $a = Minvmod($a, $n);
    return undef unless defined $a && $a > 0;
    $k = -$k;
  }
  return undef if $k == 0 && $a != 1;
  return 1 if $k == 0 || $a == 1;
  return $a if $k == 1;

  # Choose either one based on performance.
  my $r = _rootmod_composite1($a, $k, $n);
  #my $r = _rootmod_composite2($a, $k, $n);
  $r = $n-$r if defined $r && $k == 2 && ($n-$r) < $r; # Select smallest root
  $r;
}

###############################################################################
#       All modular k-th roots
###############################################################################

sub _allrootmod_cprod {
  my($aroots1, $p1, $aroots2, $p2) = @_;
  my($t, $n, $inv);

  $n = mulint($p1, $p2);
  $inv = Minvmod($p1, $p2);
  croak("CRT has undefined inverse") unless defined $inv;

  my @roots;
  for my $q1 (@$aroots1) {
    for my $q2 (@$aroots2) {
      $t = Mmulmod($inv, Msubmod($q2, $q1, $p2), $p2);
      $t = Maddmod($q1, Mmulmod($p1,$t,$n), $n);
      push @roots, $t;
    }
  }
  return @roots;
}

sub _allrootmod_prime {
  my($a,$k,$p) = @_;        # prime k, prime p
  $a %= $p if $a >= $p;     #$a = Mmodint($a,$p) if $a >= $p;

  return ($a) if $p == 2 || $a == 0;

  # If co-prime, there is exactly one root.
  my $g = Mgcd($k, $p-1);
  if ($g == 1) {
    my $r = Mpowmod($a, Minvmod($k % ($p-1), $p-1), $p);
    return ($r);
  }

  # Check generalized Euler's criterion
  return () if Mpowmod($a, Mdivint($p-1, $g), $p) != 1;

  # Special case for p=3 for performance
  return (1,2) if $p == 3;

  # A trivial brute force search:
  # return grep { Mpowmod($_,$k,$p) == $a } 0 .. $p-1;

  # Call one of the general TS solvers that also allow us to get all the roots.
  my $z;
  #my $r = _rootmod_prime_splitk($a, $k, $p, \$z);
  my $r = _ts_prime($a, $k, $p, \$z);
  croak "allrootmod: failed to find root" if $z==0 || Mpowmod($r,$k,$p) != $a;
  my @roots = ($r);
  my $r2 = Mmulmod($r,$z,$p);
  while ($r2 != $r && @roots < $k) {
    push @roots, $r2;
    $r2 = Mmulmod($r2, $z, $p);
  }
  croak "allrootmod: excess roots found" if $r2 != $r;
  return @roots;
}

sub _allrootmod_prime_power {
  my($a,$k,$p,$e) = @_;        # prime k, prime p

  return _allrootmod_prime($a, $k, $p) if $e == 1;

  my $n = Mpowint($p,$e);
  my $pk = Mpowint($p,$k);
  my @roots;

  if (($a % $n) == 0) {
    my $t = Mdivint($e-1, $k) + 1;
    my $nt = Mpowint($p, $t);
    my $nr = Mpowint($p, $e-$t);
    @roots = map { Mmulmod($_, $nt, $n) } 0 .. $nr-1;
    return @roots;
  }

  if (($a % $pk) == 0) {
    my $apk = Mdivint($a, $pk);
    my $pe1 = Mpowint($p, $k-1);
    my $pek = Mpowint($p, $e-$k+1);
    my @roots2 = _allrootmod_prime_power($apk, $k, $p, $e-$k);
    for my $r (@roots2) {
      my $rp = Mmulmod($r, $p, $n);
      for my $j (0 .. $pe1-1) {
        push @roots, Maddmod( $rp, Mmulmod($j, $pek, $n), $n);
      }
    }
    return @roots;
  }

  return () if ($a % $p) == 0;

  my $np  = Mmulint($n,$p);
  my $ered = ($p > 2 || $e < 5)  ?  ($e+1) >> 1  :  ($e+3) >> 1;
  my @roots2 = _allrootmod_prime_power($a, $k, $p, $ered);

  if ($k != $p) {
    for my $s (@roots2) {
      my $t = Mpowmod($s, $k-1, $n);
      my $t1  = Msubmod($a, Mmulmod($t,$s,$n), $n);
      my $t2  = Mmulmod($k, $t, $n);
      my $gcd = Mgcd($t1, $t2);
      my $r   = Maddmod($s,Mdivmod(Mdivint($t1,$gcd),Mdivint($t2,$gcd),$n),$n);
      push @roots, $r;
    }
  } else {
    my @rootst;
    for my $s (@roots2) {
      my $t  = Mpowmod($s, $k-1, $np);
      my $t1  = Msubmod($a, Mmulmod($t,$s,$np), $np);
      my $t2  = Mmulmod($k, $t, $np);
      my $gcd = Mgcd($t1, $t2);
      my $r   = Maddmod($s,Mdivmod(Mdivint($t1,$gcd), Mdivint($t2,$gcd),$n),$n);
      push @rootst, $r if Mpowmod($r, $k, $n) == ($a % $n);
    }
    my $ndivp = Mdivint($n,$p);
    my %roots;  # We want to remove duplicates
    for my $r (@rootst) {
      for my $j (0 .. $k-1) {
        $roots{ Mmulmod($r, Maddmod(Mmulmod($j, $ndivp, $n), 1, $n), $n) } = undef;
      }
    }
    @roots = keys(%roots);
  }
  return @roots;
}

sub _allrootmod_kprime {
  my($a,$k,$n,@nf) = @_;       # k prime, n factored into f^e,f^e,...

  return _allsqrtmodfact($a, $n, \@nf) if $k == 2;

  my $N = 1;
  my @roots;
  foreach my $F (@nf) {
    my($f,$e) = @$F;
    my $fe = Mpowint($f, $e);
    my @roots2 = ($e==1) ? _allrootmod_prime($a, $k, $f)
                         : _allrootmod_prime_power($a, $k, $f, $e);
    return () unless @roots2;
    if (scalar(@roots) == 0) {
      @roots = @roots2;
    } else {
      @roots = _allrootmod_cprod(\@roots, $N, \@roots2, $fe);
    }
    $N = Mmulint($N, $fe);
  }

  return @roots;
}

sub allrootmod {
  my($A,$k,$n) = @_;
  _validate_integer($A);
  _validate_integer($k);
  _validate_integer($n);
  $n = -$n if $n < 0;

  return () if $n == 0;
  $A = Mmodint($A,$n);

  return () if $k <= 0 && $A == 0;

  if ($k < 0) {
    $A = invmod($A, $n);
    return () unless defined $A && $A > 0;
    $k = -$k;
  }

  # TODO: For testing
  #my @roots = sort { $a <=> $b }
  #            grep { Mpowmod($_,$k,$n) == $A } 0 .. $n-1;
  #return @roots;

  return ($A) if $n <= 2 || $k == 1;
  return ($A == 1) ? (0..$n-1) : ()  if $k == 0;

  my @roots;
  my @nf = Mfactor_exp($n);

  if (Mis_prime($k)) {
    @roots = _allrootmod_kprime($A, $k, $n, @nf);
  } else {
    @roots = ($A);
    for my $primek (Mfactor($k)) {
      my @rootsnew = ();
      for my $r (@roots) {
        push @rootsnew, _allrootmod_kprime($r, $primek, $n, @nf);
      }
      @roots = @rootsnew;
    }
  }

  @roots = sort { $a <=> $b } @roots;
  return @roots;
}

################################################################################
################################################################################

sub addmod {
  my($a, $b, $n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  if ($n < INTMAX && $a < INTMAX && $b < INTMAX && $a > INTMIN && $b > INTMIN) {
    $a = $n - ((-$a) % $n) if $a < 0;
    $b = $n - ((-$b) % $n) if $b < 0;
    #$a %= $n if $a >= $n;  $b %= $n if $b >= $n;
    return _addmod($a,$b,$n);
  }
  my $ret = Math::BigInt->new("$a")->badd("$b")->bmod("$n");
  $ret = _bigint_to_int($ret) if $ret->bacmp(BMAX) <= 0;
  $ret;
}
sub submod {
  my($a, $b, $n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  if ($n < INTMAX && $a < INTMAX && $b < INTMAX && $a > INTMIN && $b > INTMIN) {
    $a = $n - ((-$a) % $n) if $a < 0;
    $b = $n - ((-$b) % $n) if $b < 0;
    #$a %= $n if $a >= $n;
    $b %= $n if $b >= $n;
    return _addmod($a,$n-$b,$n);
  }
  my $ret = Math::BigInt->new("$a")->bsub("$b")->bmod("$n");
  $ret = _bigint_to_int($ret) if $ret->bacmp(BMAX) <= 0;
  $ret;
}

sub mulmod {
  my($a, $b, $n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  return _mulmod($a,$b,$n) if $n < INTMAX && $a>0 && $a<INTMAX && $b>0 && $b<INTMAX;
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::mulmod($a,$b,$n))
    if $Math::Prime::Util::_GMPfunc{"mulmod"};
  my $ret = Math::BigInt->new("$a")->bmod("$n")->bmul("$b")->bmod("$n");
  $ret = _bigint_to_int($ret) if $ret->bacmp(BMAX) <= 0;
  $ret;
}
sub divmod {
  my($a, $b, $n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  my $ret = Math::BigInt->new("$b")->bmodinv("$n")->bmul("$a")->bmod("$n");
  if ($ret->is_nan) {
    $ret = undef;
  } else {
    $ret = _bigint_to_int($ret) if $ret->bacmp(BMAX) <= 0;
  }
  $ret;
}
sub powmod {
  my($a, $b, $n) = @_;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  return ($b > 0) ? 0 : 1  if $a == 0;

  if ($Math::Prime::Util::_GMPfunc{"powmod"}) {
    my $r = Math::Prime::Util::GMP::powmod($a,$b,$n);
    return (defined $r) ? Math::Prime::Util::_reftyped($_[0], $r) : undef;
  }

  my $ret = Math::BigInt->new("$a")->bmod("$n")->bmodpow("$b","$n");
  if ($ret->is_nan) {
    $ret = undef;
  } else {
    $ret = _bigint_to_int($ret) if $ret->bacmp(BMAX) <= 0;
  }
  $ret;
}

sub _negmod {
  my($a,$n) = @_;
  $a = Mmodint($a,$n) if $a >= $n;
  return ($a) ? ($n-$a) : 0;
}

# no validation, x is allowed to be negative, y must be >= 0
sub _gcd_ui {
  my($x, $y) = @_;
  if ($y < $x) { ($x, $y) = ($y, $x); }
  elsif ($x < 0) { $x = -$x; }
  while ($y > 0) {
    ($x, $y) = ($y, $x % $y);
  }
  $x;
}

sub is_power {
  my ($n, $a, $refp) = @_;
  croak("is_power third argument not a scalar reference") if defined($refp) && !ref($refp);
  _validate_integer($n);
  return 0 if abs($n) <= 3 && !$a;

  if ($Math::Prime::Util::_GMPfunc{"is_power"} &&
      ($Math::Prime::Util::GMP::VERSION >= 0.42 ||
       ($Math::Prime::Util::GMP::VERSION >= 0.28 && $n > 0))) {
    $a = 0 unless defined $a;
    my $k = Math::Prime::Util::GMP::is_power($n,$a);
    return 0 unless $k > 0;
    if (defined $refp) {
      $a = $k unless $a;
      my $isneg = ($n < 0);
      $n =~ s/^-// if $isneg;
      $$refp = Mrootint($n, $a);
      $$refp = Math::Prime::Util::_reftyped($_[0], $$refp) if $$refp > INTMAX;
      $$refp = -$$refp if $isneg;
    }
    return $k;
  }

  if (defined $a && $a != 0) {
    return 1 if $a == 1;                  # Everything is a 1st power
    return 0 if $n < 0 && $a % 2 == 0;    # Negative n never an even power
    if ($a == 2) {
      if (_is_perfect_square($n)) {
        $$refp = int(sqrt($n)) if defined $refp;
        return 1;
      }
    } else {
      $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
      my $root = $n->copy->babs->broot($a)->bfloor;
      $root->bneg if $n->is_neg;
      if ($root->copy->bpow($a) == $n) {
        $$refp = $root if defined $refp;
        return 1;
      }
    }
  } else {
    $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
    if ($n < 0) {
      my $absn = $n->copy->babs;
      my $root = is_power($absn, 0, $refp);
      return 0 unless $root;
      if ($root % 2 == 0) {
        my $power = valuation($root, 2);
        $root >>= $power;
        return 0 if $root == 1;
        $power = BTWO->copy->bpow($power);
        $$refp = $$refp ** $power if defined $refp;
      }
      $$refp = -$$refp if defined $refp;
      return $root;
    }
    my $e = 2;
    while (1) {
      my $root = $n->copy()->broot($e)->bfloor;
      last if $root->is_one();
      if ($root->copy->bpow($e) == $n) {
        my $next = is_power($root, 0, $refp);
        $$refp = $root if !$next && defined $refp;
        $e *= $next if $next != 0;
        return $e;
      }
      $e = Mnext_prime($e);
    }
  }
  0;
}

sub is_square {
  my($n) = @_;
  return 0 if $n < 0;
  #is_power($n,2);
  _validate_integer($n);
  _is_perfect_square($n);
}

sub is_prime_power {
  my ($n, $refp) = @_;
  croak("is_prime_power second argument not a scalar reference") if defined($refp) && !ref($refp);
  return 0 if $n <= 1;

  if (Mis_prime($n)) { $$refp = $n if defined $refp; return 1; }
  my $r;
  my $k = Math::Prime::Util::is_power($n,0,\$r);
  if ($k) {
    $r = _bigint_to_int($r) if ref($r) && $r->bacmp(BMAX) <= 0;
    return 0 unless Mis_prime($r);
    $$refp = $r if defined $refp;
  }
  $k;
}

sub is_gaussian_prime {
  my($a,$b) = @_;
  _validate_integer($a);
  _validate_integer($b);
  $a = -$a if $a < 0;
  $b = -$b if $b < 0;
  return ((($b % 4) == 3) ? Mis_prime($b) : 0) if $a == 0;
  return ((($a % 4) == 3) ? Mis_prime($a) : 0) if $b == 0;
  Mis_prime( Maddint( Mmulint($a,$a), Mmulint($b,$b) ) );
}

sub is_polygonal {
  my ($n, $k, $refp) = @_;
  croak("is_polygonal third argument not a scalar reference") if defined($refp) && !ref($refp);
  croak("is_polygonal: k must be >= 3") if $k < 3;
  return 0 if $n < 0;
  if ($n <= 1) { $$refp = $n if defined $refp; return 1; }

  if ($Math::Prime::Util::_GMPfunc{"polygonal_nth"}) {
    my $nth = Math::Prime::Util::GMP::polygonal_nth($n, $k);
    return 0 unless $nth;
    $$refp = Math::Prime::Util::_reftyped($_[0], $nth) if defined $refp;
    return 1;
  }

  my($D,$R);
  if ($k == 4) {
    return 0 unless _is_perfect_square($n);
    $$refp = Msqrtint($n) if defined $refp;
    return 1;
  }
  if ($n <= MPU_HALFWORD && $k <= MPU_HALFWORD) {
    $D = ($k==3) ? 1+($n<<3) : (8*$k-16)*$n + ($k-4)*($k-4);
    return 0 unless _is_perfect_square($D);
    $D = $k-4 + Msqrtint($D);
    $R = 2*$k-4;
  } else {
    if ($k == 3) {
      $D = Maddint(1, Mmulint($n, 8));
    } else {
      $D = Maddint(Mmulint($n, Mmulint(8, $k) - 16), Mmulint($k-4,$k-4));
    }
    return 0 unless _is_perfect_square($D);
    $D = Maddint( Msqrtint($D), $k-4 );
    $R = Mmulint(2, $k) - 4;
  }
  return 0 if ($D % $R) != 0;
  $$refp = $D / $R if defined $refp;
  1;
}

sub is_sum_of_squares {
  my($n, $k) = @_;
  $n = -$n if $n < 0;
  $k = 2 unless defined $k;
  return ($n == 0) ? 1 : 0 if $k == 0;
  return 1 if $k > 3;
  return _is_perfect_square($n) if $k == 1;

  return 1 if $n < 3;

  if ($k == 3) {
    my $tz = Mvaluation($n,2);
    return ( (($tz & 1) == 1) || ((($n >> $tz) % 8) != 7) ) ? 1 : 0;
  }

  # k = 2
  while (($n % 2) == 0) { $n >>= 1; }
  return 0 if ($n % 4) == 3;

  foreach my $F (Mfactor_exp($n)) {
    my($f,$e) = @$F;
    return 0 if ($f % 4) == 3 && ($e & 1) == 1;
  }
  1;
}

sub valuation {
  my($n, $k) = @_;
  croak "valuation: k must be > 1" if $k <= 1;
  #Math::Prime::Util::_validate_num($n) || _validate_integer($n);
  #_validate_integer($n) unless defined $n && $n eq int($n);
  # OMG, doing the input validation is more than 2x the time of the function.
  _validate_integer($n);   # OMG this is slow
  _validate_num($k) || _validate_positive_integer($k);
  return if $k < 2;
  $n = -$n if $n < 0;
  return (undef,0)[$n] if $n <= 1;
  my $v = 0;
  if ($k == 2) { # Accelerate power of 2
    if (ref($n)) {
      $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
      my $s = substr($n->as_bin,2);
      return length($s) - rindex($s,'1') - 1;
    }
    return 0 if $n & 1;
    $n >>= 1;                # So -$n stays an integer
    return 1 + (32,0,1,26,2,23,27,0,3,16,24,30,28,11,0,13,4,7,17,0,25,22,31,15,29,10,12,6,0,21,14,9,5,20,8,19,18)[(-$n & $n) % 37];
  }
  while ( !($n % $k) ) {
    $n /= $k;
    $v++;
  }
  $v;
}

sub hammingweight {
  my $n = shift;
  return 0 + (Math::BigInt->new("$n")->as_bin() =~ tr/1//);
}

my @_digitmap = (0..9, 'a'..'z');
my %_mapdigit = map { $_digitmap[$_] => $_ } 0 .. $#_digitmap;
sub _splitdigits {
  my($n, $base, $len) = @_;    # n is num or bigint, base is in range
  _validate_num($n) || _validate_positive_integer($n);
  my @d;
  if ($base == 10) {
    @d = split(//,"$n");
  } elsif ($base == 2) {
    @d = split(//,substr(Math::BigInt->new("$n")->as_bin,2));
  } elsif ($base == 16) {
    @d = map { $_mapdigit{$_} } split(//,substr(Math::BigInt->new("$n")->as_hex,2));
  } else {
    # The validation turned n into a bigint if necessary
    while ($n >= 1) {
      my $rem = $n % $base;
      unshift @d, $rem;
      $n = ($n-$rem)/$base;    # Always an exact division
    }
  }
  if ($len >= 0 && $len != scalar(@d)) {
    while (@d < $len) { unshift @d, 0; }
    while (@d > $len) { shift @d; }
  }
  @d;
}

sub todigits {
  my($n,$base,$len) = @_;
  $base = 10 unless defined $base;
  $len = -1 unless defined $len;
  die "Invalid base: $base" if $base < 2;
  return if $n == 0;
  $n = -$n if $n < 0;
  _splitdigits($n, $base, $len);
}

sub todigitstring {
  my($n,$base,$len) = @_;
  $base = 10 unless defined $base;
  $len = -1 unless defined $len;
  $n =~ s/^-//;
  return substr(Math::BigInt->new("$n")->as_bin,2) if $base ==  2 && $len < 0;
  return substr(Math::BigInt->new("$n")->as_oct,1) if $base ==  8 && $len < 0;
  return substr(Math::BigInt->new("$n")->as_hex,2) if $base == 16 && $len < 0;
  my @d = ($n == 0) ? () : _splitdigits($n, $base, $len);
  return join("", @d) if $base <= 10;
  die "Invalid base for string: $base" if $base > 36;
  join("", map { $_digitmap[$_] } @d);
}

sub _FastIntegerInput {
  my($digits, $B) = @_;
  return 0 if scalar(@$digits) == 0;
  return $digits->[0] if scalar(@$digits) == 1;
  my $L = [reverse @$digits];
  my $k = scalar(@$L);
  while ($k > 1) {
    my @T;
    for my $i (1 .. $k>>1) {
      my $x = $L->[2*$i-2];
      my $y = $L->[2*$i-1];
      push(@T, Maddint($x, Mmulint($B, $y)));
    }
    push(@T, $L->[$k-1]) if ($k&1);
    $L = \@T;
    $B = Mmulint($B, $B);
    $k = ($k+1) >> 1;
  }
  $L->[0];
}

sub fromdigits {
  my($r, $base) = @_;
  $base = 10 unless defined $base;
  return $r if $base == 10 && ref($r) =~ /^Math::/;
  my $n;
  if (ref($r) && ref($r) !~ /^Math::/) {
    croak "fromdigits first argument must be a string or array reference"
      unless ref($r) eq 'ARRAY';
    $n = BZERO + _FastIntegerInput($r,$base);
  } elsif ($base == 2) {
    $n = Math::BigInt->from_bin("0b$r");
  } elsif ($base == 8) {
    $n = Math::BigInt->from_oct("0$r");
  } elsif ($base == 16) {
    $n = Math::BigInt->from_hex("0x$r");
  } else {
    $r =~ s/^0*//;
    ($n,$base) = (BZERO->copy, BZERO + $base);
    #for my $d (map { $_mapdigit{$_} } split(//,$r)) {
    #  croak "Invalid digit for base $base" unless defined $d && $d < $base;
    #  $n = $n * $base + $d;
    #}
    for my $c (split(//, lc($r))) {
      $n->bmul($base);
      if ($c ne '0') {
        my $d = index("0123456789abcdefghijklmnopqrstuvwxyz", $c);
        croak "Invalid digit for base $base" unless $d >= 0;
        $n->badd($d);
      }
    }
  }
  $n = _bigint_to_int($n) if $n->bacmp(BMAX) <= 0;
  $n;
}

sub _validate_zeckendorf {
  my $s = shift;
  if ($s ne '0') {
    croak "fromzeckendorf takes a binary string as input"
      unless $s =~ /^1[01]*$/;
    croak "fromzeckendorf binary input not in canonical Zeckendorf form"
      if $s =~ /11/;
  }
  1;
}

sub fromzeckendorf {
  my($s) = @_;
  _validate_zeckendorf($s);

  my($n, $fb, $fc) = (0, 1, 1);
  for my $c (split(//,reverse $s)) {
    $n = Maddint($n,$fc) if $c eq '1';
    ($fb, $fc) = ($fc, Maddint($fb,$fc));
  }
  $n;
}

sub tozeckendorf {
  my($n) = @_;
  _validate_positive_integer($n);
  return '0' if $n == 0;

  my($rn, $s, $fa, $fb, $fc) = ($n, '', 0, 1, 1);
  my($i, $k);
  for ($k = 2; $fc <= $rn; $k++) {
    ($fa, $fb, $fc) = ($fb, $fc, Maddint($fb,$fc));
  }
  for ($i = $k-1; $i >= 2; $i--) {
    ($fc, $fb, $fa) = ($fb, $fa, Msubint($fb,$fa));
    if ($fc <= $rn) {
      $rn = Msubint($rn, $fc);
      $s .= '1';
    } else {
      $s .= '0';
    }
  }
  # croak "wrong tozeckendorf $n" unless $n == fromzeckendorf($s);
  $s;
}


sub sqrtint {
  my($n) = @_;
  my $sqrt = Math::BigInt->new("$n")->bsqrt;
  return Math::Prime::Util::_reftyped($_[0], "$sqrt");
}

sub rootint {
  my ($n, $k, $refp) = @_;
  croak "rootint: k must be > 0" unless $k > 0;
  # Math::BigInt returns NaN for any root of a negative n.
  my $root = Math::BigInt->new("$n")->babs->broot("$k");
  if (defined $refp) {
    croak("logint third argument not a scalar reference") unless ref($refp);
    $$refp = $root->copy->bpow($k);
  }
  return Math::Prime::Util::_reftyped($_[0], "$root");
}

sub logint {
  my ($n, $b, $refp) = @_;
  croak("logint third argument not a scalar reference") if defined($refp) && !ref($refp);

  if ($Math::Prime::Util::_GMPfunc{"logint"}) {
    my $e = Math::Prime::Util::GMP::logint($n, $b);
    if (defined $refp) {
      my $r = Math::Prime::Util::GMP::powmod($b, $e, $n);
      $r = $n if $r == 0;
      $$refp = Math::Prime::Util::_reftyped($_[0], $r);
    }
    return Math::Prime::Util::_reftyped($_[0], $e);
  }

  croak "logint: n must be > 0" unless $n > 0;
  croak "logint: missing base" unless defined $b;
  if ($b == 10) {
    my $e = length($n)-1;
    $$refp = Math::BigInt->new("1" . "0"x$e) if defined $refp;
    return $e;
  }
  if ($b == 2) {
    my $e = length(Math::BigInt->new("$n")->as_bin)-2-1;
    $$refp = Math::BigInt->from_bin("1" . "0"x$e) if defined $refp;
    return $e;
  }
  croak "logint: base must be > 1" unless $b > 1;

  my $e = Math::BigInt->new("$n")->blog("$b");
  $$refp = Math::BigInt->new("$b")->bpow($e) if defined $refp;
  return Math::Prime::Util::_reftyped($_[0], "$e");
}

# Seidel (Luschny), core using Trizen's simplications from Math::BigNum.
# http://oeis.org/wiki/User:Peter_Luschny/ComputationAndAsymptoticsOfBernoulliNumbers#Bernoulli_numbers__after_Seidel
sub _bernoulli_seidel {
  my($n) = @_;
  return (1,1) if $n == 0;
  return (0,1) if $n > 1 && $n % 2;

  my $oacc = Math::BigInt->accuracy();  Math::BigInt->accuracy(undef);
  my @D = (BZERO->copy, BONE->copy, map { BZERO->copy } 1 .. ($n>>1)-1);
  my ($h, $w) = (1, 1);

  foreach my $i (0 .. $n-1) {
    if ($w ^= 1) {
      $D[$_]->badd($D[$_-1]) for 1 .. $h-1;
    } else {
      $w = $h++;
      $D[$w]->badd($D[$w+1]) while --$w;
    }
  }
  my $num = $D[$h-1];
  my $den = BONE->copy->blsft($n+1)->bsub(BTWO);
  my $gcd = Math::BigInt::bgcd($num, $den);
  $num /= $gcd;
  $den /= $gcd;
  $num->bneg() if ($n % 4) == 0;
  Math::BigInt->accuracy($oacc);
  ($num,$den);
}

sub bernfrac {
  my $n = shift;
  return (BONE,BONE) if $n == 0;
  return (BONE,BTWO) if $n == 1;    # We're choosing 1/2 instead of -1/2
  return (BZERO,BONE) if $n < 0 || $n & 1;

  # We should have used one of the GMP functions before coming here.

  _bernoulli_seidel($n);
}

sub stirling {
  my($n, $m, $type) = @_;
  return 1 if $m == $n;
  return 0 if $n == 0 || $m == 0 || $m > $n;
  $type = 1 unless defined $type;
  croak "stirling type must be 1, 2, or 3" unless $type == 1 || $type == 2 || $type == 3;
  if ($m == 1) {
    return 1 if $type == 2;
    return Mfactorial($n) if $type == 3;
    return Mfactorial($n-1) if $n & 1;
    return Mvecprod(-1, Mfactorial($n-1));
  }
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::stirling($n,$m,$type))
    if $Math::Prime::Util::_GMPfunc{"stirling"};
  # Go through vecsum with quoted negatives to make sure we don't overflow.
  my $s;
  if ($type == 3) {
    $s = Mvecprod( Mbinomial($n,$m), Mbinomial($n-1,$m-1), Mfactorial($n-$m) );
  } elsif ($type == 2) {
    my @terms;
    for my $j (1 .. $m) {
      my $t = Mmulint(
                Mpowint($j,$n),
                Mbinomial($m,$j)
              );
      $t = Mnegint($t) if ($m-$j) & 1;
      push @terms, $t;
    }
    $s = Mvecsum(@terms) / Mfactorial($m);
  } else {
    my @terms;
    for my $k (1 .. $n-$m) {
      my $t = Mvecprod(
        Mbinomial($k + $n - 1, $k + $n - $m),
        Mbinomial(2 * $n - $m, $n - $k - $m),
        Math::Prime::Util::stirling($k - $m + $n, $k, 2),
      );
      $t = Mnegint($t) if $k & 1;
      push @terms, $t;
    }
    $s = Mvecsum(@terms);
  }
  $s;
}

sub _harmonic_split { # From Fredrik Johansson
  my($a,$b) = @_;
  return (BONE, $a) if $b - $a == BONE;
  return ($a+$a+BONE, $a*$a+$a) if $b - $a == BTWO;   # Cut down recursion
  my $m = $a->copy->badd($b)->brsft(BONE);
  my ($p,$q) = _harmonic_split($a, $m);
  my ($r,$s) = _harmonic_split($m, $b);
  ($p*$s+$q*$r, $q*$s);
}

sub harmfrac {
  my($n) = @_;
  return (BZERO,BONE) if $n <= 0;
  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  my($p,$q) = _harmonic_split($n-$n+1, $n+1);
  my $gcd = Math::BigInt::bgcd($p,$q);
  ( scalar $p->bdiv($gcd), scalar $q->bdiv($gcd) );
}

sub harmreal {
  my($n, $precision) = @_;

  do { require Math::BigFloat; Math::BigFloat->import(); } unless defined $Math::BigFloat::VERSION;
  return Math::BigFloat->bzero if $n <= 0;

  # Use asymptotic formula for larger $n if possible.  Saves lots of time if
  # the default Calc backend is being used.
  {
    my $sprec = $precision;
    $sprec = Math::BigFloat->precision unless defined $sprec;
    $sprec = 40 unless defined $sprec;
    if ( ($sprec <= 23 && $n >    54) ||
         ($sprec <= 30 && $n >   348) ||
         ($sprec <= 40 && $n >  2002) ||
         ($sprec <= 50 && $n > 12644) ) {
      $n = Math::BigFloat->new($n, $sprec+5);
      my($n2, $one, $h) = ($n*$n, Math::BigFloat->bone, Math::BigFloat->bzero);
      my $nt = $n2;
      my $eps = Math::BigFloat->new(10)->bpow(-$sprec-4);
      foreach my $d (-12, 120, -252, 240, -132, 32760, -12, 8160, -14364, 6600, -276, 65520, -12) { # OEIS A006593
        my $term = $one/($d * $nt);
        last if $term->bacmp($eps) < 0;
        $h += $term;
        $nt *= $n2;
      }
      $h->badd(scalar $one->copy->bdiv(2*$n));
      $h->badd(_Euler($sprec));
      $h->badd($n->copy->blog);
      $h->round($sprec);
      return $h;
    }
  }

  my($num,$den) = Math::Prime::Util::harmfrac($n);
  # Note, with Calc backend this can be very, very slow
  scalar Math::BigFloat->new($num)->bdiv($den, $precision);
}

sub is_pseudoprime {
  my($n, @bases) = @_;
  return 0 if int($n) < 0;
  _validate_positive_integer($n);
  @bases = (2) if scalar(@bases) == 0;
  return 0+($n >= 2) if $n < 4;

  foreach my $base (@bases) {
    croak "Base $base is invalid" if $base < 2;
    $base = $base % $n if $base >= $n;
    if ($base > 1 && $base != $n-1) {
      my $x = (ref($n) eq 'Math::BigInt')
        ? $n->copy->bzero->badd($base)->bmodpow($n-1,$n)->is_one
        : _powmod($base, $n-1, $n);
      return 0 unless $x == 1;
    }
  }
  1;
}

sub is_euler_pseudoprime {
  my($n, @bases) = @_;
  return 0 if int($n) < 0;
  _validate_positive_integer($n);
  @bases = (2) if scalar(@bases) == 0;
  return 0+($n >= 2) if $n < 4;

  foreach my $base (@bases) {
    croak "Base $base is invalid" if $base < 2;
    $base = $base % $n if $base >= $n;
    if ($base > 1 && $base != $n-1) {
      my $j = kronecker($base, $n);
      return 0 if $j == 0;
      $j = ($j > 0) ? 1 : $n-1;
      my $x = (ref($n) eq 'Math::BigInt')
        ? $n->copy->bzero->badd($base)->bmodpow(($n-1)/2,$n)
        : _powmod($base, ($n-1)>>1, $n);
      return 0 unless $x == $j;
    }
  }
  1;
}

sub is_euler_plumb_pseudoprime {
  my($n) = @_;
  return 0 if int($n) < 0;
  _validate_positive_integer($n);
  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0;
  my $nmod8 = $n % 8;
  my $exp = 1 + ($nmod8 == 1);
  my $ap = Mpowmod(2, ($n-1) >> $exp, $n);
  if ($ap ==    1) { return ($nmod8 == 1 || $nmod8 == 7); }
  if ($ap == $n-1) { return ($nmod8 == 1 || $nmod8 == 3 || $nmod8 == 5); }
  0;
}

sub _miller_rabin_2 {
  my($n, $nm1, $s, $d) = @_;

  if ( ref($n) eq 'Math::BigInt' ) {

    if (!defined $nm1) {
      $nm1 = $n->copy->bdec();
      $s = 0;
      $d = $nm1->copy;
      do {
        $s++;
        $d->brsft(BONE);
      } while $d->is_even;
    }
    my $x = BTWO->copy->bmodpow($d,$n);
    return 1 if $x->is_one || $x->bcmp($nm1) == 0;
    foreach my $r (1 .. $s-1) {
      $x->bmul($x)->bmod($n);
      last if $x->is_one;
      return 1 if $x->bcmp($nm1) == 0;
    }

  } else {

    if (!defined $nm1) {
      $nm1 = $n-1;
      $s = 0;
      $d = $nm1;
      while ( ($d & 1) == 0 ) {
        $s++;
        $d >>= 1;
      }
    }

    if ($n < MPU_HALFWORD) {
      my $x = _native_powmod(2, $d, $n);
      return 1 if $x == 1 || $x == $nm1;
      foreach my $r (1 .. $s-1) {
        $x = ($x*$x) % $n;
        last if $x == 1;
        return 1 if $x == $n-1;
      }
    } else {
      my $x = _powmod(2, $d, $n);
      return 1 if $x == 1 || $x == $nm1;
      foreach my $r (1 .. $s-1) {
        $x = ($x < MPU_HALFWORD) ? ($x*$x) % $n : _mulmod($x, $x, $n);
        last if $x == 1;
        return 1 if $x == $n-1;
      }
    }
  }
  0;
}

sub is_strong_pseudoprime {
  my($n, @bases) = @_;
  return 0 if int($n) < 0;
  _validate_positive_integer($n);
  return _miller_rabin_2($n) if scalar(@bases) == 0;

  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0;

  if ($bases[0] == 2) {
    return 0 unless _miller_rabin_2($n);
    shift @bases;
    return 1 unless @bases;
  }

  my @newbases;
  for my $base (@bases) {
    croak "Base $base is invalid" if $base < 2;
    $base %= $n if $base >= $n;
    return 0 if $base == 0 || ($base == $n-1 && ($base % 2) == 1);
    push @newbases, $base;
  }
  @bases = @newbases;

  if ( ref($n) eq 'Math::BigInt' ) {

    my $nminus1 = $n->copy->bdec();
    my $s = 0;
    my $d = $nminus1->copy;
    do {  # n is > 3 and odd, so n-1 must be even
      $s++;
      $d->brsft(BONE);
    } while $d->is_even;
    # Different way of doing the above.  Fewer function calls, slower on ave.
    #my $dbin = $nminus1->as_bin;
    #my $last1 = rindex($dbin, '1');
    #my $s = length($dbin)-2-$last1+1;
    #my $d = $nminus1->copy->brsft($s);

    foreach my $ma (@bases) {
      my $x = $n->copy->bzero->badd($ma)->bmodpow($d,$n);
      next if $x->is_one || $x->bcmp($nminus1) == 0;
      foreach my $r (1 .. $s-1) {
        $x->bmul($x); $x->bmod($n);
        return 0 if $x->is_one;
        do { $ma = 0; last; } if $x->bcmp($nminus1) == 0;
      }
      return 0 if $ma != 0;
    }

  } else {

   my $s = 0;
   my $d = $n - 1;
   while ( ($d & 1) == 0 ) {
     $s++;
     $d >>= 1;
   }

   if ($n < MPU_HALFWORD) {
    foreach my $ma (@bases) {
      my $x = _native_powmod($ma, $d, $n);
      next if ($x == 1) || ($x == ($n-1));
      foreach my $r (1 .. $s-1) {
        $x = ($x*$x) % $n;
        return 0 if $x == 1;
        last if $x == $n-1;
      }
      return 0 if $x != $n-1;
    }
   } else {
    foreach my $ma (@bases) {
      my $x = _powmod($ma, $d, $n);
      next if ($x == 1) || ($x == ($n-1));

      foreach my $r (1 .. $s-1) {
        $x = ($x < MPU_HALFWORD) ? ($x*$x) % $n : _mulmod($x, $x, $n);
        return 0 if $x == 1;
        last if $x == $n-1;
      }
      return 0 if $x != $n-1;
    }
   }

  }
  1;
}


# Calculate Kronecker symbol (a|b).  Cohen Algorithm 1.4.10.
# Extension of the Jacobi symbol, itself an extension of the Legendre symbol.
sub kronecker {
  my($a, $b) = @_;
  return (abs($a) == 1) ? 1 : 0  if $b == 0;
  my $k = 1;
  if ($b % 2 == 0) {
    return 0 if $a % 2 == 0;
    my $v = 0;
    do { $v++; $b /= 2; } while $b % 2 == 0;
    $k = -$k if $v % 2 == 1 && ($a % 8 == 3 || $a % 8 == 5);
  }
  if ($b < 0) {
    $b = -$b;
    $k = -$k if $a < 0;
  }
  if ($a < 0) { $a = -$a; $k = -$k if $b % 4 == 3; }
  $b = _bigint_to_int($b) if ref($b) eq 'Math::BigInt' && $b <= BMAX;
  $a = _bigint_to_int($a) if ref($a) eq 'Math::BigInt' && $a <= BMAX;
  # Now:  b > 0, b odd, a >= 0
  while ($a != 0) {
    if ($a % 2 == 0) {
      my $v = 0;
      do { $v++; $a /= 2; } while $a % 2 == 0;
      $k = -$k if $v % 2 == 1 && ($b % 8 == 3 || $b % 8 == 5);
    }
    $k = -$k if $a % 4 == 3 && $b % 4 == 3;
    ($a, $b) = ($b % $a, $a);
    # If a,b are bigints and now small enough, finish as native.
    if (   ref($a) eq 'Math::BigInt' && $a <= BMAX
        && ref($b) eq 'Math::BigInt' && $b <= BMAX) {
      return $k * kronecker(_bigint_to_int($a),_bigint_to_int($b));
    }
  }
  return ($b == 1) ? $k : 0;
}

sub _binomialu {
  my($r, $n, $k) = (1, @_);
  return ($k == $n) ? 1 : 0 if $k >= $n;
  $k = $n - $k if $k > ($n >> 1);
  foreach my $d (1 .. $k) {
    if ($r >= int(INTMAX/$n)) {
      my($g, $nr, $dr);
      $g = _gcd_ui($n, $d);   $nr = int($n/$g);   $dr = int($d/$g);
      $g = _gcd_ui($r, $dr);  $r  = int($r/$g);   $dr = int($dr/$g);
      return 0 if $r >= int(INTMAX/$nr);
      $r *= $nr;
      $r = int($r/$dr);
    } else {
      $r *= $n;
      $r = int($r/$d);
    }
    $n--;
  }
  $r;
}

sub binomial {
  my($n, $k) = @_;

  # 1. Try GMP
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::binomial($n,$k))
    if $Math::Prime::Util::_GMPfunc{"binomial"};

  # 2. Exit early for known 0 cases, and adjust k to be positive.
  if ($n >= 0) {  return 0 if $k < 0 || $k > $n;  }
  else         {  return 0 if $k < 0 && $k > $n;  }
  $k = $n - $k if $k < 0;

  # 3. Try to do in integer Perl
  my $r;
  if ($n >= 0) {
    $r = _binomialu($n, $k);
    return $r  if $r > 0 && $r eq int($r);
  } else {
    $r = _binomialu(-$n+$k-1, $k);
    if ($r > 0 && $r eq int($r)) {
      return $r   if !($k & 1);
      return Mnegint($r);
    }
  }

  # 4. Overflow.  Solve using Math::BigInt
  return 1 if $k == 0;        # Work around bug in old
  return $n if $k == $n-1;    # Math::BigInt (fixed in 1.90)
  if ($n >= 0) {
    $r = Math::BigInt->new(''.$n)->bnok($k);
    $r = _bigint_to_int($r) if $r->bacmp(BMAX) <= 0;
  } else { # Math::BigInt is incorrect for negative n
    $r = Math::BigInt->new(''.(-$n+$k-1))->bnok($k);
    if ($k & 1) {
      $r->bneg;
      $r = _bigint_to_int($r) if $r->bacmp(''.(~0>>1)) <= 0;
    } else {
      $r = _bigint_to_int($r) if $r->bacmp(BMAX) <= 0;
    }
  }
  $r;
}

sub binomialmod {
  my($n,$k,$m) = @_;
  _validate_integer($n);
  _validate_integer($k);
  _validate_integer($m);
  $m = -$m if $m < 0;
  return (undef,0)[$m] if $m <= 1;

  return Math::Prime::Util::_reftyped($_[2], _gmpcall("binomialmod",$n,$k,$m))
    if $Math::Prime::Util::_GMPfunc{"binomialmod"};

  return 1 if $k == 0 || $k == $n;
  return 0 if $n >= 0 && ($k < 0 || $k > $n);
  return 0 if $n  < 0 && ($k < 0 && $k > $n);
  return 0+!(($n-$k) & $k) if $m == 2;

  # TODO: Lucas split, etc.
  # 1. factorexp
  # 2.   bin[i] = _binomial_lucas_mod_prime_power(n, k, $f, $e)
  # 2a.            _factorialmod_without_prime
  # 3.   chinese(bin, p^e)
  # we can just run the more general code path.

  # Give up.
  return Mmodint(Mbinomial($n,$k),$m);
}


sub _product {
  my($a, $b, $r) = @_;
  if ($b <= $a) {
    $r->[$a];
  } elsif ($b == $a+1) {
    $r->[$a] -> bmul( $r->[$b] );
  } elsif ($b == $a+2) {
    $r->[$a] -> bmul( $r->[$a+1] ) -> bmul( $r->[$a+2] );
  } else {
    my $c = $a + (($b-$a+1)>>1);
    _product($a, $c-1, $r);
    _product($c, $b, $r);
    $r->[$a] -> bmul( $r->[$c] );
  }
}

sub factorial {
  my($n) = @_;
  return (1,1,2,6,24,120,720,5040,40320,362880,3628800,39916800,479001600)[$n] if $n <= 12;
  return Math::GMP::bfac($n) if ref($n) eq 'Math::GMP';
  do { my $r = Math::GMPz->new(); Math::GMPz::Rmpz_fac_ui($r,$n); return $r; }
    if ref($n) eq 'Math::GMPz';
  if (Math::BigInt->config()->{lib} !~ /GMP|Pari/) {
    # It's not a GMP or GMPz object, and we have a slow bigint library.
    my $r;
    if (defined $Math::GMPz::VERSION) {
      $r = Math::GMPz->new(); Math::GMPz::Rmpz_fac_ui($r,$n);
    } elsif (defined $Math::GMP::VERSION) {
      $r = Math::GMP::bfac($n);
    } elsif (defined &Math::Prime::Util::GMP::factorial && Math::Prime::Util::prime_get_config()->{'gmp'}) {
      $r = Math::Prime::Util::GMP::factorial($n);
    }
    return Math::Prime::Util::_reftyped($_[0], $r)    if defined $r;
  }
  my $r = Math::BigInt->new($n)->bfac();
  $r = _bigint_to_int($r) if $r->bacmp(BMAX) <= 0;
  $r;
}

sub factorialmod {
  my($n,$m) = @_;
  _validate_integer($n);
  _validate_integer($m);
  $m = -$m if $m < 0;
  return (undef,0)[$m] if $m <= 1;

  return Math::Prime::Util::GMP::factorialmod($n,$m)
    if $Math::Prime::Util::_GMPfunc{"factorialmod"};

  return 0 if $n >= $m || $m == 1;

  return factorial($n) % $m if $n <= 10;

  my($F, $N, $m_prime) = (1, $n, Mis_prime($m));

  # Check for Wilson's theorem letting us go backwards
  $n = $m-$n-1 if $m_prime && $n > Mrshiftint($m);
  return ($n == 0) ? ($m-1) : 1  if $n < 2;

  if ($n > 100 && !$m_prime) {   # Check for a composite that leads to zero
    my $maxpk = 0;
    foreach my $f (Mfactor_exp($m)) {
      my $pk = Mmulint($f->[0],$f->[1]);
      $maxpk = $pk if $pk > $maxpk;
    }
    return 0 if $n >= $maxpk;
  }

  my($t,$e);
  Mforprimes( sub {
    ($t,$e) = ($n,0);
    while ($t > 0) {
      $t = int($t/$_);
      $e += $t;
    }
    $F = Mmulmod($F,Mpowmod($_,$e,$m),$m);
  }, 2, $n >> 1);
  Mforprimes( sub {
    $F = Mmulmod($F, $_, $m);
  }, ($n >> 1)+1, $n);

  # Adjust for Wilson's theorem if we used it
  if ($n != $N && $F != 0) {
    $F = Msubmod($m, $F, $m) if !($n & 1);
    $F = Minvmod($F, $m);
  }

  $F;
}

sub _is_perfect_square {
  my($n) = @_;
  return (1,1,0,0,1)[$n] if $n <= 4;

  if (ref($n) eq 'Math::BigInt') {
    my $mc = _bigint_to_int($n & 31);
    if ($mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25) {
      my $sq = $n->copy->bsqrt->bfloor;
      $sq->bmul($sq);
      return 1 if $sq == $n;
    }
  } else {
    my $mc = $n & 31;
    if ($mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25) {
      my $sq = int(sqrt($n));
      return 1 if ($sq*$sq) == $n;
    }
  }
  0;
}

sub is_primitive_root {
  my($a, $n) = @_;
  _validate_integer($a);
  _validate_integer($n);
  $n = -$n if $n < 0;  # Ignore sign of n
  return (undef,1)[$n] if $n <= 1;
  $a = Mmodint($a, $n)  if $a < 0 || $a >= $n;

  return Math::Prime::Util::GMP::is_primitive_root($a,$n)
    if $Math::Prime::Util::_GMPfunc{"is_primitive_root"};

  if ($Math::Prime::Util::_GMPfunc{"znorder"} && $Math::Prime::Util::_GMPfunc{"totient"}) {
    my $order = Math::Prime::Util::GMP::znorder($a,$n);
    return 0 unless defined $order;
    my $totient = Math::Prime::Util::GMP::totient($n);
    return ($order eq $totient) ? 1 : 0;
  }

  return 0 if Mgcd($a, $n) != 1;
  my $s = Math::Prime::Util::euler_phi($n);
  return 0 if ($s % 2) == 0 && Mpowmod($a,$s >> 1,$n) == 1;
  return 0 if ($s % 3) == 0 && Mpowmod($a,int($s/3),$n) == 1;
  return 0 if ($s % 5) == 0 && Mpowmod($a,int($s/5),$n) == 1;
  foreach my $f (Mfactor_exp($s)) {
    my $fp = $f->[0];
    return 0 if $fp > 5 && Mpowmod($a, int($s/$fp), $n) == 1;
  }
  1;
}

sub znorder {
  my($a, $n) = @_;
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,1)[$n] if $n <= 1;
  $a = Mmodint($a, $n);
  return if $a <= 0;
  return 1 if $a == 1;

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::znorder($a,$n))
    if $Math::Prime::Util::_GMPfunc{"znorder"};

  # Sadly, Calc/FastCalc are horrendously slow for this function.
  return if Mgcd($a, $n) > 1;

  # The answer is one of the divisors of phi(n) and lambda(n).
  my $lambda = Math::Prime::Util::carmichael_lambda($n);
  $a = Math::BigInt->new("$a") unless ref($a) eq 'Math::BigInt';

  # This is easy and usually fast, but can bog down with too many divisors.
  if ($lambda <= 2**64) {
    foreach my $k (Math::Prime::Util::divisors($lambda)) {
      return $k if Mpowmod($a,$k,$n) == 1;
    }
    return;
  }

  # Algorithm 1.7 from A. Das applied to Carmichael Lambda.
  $lambda = Math::BigInt->new("$lambda") unless ref($lambda) eq 'Math::BigInt';
  my $k = Math::BigInt->bone;
  foreach my $f (Mfactor_exp($lambda)) {
    my($pi, $ei, $enum) = (Math::BigInt->new("$f->[0]"), $f->[1], 0);
    my $phidiv = $lambda / ($pi**$ei);
    my $b = Mpowmod($a,$phidiv,$n);
    while ($b != 1) {
      return if $enum++ >= $ei;
      $b = Mpowmod($b,$pi,$n);
      $k *= $pi;
    }
  }
  $k = _bigint_to_int($k) if $k->bacmp(BMAX) <= 0;
  return $k;
}

sub _dlp_trial {
  my ($a,$g,$p,$limit) = @_;
  $limit = $p if !defined $limit || $limit > $p;

  if ($limit < 1_000_000_000) {
    my $t = $g;
    for my $k (1 .. $limit) {
      return $k if $t == $a;
      $t = Mmulmod($t, $g, $p);
    }
    return 0;
  }

  my $t = $g->copy;
  for (my $k = BONE->copy; $k < $limit; $k->binc) {
    if ($t == $a) {
      $k = _bigint_to_int($k) if $k->bacmp(BMAX) <= 0;
      return $k;
    }
    $t->bmul($g)->bmod($p);
  }
  0;
}
sub _dlp_bsgs {
  my ($a,$g,$p,$n,$_verbose) = @_;
  my $invg = invmod($g, $p);
  return unless defined $invg;
  my $maxm = Msqrtint($n)+1;
  my $b = ($p + $maxm - 1) / $maxm;
  # Limit for time and space.
  $b = ($b > 4_000_000) ? 4_000_000 : int("$b");
  $maxm = ($maxm > $b) ? $b : int("$maxm");

  my %hash;
  my $am = BONE->copy;
  my $gm = Mpowmod($invg, $maxm, $p);
  my $key = $a->copy;
  my $r;

  foreach my $m (0 .. $b) {
    # Baby Step
    if ($m <= $maxm) {
      $r = $hash{"$am"};
      if (defined $r) {
        print "  bsgs found in stage 1 after $m tries\n" if $_verbose;
        $r = Maddmod($m, Mmulmod($r,$maxm,$p), $p);
        return $r;
      }
      $hash{"$am"} = $m;
      $am = Mmulmod($am,$g,$p);
      if ($am == $a) {
        print "  bsgs found during bs\n" if $_verbose;
        return $m+1;
      }
    }

    # Giant Step
    $r = $hash{"$key"};
    if (defined $r) {
      print "  bsgs found in stage 2 after $m tries\n" if $_verbose;
      $r = Maddmod($r, Mmulmod($m,$maxm,$p), $p);
      return $r;
    }
    $hash{"$key"} = $m if $m <= $maxm;
    $key = Mmulmod($key,$gm,$p);
  }
  0;
}

sub znlog {
  my($a, $g, $n) = @_;
  _validate_integer($a);
  _validate_integer($g);
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,0,1)[$n] if $n <= 1;
  $a = Mmodint($a, $n);
  $g = Mmodint($g, $n);
  return 0 if $a == 1 || $g == 0 || $n < 2;

  my $_verbose = Math::Prime::Util::prime_get_config()->{'verbose'};

  # For large p, znorder can be very slow.  Do a small trial test first.
  my $x = _dlp_trial($a, $g, $n, 200);

  ($a,$g,$n) = map { ref($_) eq 'Math::BigInt' ? $_ : Math::BigInt->new("$_") } ($a,$g,$n);

  if ($x == 0) {
    my $ord = znorder($g, $n);
    if (defined $ord && $ord > 1000) {
      $ord = Math::BigInt->new("$ord") unless ref($ord) eq 'Math::BigInt';
      $x = _dlp_bsgs($a, $g, $n, $ord, $_verbose);
      $x = _bigint_to_int($x) if ref($x) && $x->bacmp(BMAX) <= 0;
      return $x if $x > 0 && $g->copy->bmodpow($x, $n) == $a;
      print "  BSGS giving up\n" if $x == 0 && $_verbose;
      print "  BSGS incorrect answer $x\n" if $x > 0 && $_verbose > 1;
    }
    $x = _dlp_trial($a,$g,$n);
  }
  $x = _bigint_to_int($x) if ref($x) && $x->bacmp(BMAX) <= 0;
  return ($x == 0) ? undef : $x;
}

sub znprimroot {
  my($n) = @_;
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,0,1,2,3)[$n] if $n <= 4;
  return if $n % 4 == 0;
  my $phi = $n-1;
  if (!is_prob_prime($n)) {
    $phi = euler_phi($n);
    # Check that a primitive root exists.
    return if $phi != Math::Prime::Util::carmichael_lambda($n);
  }
  my @exp = map { Mdivint($phi, $_->[0]) }
            Mfactor_exp($phi);
  #print "phi: $phi  factors: ", join(",",factor($phi)), "\n";
  #print "  exponents: ", join(",", @exp), "\n";
  my $a = 1;
  while (1) {
    my $fail = 0;
    do { $a++ } while Mkronecker($a,$n) == 0;
    return if $a >= $n;
    foreach my $f (@exp) {
      if (Mpowmod($a,$f,$n) == 1) {
        $fail = 1;
        last;
      }
    }
    return $a if !$fail;
  }
}

sub qnr {
  my($n) = @_;
  _validate_integer($n);
  $n = -$n if $n < 0;
  return (undef,1,2)[$n] if $n <= 2;

  return 2 if Mkronecker(2,$n) == -1;

  if (Mis_prime($n)) {
    for (my $a = 3; $a < $n; $a = Mnext_prime($a)) {
      return $a if Mkronecker($a,$n) == -1;
    }
  } else {
    if ($n % 2 == 0) {
      my $e = Mvaluation($n, 2);
      $n >>= $e;
      return 2 if $n == 1 || $e >= 2;
    }
    return 2 if !($n%3) || !($n%5) || !($n%11) || !($n%13) || !($n%19);
    my @F = Mfactor_exp($n);
    for (my $a = 2; $a < $n; $a = Mnext_prime($a)) {
      for my $pe (@F) {
        my $p = $pe->[0];
        return $a if $a < $p && Mkronecker($a,$p) == -1;
      }
    }
  }
  0;
}


# Find first D in sequence (5,-7,9,-11,13,-15,...) where (D|N) == -1
sub _lucas_selfridge_params {
  my($n) = @_;

  # D is typically quite small: 67 max for N < 10^19.  However, it is
  # theoretically possible D could grow unreasonably.  I'm giving up at 4000M.
  my $d = 5;
  my $sign = 1;
  while (1) {
    my $gcd = (ref($n) eq 'Math::BigInt') ? Math::BigInt::bgcd($d, $n)
                                          : _gcd_ui($d, $n);
    return (0,0,0) if $gcd > 1 && $gcd != $n;  # Found divisor $d
    my $j = Mkronecker($d * $sign, $n);
    last if $j == -1;
    $d += 2;
    croak "Could not find Jacobi sequence for $n" if $d > 4_000_000_000;
    $sign = -$sign;
  }
  my $D = $sign * $d;
  my $P = 1;
  my $Q = int( (1 - $D) / 4 );
  ($P, $Q, $D)
}

sub _lucas_extrastrong_params {
  my($n, $increment) = @_;
  $increment = 1 unless defined $increment;

  my ($P, $Q, $D) = (3, 1, 5);
  while (1) {
    my $gcd = (ref($n) eq 'Math::BigInt') ? Math::BigInt::bgcd($D, $n)
                                          : _gcd_ui($D, $n);
    return (0,0,0) if $gcd > 1 && $gcd != $n;  # Found divisor $d
    last if kronecker($D, $n) == -1;
    $P += $increment;
    croak "Could not find Jacobi sequence for $n" if $P > 65535;
    $D = $P*$P - 4;
  }
  ($P, $Q, $D);
}

# returns U_k, V_k, Q_k all mod n
sub lucas_sequence {
  my($n, $P, $Q, $k) = @_;

  croak "lucas_sequence: n must be > 0" if $n < 1;
  croak "lucas_sequence: k must be >= 0" if $k < 0;
  return (0,0,0) if $n == 1;
  $P = Mmodint($P,$n) if $P < 0 || $P >= $n;
  $Q = Mmodint($Q,$n) if $Q < 0 || $Q >= $n;

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  return (0, 2 % $n, 1) if $k == 0;

  my $D = Msubint(
            Mmulint($P,$P),
            Mmulint(4,$Q)
          );
  if ($D == 0) {
    my $S = $P >> 1;  # If D is zero, P must be even (P*P = 4Q)
    my $U = Mmulmod($k, Mpowmod($S, $k-1, $n), $n);
    #die "  U $U : $P $Q $k $n\n" unless $U == Mmodint(lucasu($P,$Q,$k),$n);
    my $V = Mmulmod(2, Mpowmod($S, $k, $n), $n);
    #die "  V $V : $P $Q $k $n\n" unless $V == Mmodint(lucasv($P,$Q,$k),$n);
    my $Qk = Mpowmod($Q, $k, $n);
    return ($U, $V, $Qk);
  }

  if ($Math::Prime::Util::_GMPfunc{"lucas_sequence"} && $Math::Prime::Util::GMP::VERSION >= 0.30) {
    return map { ($_ > ''.~0) ? Math::BigInt->new(''.$_) : $_ }
           Math::Prime::Util::GMP::lucas_sequence($n, $P, $Q, $k);
  }

  my $ZERO = $n->copy->bzero;
  $P = $ZERO+$P unless ref($P) eq 'Math::BigInt';
  $Q = $ZERO+$Q unless ref($Q) eq 'Math::BigInt';
  $D = $ZERO+$D unless ref($D) eq 'Math::BigInt';

  my $U = BONE->copy;
  my $V = $P->copy;
  my $Qk = $Q->copy->bmod($n);

  return (BZERO->copy, BTWO->copy, $Qk) if $k == 0;
  $k = Math::BigInt->new("$k") unless ref($k) eq 'Math::BigInt';
  my $kstr = substr($k->as_bin, 2);
  my $bpos = 0;

  if (($n % 2)==0) {
    $P->bmod($n);
    $Q->bmod($n);
    my($Uh,$Vl, $Vh, $Ql, $Qh) = (BONE->copy, BTWO->copy, $P->copy, BONE->copy, BONE->copy);
    my ($b,$s) = (length($kstr)-1, 0);
    if ($kstr =~ /(0+)$/) { $s = length($1); }
    for my $bpos (0 .. $b-$s-1) {
      $Ql->bmul($Qh)->bmod($n);
      if (substr($kstr,$bpos,1)) {
        $Qh = $Ql * $Q;
        $Uh->bmul($Vh)->bmod($n);
        $Vl->bmul($Vh)->bsub($P * $Ql)->bmod($n);
        $Vh->bmul($Vh)->bsub(BTWO * $Qh)->bmod($n);
      } else {
        $Qh = $Ql->copy;
        $Uh->bmul($Vl)->bsub($Ql)->bmod($n);
        $Vh->bmul($Vl)->bsub($P * $Ql)->bmod($n);
        $Vl->bmul($Vl)->bsub(BTWO * $Ql)->bmod($n);
      }
    }
    $Ql->bmul($Qh);
    $Qh = $Ql * $Q;
    $Uh->bmul($Vl)->bsub($Ql)->bmod($n);
    $Vl->bmul($Vh)->bsub($P * $Ql)->bmod($n);
    $Ql->bmul($Qh)->bmod($n);
    for (1 .. $s) {
      $Uh->bmul($Vl)->bmod($n);
      $Vl->bmul($Vl)->bsub(BTWO * $Ql)->bmod($n);
      $Ql->bmul($Ql)->bmod($n);
    }
    ($U, $V, $Qk) = ($Uh, $Vl, $Ql);
  } elsif ($Q->is_one) {
    my $Dinverse = $D->copy->bmodinv($n);
    if ($P > BTWO && !$Dinverse->is_nan) {
      # Calculate V_k with U=V_{k+1}
      $U = $P->copy->bmul($P)->bsub(BTWO)->bmod($n);
      while (++$bpos < length($kstr)) {
        if (substr($kstr,$bpos,1)) {
          $V->bmul($U)->bsub($P  )->bmod($n);
          $U->bmul($U)->bsub(BTWO)->bmod($n);
        } else {
          $U->bmul($V)->bsub($P  )->bmod($n);
          $V->bmul($V)->bsub(BTWO)->bmod($n);
        }
      }
      # Crandall and Pomerance eq 3.13: U_n = D^-1 (2V_{n+1} - PV_n)
      $U = $Dinverse * (BTWO*$U - $P*$V);
    } else {
      while (++$bpos < length($kstr)) {
        $U->bmul($V)->bmod($n);
        $V->bmul($V)->bsub(BTWO)->bmod($n);
        if (substr($kstr,$bpos,1)) {
          my $T1 = $U->copy->bmul($D);
          $U->bmul($P)->badd( $V);
          $U->badd($n) if $U->is_odd;
          $U->brsft(BONE);
          $V->bmul($P)->badd($T1);
          $V->badd($n) if $V->is_odd;
          $V->brsft(BONE);
        }
      }
    }
  } else {
    my $qsign = ($Q == -1) ? -1 : 0;
    while (++$bpos < length($kstr)) {
      $U->bmul($V)->bmod($n);
      if    ($qsign ==  1) { $V->bmul($V)->bsub(BTWO)->bmod($n); }
      elsif ($qsign == -1) { $V->bmul($V)->badd(BTWO)->bmod($n); }
      else { $V->bmul($V)->bsub($Qk->copy->blsft(BONE))->bmod($n); }
      if (substr($kstr,$bpos,1)) {
        my $T1 = $U->copy->bmul($D);
        $U->bmul($P)->badd( $V);
        $U->badd($n) if $U->is_odd;
        $U->brsft(BONE);

        $V->bmul($P)->badd($T1);
        $V->badd($n) if $V->is_odd;
        $V->brsft(BONE);

        if ($qsign != 0) { $qsign = -1; }
        else             { $Qk->bmul($Qk)->bmul($Q)->bmod($n); }
      } else {
        if ($qsign != 0) { $qsign = 1; }
        else             { $Qk->bmul($Qk)->bmod($n); }
      }
    }
    if    ($qsign ==  1) { $Qk->bneg; }
    elsif ($qsign == -1) { $Qk = $n->copy->bdec; }
    $Qk->bmod($n);
  }
  $U->bmod($n);
  $V->bmod($n);
  return ($U, $V, $Qk);
}

sub lucasuv {
  my($P, $Q, $k) = @_;

  croak "lucas_sequence: k must be >= 0" if $k < 0;
  return (0,2) if $k == 0;

  $P = Math::BigInt->new("$P") unless ref($P) eq 'Math::BigInt';
  $Q = Math::BigInt->new("$Q") unless ref($Q) eq 'Math::BigInt';

  # Simple way, very slow as k increases:
  #my($U0, $U1) = (BZERO->copy, BONE->copy);
  #my($V0, $V1) = (BTWO->copy, Math::BigInt->new("$P"));
  #for (2 .. $k) {
  #  ($U0,$U1) = ($U1, $P*$U1 - $Q*$U0);
  #  ($V0,$V1) = ($V1, $P*$V1 - $Q*$V0);
  #}
  #return ($U1, $V1);

  my($Uh,$Vl, $Vh, $Ql, $Qh) = (BONE->copy, BTWO->copy, $P->copy, BONE->copy, BONE->copy);
  $k = Math::BigInt->new("$k") unless ref($k) eq 'Math::BigInt';
  my $kstr = substr($k->as_bin, 2);
  my ($n,$s) = (length($kstr)-1, 0);
  if ($kstr =~ /(0+)$/) { $s = length($1); }

  if ($Q == -1) {
    # This could be simplified, and it's running 10x slower than it should.
    my ($ql,$qh) = (1,1);
    for my $bpos (0 .. $n-$s-1) {
      $ql *= $qh;
      if (substr($kstr,$bpos,1)) {
        $qh = -$ql;
        $Uh->bmul($Vh);
        if ($ql == 1) {
          $Vl->bmul($Vh)->bsub( $P );
          $Vh->bmul($Vh)->badd( BTWO );
        } else {
          $Vl->bmul($Vh)->badd( $P );
          $Vh->bmul($Vh)->bsub( BTWO );
        }
      } else {
        $qh = $ql;
        if ($ql == 1) {
          $Uh->bmul($Vl)->bdec;
          $Vh->bmul($Vl)->bsub($P);
          $Vl->bmul($Vl)->bsub(BTWO);
        } else {
          $Uh->bmul($Vl)->binc;
          $Vh->bmul($Vl)->badd($P);
          $Vl->bmul($Vl)->badd(BTWO);
        }
      }
    }
    $ql *= $qh;
    $qh = -$ql;
    if ($ql == 1) {
      $Uh->bmul($Vl)->bdec;
      $Vl->bmul($Vh)->bsub($P);
    } else {
      $Uh->bmul($Vl)->binc;
      $Vl->bmul($Vh)->badd($P);
    }
    $ql *= $qh;
    for (1 .. $s) {
      $Uh->bmul($Vl);
      if ($ql == 1) { $Vl->bmul($Vl)->bsub(BTWO); $ql *= $ql; }
      else          { $Vl->bmul($Vl)->badd(BTWO); $ql *= $ql; }
    }
    return map { ($_ > ''.~0) ? Math::BigInt->new(''.$_) : $_ } ($Uh, $Vl);
  }

  for my $bpos (0 .. $n-$s-1) {
    $Ql->bmul($Qh);
    if (substr($kstr,$bpos,1)) {
      $Qh = $Ql * $Q;
      #$Uh = $Uh * $Vh;
      #$Vl = $Vh * $Vl - $P * $Ql;
      #$Vh = $Vh * $Vh - BTWO * $Qh;
      $Uh->bmul($Vh);
      $Vl->bmul($Vh)->bsub($P * $Ql);
      $Vh->bmul($Vh)->bsub(BTWO * $Qh);
    } else {
      $Qh = $Ql->copy;
      #$Uh = $Uh * $Vl - $Ql;
      #$Vh = $Vh * $Vl - $P * $Ql;
      #$Vl = $Vl * $Vl - BTWO * $Ql;
      $Uh->bmul($Vl)->bsub($Ql);
      $Vh->bmul($Vl)->bsub($P * $Ql);
      $Vl->bmul($Vl)->bsub(BTWO * $Ql);
    }
  }
  $Ql->bmul($Qh);
  $Qh = $Ql * $Q;
  $Uh->bmul($Vl)->bsub($Ql);
  $Vl->bmul($Vh)->bsub($P * $Ql);
  $Ql->bmul($Qh);
  for (1 .. $s) {
    $Uh->bmul($Vl);
    $Vl->bmul($Vl)->bsub(BTWO * $Ql);
    $Ql->bmul($Ql);
  }
  return map { ($_ > ''.~0) ? Math::BigInt->new(''.$_) : $_ } ($Uh, $Vl);
}

sub lucasuvmod {
  my($P, $Q, $k, $n) = @_;
  _validate_integer($P);
  _validate_integer($Q);
  _validate_positive_integer($k);
  _validate_integer($n);
  $n = -$n if $n < 0;
  return if $n == 0;

  lucas_sequence($n, $P, $Q, $k);
}

sub lucasu { (lucasuv(@_))[0] }
sub lucasv { (lucasuv(@_))[1] }
sub lucasumod { (lucasuvmod(@_))[0] }
sub lucasvmod { (lucasuvmod(@_))[1] }

sub is_lucas_pseudoprime {
  my($n) = @_;

  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0 || _is_perfect_square($n);

  my ($P, $Q, $D) = _lucas_selfridge_params($n);
  return 0 if $D == 0;  # We found a divisor in the sequence
  die "Lucas parameter error: $D, $P, $Q\n" if ($D != $P*$P - 4*$Q);

  my($U, $V, $Qk) = lucas_sequence($n, $P, $Q, $n+1);
  return ($U == 0) ? 1 : 0;
}

sub is_strong_lucas_pseudoprime {
  my($n) = @_;

  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0 || _is_perfect_square($n);

  my ($P, $Q, $D) = _lucas_selfridge_params($n);
  return 0 if $D == 0;  # We found a divisor in the sequence
  die "Lucas parameter error: $D, $P, $Q\n" if ($D != $P*$P - 4*$Q);

  my $m = $n+1;
  my($s, $k) = (0, $m);
  while ( $k > 0 && !($k % 2) ) {
    $s++;
    $k >>= 1;
  }
  my($U, $V, $Qk) = lucas_sequence($n, $P, $Q, $k);

  return 1 if $U == 0;
  $V = Math::BigInt->new("$V") unless ref($V) eq 'Math::BigInt';
  $Qk = Math::BigInt->new("$Qk") unless ref($Qk) eq 'Math::BigInt';
  foreach my $r (0 .. $s-1) {
    return 1 if $V->is_zero;
    if ($r < ($s-1)) {
      $V->bmul($V)->bsub(BTWO*$Qk)->bmod($n);
      $Qk->bmul($Qk)->bmod($n);
    }
  }
  return 0;
}

sub is_extra_strong_lucas_pseudoprime {
  my($n) = @_;

  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0 || _is_perfect_square($n);

  my ($P, $Q, $D) = _lucas_extrastrong_params($n);
  return 0 if $D == 0;  # We found a divisor in the sequence
  die "Lucas parameter error: $D, $P, $Q\n" if ($D != $P*$P - 4*$Q);

  # We have to convert n to a bigint or Math::BigInt::GMP's stupid set_si bug
  # (RT 71548) will hit us and make the test $V == $n-2 always return false.
  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';

  my($s, $k) = (0, $n->copy->binc);
  while ($k->is_even && !$k->is_zero) {
    $s++;
    $k->brsft(BONE);
  }

  my($U, $V, $Qk) = lucas_sequence($n, $P, $Q, $k);

  $V = Math::BigInt->new("$V") unless ref($V) eq 'Math::BigInt';
  return 1 if $U == 0 && ($V == BTWO || $V == ($n - BTWO));
  foreach my $r (0 .. $s-2) {
    return 1 if $V->is_zero;
    $V->bmul($V)->bsub(BTWO)->bmod($n);
  }
  return 0;
}

sub is_almost_extra_strong_lucas_pseudoprime {
  my($n, $increment) = @_;
  $increment = 1 unless defined $increment;

  return 0+($n >= 2) if $n < 4;
  return 0 if ($n % 2) == 0 || _is_perfect_square($n);

  my ($P, $Q, $D) = _lucas_extrastrong_params($n, $increment);
  return 0 if $D == 0;  # We found a divisor in the sequence
  die "Lucas parameter error: $D, $P, $Q\n" if ($D != $P*$P - 4*$Q);

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';

  my $ZERO = $n->copy->bzero;
  my $TWO = $ZERO->copy->binc->binc;
  my $V = $ZERO + $P;           # V_{k}
  my $W = $ZERO + $P*$P-$TWO;   # V_{k+1}
  my $kstr = substr($n->copy->binc()->as_bin, 2);
  $kstr =~ s/(0*)$//;
  my $s = length($1);
  my $bpos = 0;
  while (++$bpos < length($kstr)) {
    if (substr($kstr,$bpos,1)) {
      $V->bmul($W)->bsub($P  )->bmod($n);
      $W->bmul($W)->bsub($TWO)->bmod($n);
    } else {
      $W->bmul($V)->bsub($P  )->bmod($n);
      $V->bmul($V)->bsub($TWO)->bmod($n);
    }
  }

  return 1 if $V == 2 || $V == ($n-$TWO);
  foreach my $r (0 .. $s-2) {
    return 1 if $V->is_zero;
    $V->bmul($V)->bsub($TWO)->bmod($n);
  }
  return 0;
}

sub is_frobenius_khashin_pseudoprime {
  my($n) = @_;
  return 0+($n >= 2) if $n < 4;
  return 0 unless $n % 2;
  return 0 if _is_perfect_square($n);

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';

  my($k,$c) = (2,1);
  if    ($n % 4 == 3) { $c = $n-1; }
  elsif ($n % 8 == 5) { $c = 2; }
  else {
    do {
      $c += 2;
      $k = kronecker($c, $n);
    } while $k == 1;
  }
  return 0 if $k == 0 || ($k == 2 && !($n % 3));;

  my $ea = ($k == 2) ? 2 : 1;
  my($ra,$rb,$a,$b,$d) = ($ea,1,$ea,1,$n-1);
  while (!$d->is_zero) {
    if ($d->is_odd()) {
      ($ra, $rb) = ( (($ra*$a)%$n + ((($rb*$b)%$n)*$c)%$n) % $n,
                     (($rb*$a)%$n + ($ra*$b)%$n) % $n );
    }
    $d >>= 1;
    if (!$d->is_zero) {
      ($a, $b) = ( (($a*$a)%$n + ((($b*$b)%$n)*$c)%$n) % $n,
                   (($b*$a)%$n + ($a*$b)%$n) % $n );
    }
  }
  return ($ra == $ea && $rb == $n-1) ? 1 : 0;
}

sub is_frobenius_underwood_pseudoprime {
  my($n) = @_;
  return 0+($n >= 2) if $n < 4;
  return 0 unless $n % 2;

  my($a, $temp1, $temp2);
  if ($n % 4 == 3) {
    $a = 0;
  } else {
    for ($a = 1; $a < 1000000; $a++) {
      next if $a==2 || $a==4 || $a==7 || $a==8 || $a==10 || $a==14 || $a==16 || $a==18;
      my $j = kronecker($a*$a - 4, $n);
      last if $j == -1;
      return 0 if $j == 0 || ($a == 20 && _is_perfect_square($n));
    }
  }
  $temp1 = Mgcd(($a+4)*(2*$a+5), $n);
  return 0 if $temp1 != 1 && $temp1 != $n;

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  my $ZERO = $n->copy->bzero;
  my $ONE = $ZERO->copy->binc;
  my $TWO = $ONE->copy->binc;
  my($s, $t) = ($ONE->copy, $TWO->copy);

  my $ap2 = $TWO + $a;
  my $np1string = substr( $n->copy->binc->as_bin, 2);
  my $np1len = length($np1string);

  foreach my $bit (1 .. $np1len-1) {
    $temp2 = $t+$t;
    $temp2 += ($s * $a)  if $a != 0;
    $temp1 = $temp2 * $s;
    $temp2 = $t - $s;
    $s += $t;
    $t = ($s * $temp2) % $n;
    $s = $temp1 % $n;
    if ( substr( $np1string, $bit, 1 ) ) {
      if ($a == 0)  { $temp1 = $s + $s; }
      else          { $temp1 = $s * $ap2; }
      $temp1 += $t;
      $t->badd($t)->bsub($s);   # $t = ($t+$t) - $s;
      $s = $temp1;
    }
  }
  $temp1 = (2*$a+5) % $n;
  return ($s == 0 && $t == $temp1) ? 1 : 0;
}

sub _perrin_signature {
  my($n) = @_;
  my @S = (1,$n-1,3, 3,0,2);
  return @S if $n <= 1;

  my @nbin = todigits($n,2);
  shift @nbin;

  while (@nbin) {
    my @T = map { Maddmod(Maddmod(Mmulmod($S[$_],$S[$_],$n), $n-$S[5-$_],$n), $n-$S[5-$_],$n); } 0..5;
    my $T01 = Maddmod($T[2], $n-$T[1], $n);
    my $T34 = Maddmod($T[5], $n-$T[4], $n);
    my $T45 = Maddmod($T34, $T[3], $n);
    if (shift @nbin) {
      @S = ($T[0], $T01, $T[1], $T[4], $T45, $T[5]);
    } else {
      @S = ($T01, $T[1], Maddmod($T01,$T[0],$n), $T34, $T[4], $T45);
    }
  }
  @S;
}

sub is_perrin_pseudoprime {
  my($n, $restrict) = @_;
  $restrict = 0 unless defined $restrict;
  return 0+($n >= 2) if $n < 4;
  return 0 if $restrict > 2 && ($n % 2) == 0;

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';

  my @S = _perrin_signature($n);
  return 0 unless $S[4] == 0;
  return 1 if $restrict == 0;
  return 0 unless $S[1] == $n-1;
  return 1 if $restrict == 1;
  my $j = Mkronecker(-23,$n);
  if ($j == -1) {
    my $B = $S[2];
    my $B2 = Mmulmod($B,$B,$n);
    my $A = Maddmod(Maddmod(1,Mmulmod(3,$B,$n),$n),$n-$B2,$n);
    my $C = Maddmod(Mmulmod(3,$B2,$n),$n-2,$n);
    return 1 if $S[0] == $A && $S[2] == $B && $S[3] == $B && $S[5] == $C && $B != 3 && Maddmod(Mmulmod($B2,$B,$n),$n-$B,$n) == 1;
  } else {
    return 0 if $j == 0 && $n != 23 && $restrict > 2;
    return 1 if $S[0] == 1 && $S[2] == 3 && $S[3] == 3 && $S[5] == 2;
    return 1 if $S[0] == 0 && $S[5] == $n-1 && $S[2] != $S[3] && Maddmod($S[2],$S[3],$n) == $n-3 && Mmulmod(Maddmod($S[2],$n-$S[3],$n),Maddmod($S[2],$n-$S[3],$n),$n) == $n-(23%$n);
  }
  0;
}

sub is_catalan_pseudoprime {
  my($n) = @_;
  return 0+($n >= 2) if $n < 4;
  my $m = ($n-1)>>1;
  return (binomial($m<<1,$m) % $n) == (($m&1) ? $n-1 : 1) ? 1 : 0;
}

sub is_frobenius_pseudoprime {
  my($n, $P, $Q) = @_;
  ($P,$Q) = (0,0) unless defined $P && defined $Q;
  return 0+($n >= 2) if $n < 4;

  $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  return 0 if $n->is_even;

  my($k, $Vcomp, $D, $Du) = (0, 4);
  if ($P == 0 && $Q == 0) {
    ($P,$Q) = (-1,2);
    while ($k != -1) {
      $P += 2;
      $P = 5 if $P == 3;  # Skip 3
      $D = $P*$P-4*$Q;
      $Du = ($D >= 0) ? $D : -$D;
      last if $P >= $n || $Du >= $n;   # TODO: remove?
      $k = Mkronecker($D, $n);
      return 0 if $k == 0;
      return 0 if $P == 10001 && _is_perfect_square($n);
    }
  } else {
    $D = $P*$P-4*$Q;
    $Du = ($D >= 0) ? $D : -$D;
    croak "Frobenius invalid P,Q: ($P,$Q)" if _is_perfect_square($Du);
  }
  return (Mis_prime($n) ? 1 : 0) if $n <= $Du || $n <= abs($Q) || $n <= abs($P);
  return 0 if Mgcd(abs($P*$Q*$D), $n) > 1;

  if ($k == 0) {
    $k = Mkronecker($D, $n);
    return 0 if $k == 0;
    my $Q2 = (2*abs($Q)) % $n;
    $Vcomp = ($k == 1) ? 2 : ($Q >= 0) ? $Q2 : $n-$Q2;
  }

  my($U, $V, $Qk) = lucas_sequence($n, $P, $Q, $n-$k);
  return 1 if $U == 0 && $V == $Vcomp;
  0;
}

# Since people have graciously donated millions of CPU years to doing these
# tests, it would be rude of us not to use the results.  This means we don't
# actually use the pretest and Lucas-Lehmer test coded below for any reasonable
# size number.
# See: http://www.mersenne.org/report_milestones/
my %_mersenne_primes;
undef @_mersenne_primes{2,3,5,7,13,17,19,31,61,89,107,127,521,607,1279,2203,2281,3217,4253,4423,9689,9941,11213,19937,21701,23209,44497,86243,110503,132049,216091,756839,859433,1257787,1398269,2976221,3021377,6972593,13466917,20996011,24036583,25964951,30402457,32582657,37156667,42643801,43112609,57885161,74207281};

sub is_mersenne_prime {
  my $p = shift;

  # Use the known Mersenne primes
  return 1 if exists $_mersenne_primes{$p};
  return 0 if $p < 34007399; # GIMPS has checked all below
  # Past this we do a generic Mersenne prime test

  return 1 if $p == 2;
  return 0 unless is_prob_prime($p);
  return 0 if $p > 3 && $p % 4 == 3 && $p < ((~0)>>1) && is_prob_prime($p*2+1);
  my $mp = BONE->copy->blsft($p)->bdec;

  # Definitely faster than using Math::BigInt that doesn't have GMP.
  return (0 == (Math::Prime::Util::GMP::lucas_sequence($mp, 4, 1, $mp+1))[0])
    if $Math::Prime::Util::_GMPfunc{"lucas_sequence"};

  my $V = Math::BigInt->new(4);
  for my $k (3 .. $p) {
    $V->bmul($V)->bsub(BTWO)->bmod($mp);
  }
  return $V->is_zero;
}


my $_poly_bignum;
sub _poly_new {
  my @poly = @_;
  push @poly, 0 unless scalar @poly;
  if ($_poly_bignum) {
    @poly = map { (ref $_ eq 'Math::BigInt')
                  ?  $_->copy
                  :  Math::BigInt->new("$_"); } @poly;
  }
  return \@poly;
}

#sub _poly_print {
#  my($poly) = @_;
#  carp "poly has null top degree" if $#$poly > 0 && !$poly->[-1];
#  foreach my $d (reverse 1 .. $#$poly) {
#    my $coef = $poly->[$d];
#    print "", ($coef != 1) ? $coef : "", ($d > 1) ? "x^$d" : "x", " + "
#      if $coef;
#  }
#  my $p0 = $poly->[0] || 0;
#  print "$p0\n";
#}

sub _poly_mod_mul {
  my($px, $py, $r, $n) = @_;

  my $px_degree = $#$px;
  my $py_degree = $#$py;
  my @res = map { $_poly_bignum ? Math::BigInt->bzero : 0 } 0 .. $r-1;

  # convolve(px, py) mod (X^r-1,n)
  my @indices_y = grep { $py->[$_] } (0 .. $py_degree);
  foreach my $ix (0 .. $px_degree) {
    my $px_at_ix = $px->[$ix];
    next unless $px_at_ix;
    if ($_poly_bignum) {
      foreach my $iy (@indices_y) {
        my $rindex = ($ix + $iy) % $r;  # reduce mod X^r-1
        $res[$rindex]->badd($px_at_ix->copy->bmul($py->[$iy]))->bmod($n);
      }
    } else {
      foreach my $iy (@indices_y) {
        my $rindex = ($ix + $iy) % $r;  # reduce mod X^r-1
        $res[$rindex] = ($res[$rindex] + $px_at_ix * $py->[$iy]) % $n;
      }
    }
  }
  # In case we had upper terms go to zero after modulo, reduce the degree.
  pop @res while !$res[-1];
  return \@res;
}

sub _poly_mod_pow {
  my($pn, $power, $r, $mod) = @_;
  my $res = _poly_new(1);
  my $p = $power;

  while ($p) {
    $res = _poly_mod_mul($res, $pn, $r, $mod) if ($p % 2) != 0;
    $p >>= 1;
    $pn  = _poly_mod_mul($pn,  $pn, $r, $mod) if $p;
  }
  return $res;
}

sub _test_anr {
  my($a, $n, $r) = @_;
  my $pp = _poly_mod_pow(_poly_new($a, 1), $n, $r, $n);
  my $nr = $n % $r;
  $pp->[$nr] = (($pp->[$nr] || 0) -  1) % $n;  # subtract X^(n%r)
  $pp->[  0] = (($pp->[  0] || 0) - $a) % $n;  # subtract a
  return 0 if scalar grep { $_ } @$pp;
  1;
}

sub is_aks_prime {
  my $n = shift;
  return 0 if $n < 2 || is_power($n);

  my($log2n, $limit);
  if ($n > 2**48) {
    do { require Math::BigFloat; Math::BigFloat->import(); }
      if !defined $Math::BigFloat::VERSION;
    # limit = floor( log2(n) * log2(n) ).  o_r(n) must be larger than this
    my $floatn = Math::BigFloat->new("$n");
    #my $sqrtn = _bigint_to_int($floatn->copy->bsqrt->bfloor);
    # The following line seems to trigger a memory leak in Math::BigFloat::blog
    # (the part where $MBI is copied to $int) if $n is a Math::BigInt::GMP.
    $log2n = $floatn->copy->blog(2);
    $limit = _bigint_to_int( ($log2n * $log2n)->bfloor );
  } else {
    $log2n = log($n)/log(2) + 0.0001;      # Error on large side.
    $limit = int( $log2n*$log2n + 0.0001 );
  }

  my $r = Mnext_prime($limit);
  foreach my $f (@{primes(0,$r-1)}) {
    return 1 if $f == $n;
    return 0 if !($n % $f);
  }

  while ($r < $n) {
    return 0 if !($n % $r);
    #return 1 if $r >= $sqrtn;
    last if znorder($n, $r) > $limit;  # Note the arguments!
    $r = Mnext_prime($r);
  }

  return 1 if $r >= $n;

  # Since r is a prime, phi(r) = r-1
  my $rlimit = (ref($log2n) eq 'Math::BigFloat')
             ? _bigint_to_int( Math::BigFloat->new("$r")->bdec()
                                           ->bsqrt->bmul($log2n)->bfloor)
             : int( (sqrt(($r-1)) * $log2n) + 0.001 );

  $_poly_bignum = 1;
  if ( $n < (MPU_HALFWORD-1) ) {
    $_poly_bignum = 0;
    #$n = _bigint_to_int($n) if ref($n) eq 'Math::BigInt';
  } else {
    $n = Math::BigInt->new("$n") unless ref($n) eq 'Math::BigInt';
  }

  my $_verbose = Math::Prime::Util::prime_get_config()->{'verbose'};
  print "# aks r = $r  s = $rlimit\n" if $_verbose;
  local $| = 1 if $_verbose > 1;
  for (my $a = 1; $a <= $rlimit; $a++) {
    return 0 unless _test_anr($a, $n, $r);
    print "." if $_verbose > 1;
  }
  print "\n" if $_verbose > 1;

  return 1;
}


sub _basic_factor {
  # MODIFIES INPUT SCALAR
  return ($_[0] == 1) ? () : ($_[0])   if $_[0] < 4;

  my @factors;
  if (ref($_[0]) ne 'Math::BigInt') {
    while ( !($_[0] % 2) ) { push @factors, 2;  $_[0] = int($_[0] / 2); }
    while ( !($_[0] % 3) ) { push @factors, 3;  $_[0] = int($_[0] / 3); }
    while ( !($_[0] % 5) ) { push @factors, 5;  $_[0] = int($_[0] / 5); }
  } else {
    # Without this, the bdivs will try to convert the results to BigFloat
    # and lose precision.
    $_[0]->upgrade(undef) if ref($_[0]) && $_[0]->upgrade();
    if (!Math::BigInt::bgcd($_[0], B_PRIM235)->is_one) {
      while ( $_[0]->is_even)   { push @factors, 2;  $_[0]->brsft(BONE); }
      foreach my $div (3, 5) {
        my ($q, $r) = $_[0]->copy->bdiv($div);
        while ($r->is_zero) {
          push @factors, $div;
          $_[0] = $q;
          ($q, $r) = $_[0]->copy->bdiv($div);
        }
      }
    }
    $_[0] = _bigint_to_int($_[0]) if $] >= 5.008 && $_[0] <= BMAX;
  }

  if ( ($_[0] > 1) && _is_prime7($_[0]) ) {
    push @factors, $_[0];
    $_[0] = 1;
  }
  @factors;
}

sub trial_factor {
  my($n, $limit) = @_;

  # Don't use _basic_factor here -- they want a trial forced.
  my @factors;
  if ($n < 4) {
    @factors = ($n == 1) ? () : ($n);
    return @factors;
  }

  my $start_idx = 1;
  # Expand small primes if it would help.
  push @_primes_small, @{primes($_primes_small[-1]+1, 100_003)}
    if $n > 400_000_000
    && $_primes_small[-1] < 99_000
    && (!defined $limit || $limit > $_primes_small[-1]);

  # Do initial bigint reduction.  Hopefully reducing it to native int.
  if (ref($n) eq 'Math::BigInt') {
    $n = $n->copy;  # Don't modify their original input!
    my $newlim = $n->copy->bsqrt;
    $limit = $newlim if !defined $limit || $limit > $newlim;
    while ($start_idx <= $#_primes_small) {
      my $f = $_primes_small[$start_idx++];
      last if $f > $limit;
      if ($n->copy->bmod($f)->is_zero) {
        do {
          push @factors, $f;
          $n->bdiv($f)->bfloor();
        } while $n->copy->bmod($f)->is_zero;
        last if $n < BMAX;
        my $newlim = $n->copy->bsqrt;
        $limit = $newlim if $limit > $newlim;
      }
    }
    return @factors if $n->is_one;
    $n = _bigint_to_int($n) if $n <= BMAX;
    return (@factors,$n) if $start_idx <= $#_primes_small && $_primes_small[$start_idx] > $limit;
  }

  {
    my $newlim = (ref($n) eq 'Math::BigInt') ? $n->copy->bsqrt : int(sqrt($n) + 0.001);
    $limit = $newlim if !defined $limit || $limit > $newlim;
  }

  if (ref($n) ne 'Math::BigInt') {
    for my $i ($start_idx .. $#_primes_small) {
      my $p = $_primes_small[$i];
      last if $p > $limit;
      if (($n % $p) == 0) {
        do { push @factors, $p;  $n = int($n/$p); } while ($n % $p) == 0;
        last if $n == 1;
        my $newlim = int( sqrt($n) + 0.001);
        $limit = $newlim if $newlim < $limit;
      }
    }
    if ($_primes_small[-1] < $limit) {
      my $inc = (($_primes_small[-1] % 6) == 1) ? 4 : 2;
      my $p = $_primes_small[-1] + $inc;
      while ($p <= $limit) {
        if (($n % $p) == 0) {
          do { push @factors, $p;  $n = int($n/$p); } while ($n % $p) == 0;
          last if $n == 1;
          my $newlim = int( sqrt($n) + 0.001);
          $limit = $newlim if $newlim < $limit;
        }
        $p += ($inc ^= 6);
      }
    }
  } else {   # n is a bigint.  Use mod-210 wheel trial division.
    # Generating a wheel mod $w starting at $s:
    # mpu 'my($s,$w,$t)=(11,2*3*5); say join ",",map { ($t,$s)=($_-$s,$_); $t; } grep { gcd($_,$w)==1 } $s+1..$s+$w;'
    # Should start at $_primes_small[$start_idx], do 11 + next multiple of 210.
    my @incs = map { Math::BigInt->new($_) } (2,4,2,4,6,2,6,4,2,4,6,6,2,6,4,2,6,4,6,8,4,2,4,2,4,8,6,4,6,2,4,6,2,6,6,4,2,4,6,2,6,4,2,4,2,10,2,10);
    my $f = 11; while ($f <= $_primes_small[$start_idx-1]-210) { $f += 210; }
    ($f, $limit) = map { Math::BigInt->new("$_") } ($f, $limit);
    SEARCH: while ($f <= $limit) {
      foreach my $finc (@incs) {
        if ($n->copy->bmod($f)->is_zero && $f->bacmp($limit) <= 0) {
          my $sf = ($f <= BMAX) ? _bigint_to_int($f) : $f->copy;
          do {
            push @factors, $sf;
            $n->bdiv($f)->bfloor();
          } while $n->copy->bmod($f)->is_zero;
          last SEARCH if $n->is_one;
          my $newlim = $n->copy->bsqrt;
          $limit = $newlim if $limit > $newlim;
        }
        $f->badd($finc);
      }
    }
  }
  push @factors, $n  if $n > 1;
  @factors;
}

my $_holf_r;
my @_fsublist = (
  [ "pbrent 32k", sub { pbrent_factor (shift,   32*1024, 1, 1) } ],
  [ "p-1 1M",     sub { pminus1_factor(shift, 1_000_000, undef, 1); } ],
  [ "ECM 1k",     sub { ecm_factor    (shift,     1_000,   5_000, 15) } ],
  [ "pbrent 512k",sub { pbrent_factor (shift,  512*1024, 7, 1) } ],
  [ "p-1 4M",     sub { pminus1_factor(shift, 4_000_000, undef, 1); } ],
  [ "ECM 10k",    sub { ecm_factor    (shift,    10_000,  50_000, 10) } ],
  [ "pbrent 512k",sub { pbrent_factor (shift,  512*1024, 11, 1) } ],
  [ "HOLF 256k",  sub { holf_factor   (shift, 256*1024, $_holf_r); $_holf_r += 256*1024; } ],
  [ "p-1 20M",    sub { pminus1_factor(shift,20_000_000); } ],
  [ "ECM 100k",   sub { ecm_factor    (shift,   100_000, 800_000, 10) } ],
  [ "HOLF 512k",  sub { holf_factor   (shift, 512*1024, $_holf_r); $_holf_r += 512*1024; } ],
  [ "pbrent 2M",  sub { pbrent_factor (shift, 2048*1024, 13, 1) } ],
  [ "HOLF 2M",    sub { holf_factor   (shift, 2048*1024, $_holf_r); $_holf_r += 2048*1024; } ],
  [ "ECM 1M",     sub { ecm_factor    (shift, 1_000_000, 1_000_000, 10) } ],
  [ "p-1 100M",   sub { pminus1_factor(shift, 100_000_000, 500_000_000); } ],
);

sub factor {
  my($n) = @_;
  _validate_positive_integer($n);
  my @factors;

  if ($n < 4) {
    @factors = ($n == 1) ? () : ($n);
    return @factors;
  }
  $n = $n->copy if ref($n) eq 'Math::BigInt';
  my $lim = 4999;  # How much trial factoring to do

  # For native integers, we could save a little time by doing hardcoded trials
  # by 2-29 here.  Skipping it.

  push @factors, trial_factor($n, $lim);
  return @factors if $factors[-1] < $lim*$lim;
  $n = pop(@factors);

  my @nstack = ($n);
  while (@nstack) {
    $n = pop @nstack;
    # Don't use bignum on $n if it has gotten small enough.
    $n = _bigint_to_int($n) if ref($n) eq 'Math::BigInt' && $n <= BMAX;
    #print "Looking at $n with stack ", join(",",@nstack), "\n";
    while ( ($n >= ($lim*$lim)) && !_is_prime7($n) ) {
      my @ftry;
      $_holf_r = 1;
      foreach my $sub (@_fsublist) {
        last if scalar @ftry >= 2;
        print "  starting $sub->[0]\n" if Math::Prime::Util::prime_get_config()->{'verbose'} > 1;
        @ftry = $sub->[1]->($n);
      }
      if (scalar @ftry > 1) {
        #print "  split into ", join(",",@ftry), "\n";
        $n = shift @ftry;
        $n = _bigint_to_int($n) if ref($n) eq 'Math::BigInt' && $n <= BMAX;
        push @nstack, @ftry;
      } else {
        #warn "trial factor $n\n";
        push @factors, trial_factor($n);
        #print "  trial into ", join(",",@factors), "\n";
        $n = 1;
        last;
      }
    }
    push @factors, $n  if $n != 1;
  }
  @factors = sort {$a<=>$b} @factors;
  return @factors;
}

sub _found_factor {
  my($f, $n, $what, @factors) = @_;
  if ($f == 1 || $f == $n) {
    push @factors, $n;
  } else {
    # Perl 5.6.2 needs things spelled out for it.
    my $f2 = (ref($n) eq 'Math::BigInt') ? $n->copy->bdiv($f)->as_int
                                         : int($n/$f);
    push @factors, $f;
    push @factors, $f2;
    croak "internal error in $what" unless $f * $f2 == $n;
    # MPU::GMP prints this type of message if verbose, so do the same.
    print "$what found factor $f\n" if Math::Prime::Util::prime_get_config()->{'verbose'} > 0;
  }
  @factors;
}

# TODO:
sub squfof_factor { trial_factor(@_) }

sub prho_factor {
  my($n, $rounds, $pa, $skipbasic) = @_;
  $rounds = 4*1024*1024 unless defined $rounds;
  $pa = 3 unless defined $pa;

  my @factors;
  if (!$skipbasic) {
    @factors = _basic_factor($n);
    return @factors if $n < 4;
  }

  my $inloop = 0;
  my $U = 7;
  my $V = 7;

  if ( ref($n) eq 'Math::BigInt' ) {

    my $zero = $n->copy->bzero;
    $pa = $zero->badd("$pa");
    $U = $zero->copy->badd($U);
    $V = $zero->copy->badd($V);
    for my $i (1 .. $rounds) {
      # Would use bmuladd here, but old Math::BigInt's barf with scalar $pa.
      $U->bmul($U)->badd($pa)->bmod($n);
      $V->bmul($V)->badd($pa);
      $V->bmul($V)->badd($pa)->bmod($n);
      my $f = Math::BigInt::bgcd($U-$V, $n);
      if ($f->bacmp($n) == 0) {
        last if $inloop++;  # We've been here before
      } elsif (!$f->is_one) {
        return _found_factor($f, $n, "prho", @factors);
      }
    }

  } elsif ($n < MPU_HALFWORD) {

    my $inner = 32;
    $rounds = int( ($rounds + $inner-1) / $inner );
    while ($rounds-- > 0) {
      my($m, $oldU, $oldV, $f) = (1, $U, $V);
      for my $i (1 .. $inner) {
        $U = ($U * $U + $pa) % $n;
        $V = ($V * $V + $pa) % $n;
        $V = ($V * $V + $pa) % $n;
        $f = ($U > $V) ? $U-$V : $V-$U;
        $m = ($m * $f) % $n;
      }
      $f = _gcd_ui( $m, $n );
      next if $f == 1;
      if ($f == $n) {
        ($U, $V) = ($oldU, $oldV);
        for my $i (1 .. $inner) {
          $U = ($U * $U + $pa) % $n;
          $V = ($V * $V + $pa) % $n;
          $V = ($V * $V + $pa) % $n;
          $f = ($U > $V) ? $U-$V : $V-$U;
          $f = _gcd_ui( $f, $n);
          last if $f != 1;
        }
        last if $f == 1 || $f == $n;
      }
      return _found_factor($f, $n, "prho", @factors);
    }

  } else {

    for my $i (1 .. $rounds) {
      if ($n <= (~0 >> 1)) {
       $U = _mulmod($U, $U, $n);  $U += $pa;  $U -= $n if $U >= $n;
       $V = _mulmod($V, $V, $n);  $V += $pa;  # Let the mulmod handle it
       $V = _mulmod($V, $V, $n);  $V += $pa;  $V -= $n if $V >= $n;
      } else {
       #$U = _mulmod($U, $U, $n); $U=$n-$U; $U = ($pa>=$U) ? $pa-$U : $n-$U+$pa;
       #$V = _mulmod($V, $V, $n); $V=$n-$V; $V = ($pa>=$V) ? $pa-$V : $n-$V+$pa;
       #$V = _mulmod($V, $V, $n); $V=$n-$V; $V = ($pa>=$V) ? $pa-$V : $n-$V+$pa;
       $U = _mulmod($U, $U, $n);  $U = _addmod($U, $pa, $n);
       $V = _mulmod($V, $V, $n);  $V = _addmod($V, $pa, $n);
       $V = _mulmod($V, $V, $n);  $V = _addmod($V, $pa, $n);
      }
      my $f = _gcd_ui( $U-$V,  $n );
      if ($f == $n) {
        last if $inloop++;  # We've been here before
      } elsif ($f != 1) {
        return _found_factor($f, $n, "prho", @factors);
      }
    }

  }
  push @factors, $n;
  @factors;
}

sub pbrent_factor {
  my($n, $rounds, $pa, $skipbasic) = @_;
  $rounds = 4*1024*1024 unless defined $rounds;
  $pa = 3 unless defined $pa;

  my @factors;
  if (!$skipbasic) {
    @factors = _basic_factor($n);
    return @factors if $n < 4;
  }

  my $Xi = 2;
  my $Xm = 2;

  if ( ref($n) eq 'Math::BigInt' ) {

    # Same code as the GMP version, but runs *much* slower.  Even with
    # Math::BigInt::GMP it's >200x slower.  With the default Calc backend
    # it's thousands of times slower.
    my $inner = 32;
    my $zero = $n->copy->bzero;
    my $saveXi;
    my $f;
    $Xi = $zero->copy->badd($Xi);
    $Xm = $zero->copy->badd($Xm);
    $pa = $zero->copy->badd($pa);
    my $r = 1;
    while ($rounds > 0) {
      my $rleft = ($r > $rounds) ? $rounds : $r;
      while ($rleft > 0) {
        my $dorounds = ($rleft > $inner) ? $inner : $rleft;
        my $m = $zero->copy->bone;
        $saveXi = $Xi->copy;
        foreach my $i (1 .. $dorounds) {
          $Xi->bmul($Xi)->badd($pa)->bmod($n);
          $m->bmul($Xi->copy->bsub($Xm));
        }
        $rleft -= $dorounds;
        $rounds -= $dorounds;
        $m->bmod($n);
        $f = Math::BigInt::bgcd($m,  $n);
        last unless $f->is_one;
      }
      if ($f->is_one) {
        $r *= 2;
        $Xm = $Xi->copy;
        next;
      }
      if ($f == $n) {  # back up to determine the factor
        $Xi = $saveXi->copy;
        do {
          $Xi->bmul($Xi)->badd($pa)->bmod($n);
          $f = Math::BigInt::bgcd($Xm-$Xi, $n);
        } while ($f != 1 && $r-- != 0);
        last if $f == 1 || $f == $n;
      }
      return _found_factor($f, $n, "pbrent", @factors);
    }

  } elsif ($n < MPU_HALFWORD) {

    # Doing the gcd batching as above works pretty well here, but it's a lot
    # of code for not much gain for general users.
    for my $i (1 .. $rounds) {
      $Xi = ($Xi * $Xi + $pa) % $n;
      my $f = _gcd_ui( ($Xi>$Xm) ? $Xi-$Xm : $Xm-$Xi, $n);
      return _found_factor($f, $n, "pbrent", @factors) if $f != 1 && $f != $n;
      $Xm = $Xi if ($i & ($i-1)) == 0;  # i is a power of 2
    }

  } else {

    for my $i (1 .. $rounds) {
      $Xi = _addmod( _mulmod($Xi, $Xi, $n), $pa, $n);
      my $f = _gcd_ui( ($Xi>$Xm) ? $Xi-$Xm : $Xm-$Xi, $n);
      return _found_factor($f, $n, "pbrent", @factors) if $f != 1 && $f != $n;
      $Xm = $Xi if ($i & ($i-1)) == 0;  # i is a power of 2
    }

  }
  push @factors, $n;
  @factors;
}

sub pminus1_factor {
  my($n, $B1, $B2, $skipbasic) = @_;

  my @factors;
  if (!$skipbasic) {
    @factors = _basic_factor($n);
    return @factors if $n < 4;
  }

  if ( ref($n) ne 'Math::BigInt' ) {
    # Stage 1 only
    $B1 = 10_000_000 unless defined $B1;
    my $pa = 2;
    my $f = 1;
    my($pc_beg, $pc_end, @bprimes);
    $pc_beg = 2;
    $pc_end = $pc_beg + 100_000;
    my $sqrtb1 = int(sqrt($B1));
    while (1) {
      $pc_end = $B1 if $pc_end > $B1;
      @bprimes = @{ primes($pc_beg, $pc_end) };
      foreach my $q (@bprimes) {
        my $k = $q;
        if ($q <= $sqrtb1) {
          my $kmin = int($B1 / $q);
          while ($k <= $kmin) { $k *= $q; }
        }
        $pa = _powmod($pa, $k, $n);
        if ($pa == 0) { push @factors, $n; return @factors; }
        my $f = _gcd_ui( $pa-1, $n );
        return _found_factor($f, $n, "pminus1", @factors) if $f != 1;
      }
      last if $pc_end >= $B1;
      $pc_beg = $pc_end+1;
      $pc_end += 500_000;
    }
    push @factors, $n;
    return @factors;
  }

  # Stage 2 isn't really any faster than stage 1 for the examples I've tried.
  # Perl's overhead is greater than the savings of multiply vs. powmod

  if (!defined $B1) {
    for my $mul (1, 100, 1000, 10_000, 100_000, 1_000_000) {
      $B1 = 1000 * $mul;
      $B2 = 1*$B1;
      #warn "Trying p-1 with $B1 / $B2\n";
      my @nf = pminus1_factor($n, $B1, $B2);
      if (scalar @nf > 1) {
        push @factors, @nf;
        return @factors;
      }
    }
    push @factors, $n;
    return @factors;
  }
  $B2 = 1*$B1 unless defined $B2;

  my $one = $n->copy->bone;
  my ($j, $q, $saveq) = (32, 2, 2);
  my $t = $one->copy;
  my $pa = $one->copy->binc();
  my $savea = $pa->copy;
  my $f = $one->copy;
  my($pc_beg, $pc_end, @bprimes);

  $pc_beg = 2;
  $pc_end = $pc_beg + 100_000;
  while (1) {
    $pc_end = $B1 if $pc_end > $B1;
    @bprimes = @{ primes($pc_beg, $pc_end) };
    foreach my $q (@bprimes) {
      my($k, $kmin) = ($q, int($B1 / $q));
      while ($k <= $kmin) { $k *= $q; }
      $t *= $k;                         # accumulate powers for a
      if ( ($j++ % 64) == 0) {
        next if $pc_beg > 2 && ($j-1) % 256;
        $pa->bmodpow($t, $n);
        $t = $one->copy;
        if ($pa == 0) { push @factors, $n; return @factors; }
        $f = Math::BigInt::bgcd( $pa->copy->bdec, $n );
        last if $f == $n;
        return _found_factor($f, $n, "pminus1", @factors) unless $f->is_one;
        $saveq = $q;
        $savea = $pa->copy;
      }
    }
    $q = $bprimes[-1];
    last if !$f->is_one || $pc_end >= $B1;
    $pc_beg = $pc_end+1;
    $pc_end += 500_000;
  }
  undef @bprimes;
  $pa->bmodpow($t, $n);
  if ($pa == 0) { push @factors, $n; return @factors; }
  $f = Math::BigInt::bgcd( $pa-1, $n );
  if ($f == $n) {
    $q = $saveq;
    $pa = $savea->copy;
    while ($q <= $B1) {
      my ($k, $kmin) = ($q, int($B1 / $q));
      while ($k <= $kmin) { $k *= $q; }
      $pa->bmodpow($k, $n);
      my $f = Math::BigInt::bgcd( $pa-1, $n );
      if ($f == $n) { push @factors, $n; return @factors; }
      last if !$f->is_one;
      $q = Mnext_prime($q);
    }
  }
  # STAGE 2
  if ($f->is_one && $B2 > $B1) {
    my $bm = $pa->copy;
    my $b = $one->copy;
    my @precomp_bm;
    $precomp_bm[0] = ($bm * $bm) % $n;
    foreach my $j (1..19) {
      $precomp_bm[$j] = ($precomp_bm[$j-1] * $bm * $bm) % $n;
    }
    $pa->bmodpow($q, $n);
    my $j = 1;
    $pc_beg = $q+1;
    $pc_end = $pc_beg + 100_000;
    while (1) {
      $pc_end = $B2 if $pc_end > $B2;
      @bprimes = @{ primes($pc_beg, $pc_end) };
      foreach my $i (0 .. $#bprimes) {
        my $diff = $bprimes[$i] - $q;
        $q = $bprimes[$i];
        my $qdiff = ($diff >> 1) - 1;
        if (!defined $precomp_bm[$qdiff]) {
          $precomp_bm[$qdiff] = $bm->copy->bmodpow($diff, $n);
        }
        $pa->bmul($precomp_bm[$qdiff])->bmod($n);
        if ($pa == 0) { push @factors, $n; return @factors; }
        $b->bmul($pa-1);
        if (($j++ % 128) == 0) {
          $b->bmod($n);
          $f = Math::BigInt::bgcd( $b, $n );
          last if !$f->is_one;
        }
      }
      last if !$f->is_one || $pc_end >= $B2;
      $pc_beg = $pc_end+1;
      $pc_end += 500_000;
    }
    $f = Math::BigInt::bgcd( $b, $n );
  }
  return _found_factor($f, $n, "pminus1", @factors);
}

sub holf_factor {
  my($n, $rounds, $startrounds) = @_;
  $rounds = 64*1024*1024 unless defined $rounds;
  $startrounds = 1 unless defined $startrounds;
  $startrounds = 1 if $startrounds < 1;

  my @factors = _basic_factor($n);
  return @factors if $n < 4;

  if ( ref($n) eq 'Math::BigInt' ) {
    for my $i ($startrounds .. $rounds) {
      my $ni = $n->copy->bmul($i);
      my $s = $ni->copy->bsqrt->bfloor->as_int;
      if ($s * $s == $ni) {
        # s^2 = n*i, so m = s^2 mod n = 0.  Hence f = GCD(n, s) = GCD(n, n*i)
        my $f = Math::BigInt::bgcd($ni, $n);
        return _found_factor($f, $n, "HOLF", @factors);
      }
      $s->binc;
      my $m = ($s * $s) - $ni;
      # Check for perfect square
      my $mc = _bigint_to_int($m & 31);
      next unless $mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25;
      my $f = $m->copy->bsqrt->bfloor->as_int;
      next unless ($f*$f) == $m;
      $f = Math::BigInt::bgcd( ($s > $f) ? $s-$f : $f-$s,  $n);
      return _found_factor($f, $n, "HOLF ($i rounds)", @factors);
    }
  } else {
    for my $i ($startrounds .. $rounds) {
      my $s = int(sqrt($n * $i));
      $s++ if ($s * $s) != ($n * $i);
      my $m = ($s < MPU_HALFWORD) ? ($s*$s) % $n : _mulmod($s, $s, $n);
      # Check for perfect square
      my $mc = $m & 31;
      next unless $mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25;
      my $f = int(sqrt($m));
      next unless $f*$f == $m;
      $f = _gcd_ui($s - $f,  $n);
      return _found_factor($f, $n, "HOLF ($i rounds)", @factors);
    }
  }
  push @factors, $n;
  @factors;
}

sub fermat_factor {
  my($n, $rounds) = @_;
  $rounds = 64*1024*1024 unless defined $rounds;

  my @factors = _basic_factor($n);
  return @factors if $n < 4;

  if ( ref($n) eq 'Math::BigInt' ) {
    my $pa = $n->copy->bsqrt->bfloor->as_int;
    return _found_factor($pa, $n, "Fermat", @factors) if $pa*$pa == $n;
    $pa++;
    my $b2 = $pa*$pa - $n;
    my $lasta = $pa + $rounds;
    while ($pa <= $lasta) {
      my $mc = _bigint_to_int($b2 & 31);
      if ($mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25) {
        my $s = $b2->copy->bsqrt->bfloor->as_int;
        if ($s*$s == $b2) {
          my $i = $pa-($lasta-$rounds)+1;
          return _found_factor($pa - $s, $n, "Fermat ($i rounds)", @factors);
        }
      }
      $pa++;
      $b2 = $pa*$pa-$n;
    }
  } else {
    my $pa = int(sqrt($n));
    return _found_factor($pa, $n, "Fermat", @factors) if $pa*$pa == $n;
    $pa++;
    my $b2 = $pa*$pa - $n;
    my $lasta = $pa + $rounds;
    while ($pa <= $lasta) {
      my $mc = $b2 & 31;
      if ($mc==0||$mc==1||$mc==4||$mc==9||$mc==16||$mc==17||$mc==25) {
        my $s = int(sqrt($b2));
        if ($s*$s == $b2) {
          my $i = $pa-($lasta-$rounds)+1;
          return _found_factor($pa - $s, $n, "Fermat ($i rounds)", @factors);
        }
      }
      $pa++;
      $b2 = $pa*$pa-$n;
    }
  }
  push @factors, $n;
  @factors;
}


sub ecm_factor {
  my($n, $B1, $B2, $ncurves) = @_;
  _validate_positive_integer($n);

  my @factors = _basic_factor($n);
  return @factors if $n < 4;

  if ($Math::Prime::Util::_GMPfunc{"ecm_factor"}) {
    $B1 = 0 if !defined $B1;
    $ncurves = 0 if !defined $ncurves;
    my @ef = Math::Prime::Util::GMP::ecm_factor($n, $B1, $ncurves);
    if (@ef > 1) {
      my $ecmfac = Math::Prime::Util::_reftyped($n, $ef[-1]);
      return _found_factor($ecmfac, $n, "ECM (GMP) B1=$B1 curves $ncurves", @factors);
    }
    push @factors, $n;
    return @factors;
  }

  $ncurves = 10 unless defined $ncurves;

  if (!defined $B1) {
    for my $mul (1, 10, 100, 1000, 10_000, 100_000, 1_000_000) {
      $B1 = 100 * $mul;
      $B2 = 10*$B1;
      #warn "Trying ecm with $B1 / $B2\n";
      my @nf = ecm_factor($n, $B1, $B2, $ncurves);
      if (scalar @nf > 1) {
        push @factors, @nf;
        return @factors;
      }
    }
    push @factors, $n;
    return @factors;
  }

  $B2 = 10*$B1 unless defined $B2;
  my $sqrt_b1 = int(sqrt($B1)+1);

  # Affine code.  About 3x slower than the projective, and no stage 2.
  #
  #if (!defined $Math::Prime::Util::ECAffinePoint::VERSION) {
  #  eval { require Math::Prime::Util::ECAffinePoint; 1; }
  #  or do { croak "Cannot load Math::Prime::Util::ECAffinePoint"; };
  #}
  #my @bprimes = @{ primes(2, $B1) };
  #my $irandf = Math::Prime::Util::_get_rand_func();
  #foreach my $curve (1 .. $ncurves) {
  #  my $a = $irandf->($n-1);
  #  my $b = 1;
  #  my $ECP = Math::Prime::Util::ECAffinePoint->new($a, $b, $n, 0, 1);
  #  foreach my $q (@bprimes) {
  #    my $k = $q;
  #    if ($k < $sqrt_b1) {
  #      my $kmin = int($B1 / $q);
  #      while ($k <= $kmin) { $k *= $q; }
  #    }
  #    $ECP->mul($k);
  #    my $f = $ECP->f;
  #    if ($f != 1) {
  #      last if $f == $n;
  #      warn "ECM found factors with B1 = $B1 in curve $curve\n";
  #      return _found_factor($f, $n, "ECM B1=$B1 curve $curve", @factors);
  #    }
  #    last if $ECP->is_infinity;
  #  }
  #}

  require Math::Prime::Util::ECProjectivePoint;
  require Math::Prime::Util::RandomPrimes;

  # With multiple curves, it's better to get all the primes at once.
  # The downside is this can kill memory with a very large B1.
  my @bprimes = @{ primes(3, $B1) };
  foreach my $q (@bprimes) {
    last if $q > $sqrt_b1;
    my($k,$kmin) = ($q, int($B1/$q));
    while ($k <= $kmin) { $k *= $q; }
    $q = $k;
  }
  my @b2primes = ($B2 > $B1) ? @{primes($B1+1, $B2)} : ();

  foreach my $curve (1 .. $ncurves) {
    my $sigma = Murandomm($n-6) + 6;
    my ($u, $v) = ( ($sigma*$sigma - 5) % $n, (4 * $sigma) % $n );
    my ($x, $z) = ( ($u*$u*$u) % $n,  ($v*$v*$v) % $n );
    my $cb = (4 * $x * $v) % $n;
    my $ca = ( (($v-$u)**3) * (3*$u + $v) ) % $n;
    my $f = Math::BigInt::bgcd( $cb, $n );
    $f = Math::BigInt::bgcd( $z, $n ) if $f == 1;
    next if $f == $n;
    return _found_factor($f,$n, "ECM B1=$B1 curve $curve", @factors) if $f != 1;
    $cb = Math::BigInt->new("$cb") unless ref($cb) eq 'Math::BigInt';
    $u = $cb->copy->bmodinv($n);
    $ca = (($ca*$u) - 2) % $n;

    my $ECP = Math::Prime::Util::ECProjectivePoint->new($ca, $n, $x, $z);
    my $fm = $n-$n+1;
    my $i = 15;

    for (my $q = 2; $q < $B1; $q *= 2) { $ECP->double(); }
    foreach my $k (@bprimes) {
      $ECP->mul($k);
      $fm = ($fm * $ECP->x() ) % $n;
      if ($i++ % 32 == 0) {
        $f = Math::BigInt::bgcd($fm, $n);
        last if $f != 1;
      }
    }
    $f = Math::BigInt::bgcd($fm, $n);
    next if $f == $n;

    if ($f == 1 && $B2 > $B1) { # BEGIN STAGE 2
      my $D = int(sqrt($B2/2));  $D++ if $D % 2;
      my $one = $n - $n + 1;
      my $g = $one;

      my $S2P = $ECP->copy->normalize;
      $f = $S2P->f;
      if ($f != 1) {
        next if $f == $n;
        #warn "ECM S2 normalize f=$f\n" if $f != 1;
        return _found_factor($f, $n, "ECM S2 B1=$B1 curve $curve");
      }
      my $S2x = $S2P->x;
      my $S2d = $S2P->d;
      my @nqx = ($n-$n, $S2x);

      foreach my $i (2 .. 2*$D) {
        my($x2, $z2);
        if ($i % 2) {
          ($x2, $z2) = Math::Prime::Util::ECProjectivePoint::_addx($nqx[($i-1)/2], $nqx[($i+1)/2], $S2x, $n);
        } else {
          ($x2, $z2) = Math::Prime::Util::ECProjectivePoint::_double($nqx[$i/2], $one, $n, $S2d);
        }
        $nqx[$i] = $x2;
        #($f, $u, undef) = _extended_gcd($z2, $n);
        $f = Math::BigInt::bgcd( $z2, $n );
        last if $f != 1;
        $u = $z2->copy->bmodinv($n);
        $nqx[$i] = ($x2 * $u) % $n;
      }
      if ($f != 1) {
        next if $f == $n;
        #warn "ECM S2 1: B1 $B1 B2 $B2 curve $curve f=$f\n";
        return _found_factor($f, $n, "ECM S2 B1=$B1 curve $curve", @factors);
      }

      $x = $nqx[2*$D-1];
      my $m = 1;
      while ($m < ($B2+$D)) {
        if ($m != 1) {
          my $oldx = $S2x;
          my ($x1, $z1) = Math::Prime::Util::ECProjectivePoint::_addx($nqx[2*$D], $S2x, $x, $n);
          $f = Math::BigInt::bgcd( $z1, $n );
          last if $f != 1;
          $u = $z1->copy->bmodinv($n);
          $S2x = ($x1 * $u) % $n;
          $x = $oldx;
          last if $f != 1;
        }
        if ($m+$D > $B1) {
          my @p = grep { $_ >= $m-$D && $_ <= $m+$D } @b2primes;
          foreach my $i (@p) {
            last if $i >= $m;
            $g = ($g * ($S2x - $nqx[$m+$D-$i])) % $n;
          }
          foreach my $i (@p) {
            next unless $i > $m;
            next if $i > ($m+$m) || is_prime($m+$m-$i);
            $g = ($g * ($S2x - $nqx[$i-$m])) % $n;
          }
          $f = Math::BigInt::bgcd($g, $n);
          #warn "ECM S2 3: found $f in stage 2\n" if $f != 1;
          last if $f != 1;
        }
        $m += 2*$D;
      }
    } # END STAGE 2

    next if $f == $n;
    if ($f != 1) {
      #warn "ECM found factors with B1 = $B1 in curve $curve\n";
      return _found_factor($f, $n, "ECM B1=$B1 curve $curve", @factors);
    }
    # end of curve loop
  }
  push @factors, $n;
  @factors;
}

sub divisors {
  my($n) = @_;
  _validate_positive_integer($n);
  my(@factors, @d, @t);

  # In scalar context, returns sigma_0(n).  Very fast.
  return Math::Prime::Util::divisor_sum($n,0) unless wantarray;
  return ($n == 0) ? (0,1) : (1)  if $n <= 1;

  if ($Math::Prime::Util::_GMPfunc{"divisors"}) {
    # This trips an erroneous compile time error without the eval.
    eval "\@d = Math::Prime::Util::GMP::divisors(\"$n\"); ";  ## no critic qw(ProhibitStringyEval)
    @d = map { $_ <= ~0 ? $_ : ref($n)->new($_) } @d   if ref($n);
    return @d;
  }

  @factors = Mfactor($n);
  return (1,$n) if scalar @factors == 1;

  my $bigint = ref($n);
  @factors = map { $bigint->new("$_") } @factors  if $bigint;
  @d = $bigint ? ($bigint->new(1)) : (1);

  while (my $p = shift @factors) {
    my $e = 1;
    while (@factors && $p == $factors[0]) { $e++; shift(@factors); }
    push @d,  @t = map { $_ * $p } @d;               # multiply through once
    push @d,  @t = map { $_ * $p } @t   for 2 .. $e; # repeat
  }

  @d = map { $_ <= INTMAX ? _bigint_to_int($_) : $_ } @d   if $bigint;
  @d = sort { $a <=> $b } @d;
  @d;
}


sub chebyshev_theta {
  my($n,$low) = @_;
  $low = 2 unless defined $low;
  my($sum,$high) = (0.0, 0);
  while ($low <= $n) {
    $high = $low + 1e6;
    $high = $n if $high > $n;
    $sum += log($_) for @{primes($low,$high)};
    $low = $high+1;
  }
  $sum;
}

sub chebyshev_psi {
  my($n) = @_;
  return 0 if $n <= 1;
  my ($sum, $logn, $sqrtn) = (0.0, log($n), int(sqrt($n)));

  # Sum the log of prime powers first
  for my $p (@{primes($sqrtn)}) {
    my $logp = log($p);
    $sum += $logp * int($logn/$logp+1e-15);
  }
  # The rest all have exponent 1: add them in using the segmenting theta code
  $sum += chebyshev_theta($n, $sqrtn+1);

  $sum;
}

sub hclassno {
  my $n = shift;

  return -1 if $n == 0;
  return 0 if $n < 0 || ($n % 4) == 1 || ($n % 4) == 2;
  return 2 * (2,3,6,6,6,8,12,9,6,12,18,12,8,12,18,18,12,15,24,12,6,24,30,20,12,12,24,24,18,24)[($n>>1)-1] if $n <= 60;

  my ($h, $square, $b, $b2) = (0, 0, $n & 1, ($n+1) >> 2);

  if ($b == 0) {
    my $lim = int(sqrt($b2));
    if (_is_perfect_square($b2)) {
      $square = 1;
      $lim--;
    }
    #$h += scalar(grep { $_ <= $lim } divisors($b2));
    for my $i (1 .. $lim) { $h++ unless $b2 % $i; }
    ($b,$b2) = (2, ($n+4) >> 2);
  }
  while ($b2 * 3 < $n) {
    $h++ unless $b2 % $b;
    my $lim = int(sqrt($b2));
    if (_is_perfect_square($b2)) {
      $h++;
      $lim--;
    }
    #$h += 2 * scalar(grep { $_ > $b && $_ <= $lim } divisors($b2));
    for my $i ($b+1 .. $lim) { $h += 2 unless $b2 % $i; }
    $b += 2;
    $b2 = ($n+$b*$b) >> 2;
  }
  return (($b2*3 == $n) ? 2*(3*$h+1) : $square ? 3*(2*$h+1) : 6*$h) << 1;
}

# Sigma method for prime powers
sub _taup {
  my($p, $e, $n) = @_;
  my($bp) = Math::BigInt->new("".$p);
  if ($e == 1) {
    return (0,1,-24,252,-1472,4830,-6048,-16744,84480)[$p] if $p <= 8;
    my $ds5  = $bp->copy->bpow( 5)->binc();  # divisor_sum(p,5)
    my $ds11 = $bp->copy->bpow(11)->binc();  # divisor_sum(p,11)
    my $s    = Math::BigInt->new("".Mvecsum(map { Mvecprod(BTWO,Math::Prime::Util::divisor_sum($_,5), Math::Prime::Util::divisor_sum($p-$_,5)) } 1..($p-1)>>1));
    $n = ( 65*$ds11 + 691*$ds5 - (691*252)*$s ) / 756;
  } else {
    my $t = Math::BigInt->new(""._taup($p,1));
    $n = $t->copy->bpow($e);
    if ($e == 2) {
      $n -= $bp->copy->bpow(11);
    } elsif ($e == 3) {
      $n -= BTWO * $t * $bp->copy->bpow(11);
    } else {
      $n += Mvecsum( map { Mvecprod( ($_&1) ? - BONE : BONE,
                                     $bp->copy->bpow(11*$_),
                                     Mbinomial($e-$_, $e-2*$_),
                                     $t ** ($e-2*$_) ) } 1 .. ($e>>1) );
    }
  }
  $n = _bigint_to_int($n) if ref($n) && $n->bacmp(BMAX) <= 0;
  $n;
}

# Cohen's method using Hurwitz class numbers
# The two hclassno calls could be collapsed with some work
sub _tauprime {
  my $p = shift;
  return -24 if $p == 2;
  my $sum = Math::BigInt->new(0);
  if ($p < (MPU_32BIT ?  300  :  1600)) {
    my($p9,$pp7) = (9*$p, 7*$p*$p);
    for my $t (1 .. Msqrtint($p)) {
      my $t2 = $t * $t;
      my $v = $p - $t2;
      $sum += $t2**3 * (4*$t2*$t2 - $p9*$t2 + $pp7) * (Math::Prime::Util::hclassno(4*$v) + 2 * Math::Prime::Util::hclassno($v));
    }
    $p = Math::BigInt->new("$p");
  } else {
    $p = Math::BigInt->new("$p");
    my($p9,$pp7) = (9*$p, 7*$p*$p);
    for my $t (1 .. Msqrtint($p)) {
      my $t2 = Math::BigInt->new("$t") ** 2;
      my $v = $p - $t2;
      $sum += $t2**3 * (4*$t2*$t2 - $p9*$t2 + $pp7) * (Math::Prime::Util::hclassno(4*$v) + 2 * Math::Prime::Util::hclassno($v));
    }
  }
  28*$p**6 - 28*$p**5 - 90*$p**4 - 35*$p**3 - 1 - 32 * ($sum/3);
}

# Recursive method for handling prime powers
sub _taupower {
  my($p, $e) = @_;
  return 1 if $e <= 0;
  return _tauprime($p) if $e == 1;
  $p = Math::BigInt->new("$p");
  my($tp, $p11) = ( _tauprime($p), $p**11 );
  return $tp ** 2 - $p11 if $e == 2;
  return $tp ** 3 - 2 * $tp * $p11 if $e == 3;
  return $tp ** 4 - 3 * $tp**2 * $p11 + $p11**2 if $e == 4;
  # Recurse -3
  ($tp**3 - 2*$tp*$p11) * _taupower($p,$e-3) + ($p11*$p11 - $tp*$tp*$p11) * _taupower($p,$e-4);
}

sub ramanujan_tau {
  my $n = shift;
  return 0 if $n <= 0;

  # Use GMP if we have no XS or if size is small
  if ($n < 100000 || !Math::Prime::Util::prime_get_config()->{'xs'}) {
    if ($Math::Prime::Util::_GMPfunc{"ramanujan_tau"}) {
      return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::ramanujan_tau($n));
    }
  }

  # _taup is faster for small numbers, but gets very slow.  It's not a huge
  # deal, and the GMP code will probably get run for small inputs anyway.
  Mvecprod(map { _taupower($_->[0],$_->[1]) } Mfactor_exp($n));
}

sub _Euler {
 my($dig) = @_;
 return Math::Prime::Util::GMP::Euler($dig)
   if $dig > 70 && $Math::Prime::Util::_GMPfunc{"Euler"};
 '0.57721566490153286060651209008240243104215933593992359880576723488486772677766467';
}
sub _Li2 {
 my($dig) = @_;
 return Math::Prime::Util::GMP::li(2,$dig)
   if $dig > 70 && $Math::Prime::Util::_GMPfunc{"li"};
 '1.04516378011749278484458888919461313652261557815120157583290914407501320521';
}

sub ExponentialIntegral {
  my($x) = @_;
  return - MPU_INFINITY if $x == 0;
  return 0              if $x == - MPU_INFINITY;
  return MPU_INFINITY   if $x == MPU_INFINITY;

  if ($Math::Prime::Util::_GMPfunc{"ei"}) {
    $x = Math::BigFloat->new("$x") if defined $bignum::VERSION && ref($x) ne 'Math::BigFloat';
    return 0.0 + Math::Prime::Util::GMP::ei($x,40) if !ref($x);
    my $str = Math::Prime::Util::GMP::ei($x, _find_big_acc($x));
    return $x->copy->bzero->badd($str);
  }

  $x = Math::BigFloat->new("$x") if defined $bignum::VERSION && ref($x) ne 'Math::BigFloat';

  my $tol = 1e-16;
  my $sum = 0.0;
  my($y, $t);
  my $c = 0.0;
  my $val; # The result from one of the four methods

  if ($x < -1) {
    # Continued fraction
    my $lc = 0;
    my $ld = 1 / (1 - $x);
    $val = $ld * (-exp($x));
    for my $n (1 .. 100000) {
      $lc = 1 / (2*$n + 1 - $x - $n*$n*$lc);
      $ld = 1 / (2*$n + 1 - $x - $n*$n*$ld);
      my $old = $val;
      $val *= $ld/$lc;
      last if abs($val - $old) <= ($tol * abs($val));
    }
  } elsif ($x < 0) {
    # Rational Chebyshev approximation
    my @C6p = ( -148151.02102575750838086,
                 150260.59476436982420737,
                  89904.972007457256553251,
                  15924.175980637303639884,
                   2150.0672908092918123209,
                    116.69552669734461083368,
                      5.0196785185439843791020);
    my @C6q = (  256664.93484897117319268,
                 184340.70063353677359298,
                  52440.529172056355429883,
                   8125.8035174768735759866,
                    750.43163907103936624165,
                     40.205465640027706061433,
                      1.0000000000000000000000);
    my $sumn = $C6p[0]-$x*($C6p[1]-$x*($C6p[2]-$x*($C6p[3]-$x*($C6p[4]-$x*($C6p[5]-$x*$C6p[6])))));
    my $sumd = $C6q[0]-$x*($C6q[1]-$x*($C6q[2]-$x*($C6q[3]-$x*($C6q[4]-$x*($C6q[5]-$x*$C6q[6])))));
    $val = log(-$x) - ($sumn / $sumd);
  } elsif ($x < -log($tol)) {
    # Convergent series
    my $fact_n = 1;
    $y = _Euler(18)-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
    $y = log($x)-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
    for my $n (1 .. 200) {
      $fact_n *= $x/$n;
      my $term = $fact_n / $n;
      $y = $term-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
      last if $term < $tol;
    }
    $val = $sum;
  } else {
    # Asymptotic divergent series
    my $invx = 1.0 / $x;
    my $term = $invx;
    $sum = 1.0 + $term;
    for my $n (2 .. 200) {
      my $last_term = $term;
      $term *= $n * $invx;
      last if $term < $tol;
      if ($term < $last_term) {
        $y = $term-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
      } else {
        $y = (-$last_term/3)-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
        last;
      }
    }
    $val = exp($x) * $invx * $sum;
  }
  $val;
}

sub LogarithmicIntegral {
  my($x,$opt) = @_;
  return 0              if $x == 0;
  return - MPU_INFINITY if $x == 1;
  return MPU_INFINITY   if $x == MPU_INFINITY;
  croak "Invalid input to LogarithmicIntegral:  x must be > 0" if $x <= 0;
  $opt = 0 unless defined $opt;

  if ($Math::Prime::Util::_GMPfunc{"li"}) {
    $x = Math::BigFloat->new("$x") if defined $bignum::VERSION && ref($x) ne 'Math::BigFloat';
    return 0.0 + Math::Prime::Util::GMP::li($x,40) if !ref($x);
    my $str = Math::Prime::Util::GMP::li($x, _find_big_acc($x));
    return $x->copy->bzero->badd($str);
  }

  if ($x == 2) {
    my $li2const = (ref($x) eq 'Math::BigFloat') ? Math::BigFloat->new(_Li2(_find_big_acc($x))) : 0.0+_Li2(30);
    return $li2const;
  }

  if (defined $bignum::VERSION) {
    # If bignum is on, always use Math::BigFloat.
    $x = Math::BigFloat->new("$x") if ref($x) ne 'Math::BigFloat';
  } elsif (ref($x)) {
    # bignum is off, use native if small, BigFloat otherwise.
    if ($x <= 1e16) {
      $x = _bigint_to_int($x);
    } else {
      $x = _upgrade_to_float($x) if ref($x) ne 'Math::BigFloat';
    }
  }
  # Make sure we preserve whatever accuracy setting the input was using.
  $x->accuracy($_[0]->accuracy) if ref($x) && ref($_[0]) =~ /^Math::Big/ && $_[0]->accuracy;

  # Do divergent series here for big inputs.  Common for big pc approximations.
  # Why is this here?
  #   1) exp(log(x)) results in a lot of lost precision
  #   2) exp(x) with lots of precision turns out to be really slow, and in
  #      this case it was unnecessary.
  my $tol = 1e-16;
  my $xdigits = 0;
  my $finalacc = 0;
  if (ref($x) =~ /^Math::Big/) {
    $xdigits = _find_big_acc($x);
    my $xlen = length($x->copy->bfloor->bstr());
    $xdigits = $xlen if $xdigits < $xlen;
    $finalacc = $xdigits;
    $xdigits += length(int(log(0.0+"$x"))) + 1;
    $tol = Math::BigFloat->new(10)->bpow(-$xdigits);
    $x->accuracy($xdigits);
  }
  my $logx = $xdigits ? $x->copy->blog(undef,$xdigits) : log($x);

  # TODO: See if we can tune this
  if (0 && $x >= 1) {
    _upgrade_to_float();
    my $sum = Math::BigFloat->new(0);
    my $inner_sum = Math::BigFloat->new(0);
    my $p = Math::BigFloat->new(-1);
    my $factorial = 1;
    my $power2 = 1;
    my $q;
    my $k = 0;
    my $neglogx = -$logx;
    for my $n (1 .. 1000) {
      $factorial = mulint($factorial, $n);
      $q = mulint($factorial, $power2);
      $power2 = mulint(2, $power2);
      while ($k <= ($n-1)>>1) {
        $inner_sum += Math::BigFloat->new(1) / (2*$k+1);
        $k++;
      }
      $p *= $neglogx;
      my $term = ($p / $q) * $inner_sum;
      $sum += $term;
      last if abs($term) < $tol;
    }
    $sum *= sqrt($x);
    return 0.0+_Euler(18) + log($logx) + $sum unless ref($x)=~/^Math::Big/;
    my $val = Math::BigFloat->new(_Euler(40))->badd("".log($logx))->badd("$sum");
    $val->accuracy($finalacc) if $xdigits;
    return $val;
  }

  if ($x > 1e16) {
    my $invx = ref($logx) ? Math::BigFloat->bone / $logx : 1.0/$logx;
    # n = 0  =>  0!/(logx)^0 = 1/1 = 1
    # n = 1  =>  1!/(logx)^1 = 1/logx
    my $term = $invx;
    my $sum = 1.0 + $term;
    for my $n (2 .. 1000) {
      my $last_term = $term;
      $term *= $n * $invx;
      last if $term < $tol;
      if ($term < $last_term) {
        $sum += $term;
      } else {
        $sum -= ($last_term/3);
        last;
      }
      $term->bround($xdigits) if $xdigits;
    }
    $invx *= $sum;
    $invx *= $x;
    $invx->accuracy($finalacc) if ref($invx) && $xdigits;
    return $invx;
  }
  # Convergent series.
  if ($x >= 1) {
    my $fact_n = 1.0;
    my $nfac = 1.0;
    my $sum  = 0.0;
    for my $n (1 .. 200) {
      $fact_n *= $logx/$n;
      my $term = $fact_n / $n;
      $sum += $term;
      last if $term < $tol;
      $term->bround($xdigits) if $xdigits;
    }

    return 0.0+_Euler(18) + log($logx) + $sum unless ref($x) =~ /^Math::Big/;

    my $val = Math::BigFloat->new(_Euler(40))->badd("".log($logx))->badd("$sum");
    $val->accuracy($finalacc) if $xdigits;
    return $val;
  }

  ExponentialIntegral($logx);
}

# Riemann Zeta function for native integers.
my @_Riemann_Zeta_Table = (
  0.6449340668482264364724151666460251892,  # zeta(2) - 1
  0.2020569031595942853997381615114499908,
  0.0823232337111381915160036965411679028,
  0.0369277551433699263313654864570341681,
  0.0173430619844491397145179297909205279,
  0.0083492773819228268397975498497967596,
  0.0040773561979443393786852385086524653,
  0.0020083928260822144178527692324120605,
  0.0009945751278180853371459589003190170,
  0.0004941886041194645587022825264699365,
  0.0002460865533080482986379980477396710,
  0.0001227133475784891467518365263573957,
  0.0000612481350587048292585451051353337,
  0.0000305882363070204935517285106450626,
  0.0000152822594086518717325714876367220,
  0.0000076371976378997622736002935630292,
  0.0000038172932649998398564616446219397,
  0.0000019082127165539389256569577951013,
  0.0000009539620338727961131520386834493,
  0.0000004769329867878064631167196043730,
  0.0000002384505027277329900036481867530,
  0.0000001192199259653110730677887188823,
  0.0000000596081890512594796124402079358,
  0.0000000298035035146522801860637050694,
  0.0000000149015548283650412346585066307,
  0.0000000074507117898354294919810041706,
  0.0000000037253340247884570548192040184,
  0.0000000018626597235130490064039099454,
  0.0000000009313274324196681828717647350,
  0.0000000004656629065033784072989233251,
  0.0000000002328311833676505492001455976,
  0.0000000001164155017270051977592973835,
  0.0000000000582077208790270088924368599,
  0.0000000000291038504449709968692942523,
  0.0000000000145519218910419842359296322,
  0.0000000000072759598350574810145208690,
  0.0000000000036379795473786511902372363,
  0.0000000000018189896503070659475848321,
  0.0000000000009094947840263889282533118,
);


sub RiemannZeta {
  my($x) = @_;

  my $ix = ($x == int($x))  ?  "" . Math::BigInt->new($x)  :  0;

  # Try our GMP code if possible.
  if ($Math::Prime::Util::_GMPfunc{"zeta"}) {
    my($wantbf,$xdigits) = _bfdigits($x);
    # If we knew the *exact* number of zero digits, we could let GMP zeta
    # handle the correct rounding.  But we don't, so we have to go over.
    my $zero_dig = "".int($x / 3) - 1;
    my $strval = Math::Prime::Util::GMP::zeta($x, $xdigits + 8 + $zero_dig);
    if ($strval =~ s/^(1\.0*)/./) {
      $strval .= "e-".(length($1)-2) if length($1) > 2;
    } else {
      $strval =~ s/^(-?\d+)/$1-1/e;
    }

    return ($wantbf)  ?  Math::BigFloat->new($strval,$wantbf)  : 0.0 + $strval;
  }

  # If we need a bigfloat result, then call our PP routine.
  if (defined $bignum::VERSION || ref($x) =~ /^Math::Big/) {
    require Math::Prime::Util::ZetaBigFloat;
    return Math::Prime::Util::ZetaBigFloat::RiemannZeta($x);
  }

  # Native float results
  return 0.0 + $_Riemann_Zeta_Table[int($x)-2]
    if $x == int($x) && defined $_Riemann_Zeta_Table[int($x)-2];
  my $tol = 1.11e-16;

  # Series based on (2n)! / B_2n.
  # This is a simplification of the Cephes zeta function.
  my @A = (
      12.0,
     -720.0,
      30240.0,
     -1209600.0,
      47900160.0,
     -1892437580.3183791606367583212735166426,
      74724249600.0,
     -2950130727918.1642244954382084600497650,
      116467828143500.67248729113000661089202,
     -4597978722407472.6105457273596737891657,
      181521054019435467.73425331153534235290,
     -7166165256175667011.3346447367083352776,
      282908877253042996618.18640556532523927,
  );
  my $s = 0.0;
  my $rb = 0.0;
  foreach my $i (2 .. 10) {
    $rb = $i ** -$x;
    $s += $rb;
    return $s if abs($rb/$s) < $tol;
  }
  my $w = 10.0;
  $s = $s  +  $rb*$w/($x-1.0)  -  0.5*$rb;
  my $ra = 1.0;
  foreach my $i (0 .. 12) {
    my $k = 2*$i;
    $ra *= $x + $k;
    $rb /= $w;
    my $t = $ra*$rb/$A[$i];
    $s += $t;
    $t = abs($t/$s);
    last if $t < $tol;
    $ra *= $x + $k + 1.0;
    $rb /= $w;
  }
  return $s;
}

# Riemann R function
sub RiemannR {
  my($x) = @_;

  croak "Invalid input to ReimannR:  x must be > 0" if $x <= 0;

  # With MPU::GMP v0.49 this is fast.
  if ($Math::Prime::Util::_GMPfunc{"riemannr"}) {
    my($wantbf,$xdigits) = _bfdigits($x);
    my $strval = Math::Prime::Util::GMP::riemannr($x, $xdigits);
    return ($wantbf)  ?  Math::BigFloat->new($strval,$wantbf)  :  0.0 + $strval;
  }


# TODO: look into this as a generic solution
if (0 && $Math::Prime::Util::_GMPfunc{"zeta"}) {
  my($wantbf,$xdigits) = _bfdigits($x);
  $x = _upgrade_to_float($x);

  my $extra_acc = 4;
  $xdigits += $extra_acc;
  $x->accuracy($xdigits);

  my $logx = log($x);
  my $part_term = $x->copy->bone;
  my $sum = $x->copy->bone;
  my $tol = $x->copy->bone->brsft($xdigits-1, 10);
  my $bigk = $x->copy->bone;
  my $term;
  for my $k (1 .. 10000) {
    $part_term *= $logx / $bigk;
    my $zarg = $bigk->copy->binc;
    my $zeta = (RiemannZeta($zarg) * $bigk) + $bigk;
    #my $strval = Math::Prime::Util::GMP::zeta($k+1, $xdigits + int(($k+1) / 3));
    #my $zeta = Math::BigFloat->new($strval)->bdec->bmul($bigk)->badd($bigk);
    $term = $part_term / $zeta;
    $sum += $term;
    last if $term < ($tol * $sum);
    $bigk->binc;
  }
  $sum->bround($xdigits-$extra_acc);
  my $strval = "$sum";
  return ($wantbf)  ?  Math::BigFloat->new($strval,$wantbf)  :  0.0 + $strval;
}

  if (defined $bignum::VERSION || ref($x) =~ /^Math::Big/) {
    require Math::Prime::Util::ZetaBigFloat;
    return Math::Prime::Util::ZetaBigFloat::RiemannR($x);
  }

  my $sum = 0.0;
  my $tol = 1e-18;
  my($c, $y, $t) = (0.0);
  if ($x > 10**17) {
    my @mob = Mmoebius(0,300);
    for my $k (1 .. 300) {
      next if $mob[$k] == 0;
      my $term = $mob[$k] / $k *
                 Math::Prime::Util::LogarithmicIntegral($x**(1.0/$k));
      $y = $term-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
      last if abs($term) < ($tol * abs($sum));
    }
  } else {
    $y = 1.0-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
    my $flogx = log($x);
    my $part_term = 1.0;
    for my $k (1 .. 10000) {
      my $zeta = ($k <= $#_Riemann_Zeta_Table)
                 ? $_Riemann_Zeta_Table[$k+1-2]    # Small k from table
                 : RiemannZeta($k+1);              # Large k from function
      $part_term *= $flogx / $k;
      my $term = $part_term / ($k + $k * $zeta);
      $y = $term-$c; $t = $sum+$y; $c = ($t-$sum)-$y; $sum = $t;
      last if $term < ($tol * $sum);
    }
  }
  return $sum;
}

sub LambertW {
  my $x = shift;
  croak "Invalid input to LambertW:  x must be >= -1/e" if $x < -0.36787944118;
  $x = _upgrade_to_float($x) if ref($x) eq 'Math::BigInt';
  my $xacc = ref($x) ? _find_big_acc($x) : 0;
  my $w;

  if ($Math::Prime::Util::_GMPfunc{"lambertw"}) {
    my $w = (!$xacc)
          ? 0.0 + Math::Prime::Util::GMP::lambertw($x)
          : $x->copy->bzero->badd(Math::Prime::Util::GMP::lambertw($x, $xacc));
    return $w;
  }

  # Approximation
  if ($x < -0.06) {
    my $ti = $x * 2 * exp($x-$x+1) + 2;
    return -1 if $ti <= 0;
    my $t  = sqrt($ti);
    $w = (-1 + 1/6*$t + (257/720)*$t*$t + (13/720)*$t*$t*$t) / (1 + (5/6)*$t + (103/720)*$t*$t);
  } elsif ($x < 1.363) {
    my $l1 = log($x + 1);
    $w = $l1 * (1 - log(1+$l1) / (2+$l1));
  } elsif ($x < 3.7) {
    my $l1 = log($x);
    my $l2 = log($l1);
    $w = $l1 - $l2 - log(1 - $l2/$l1)/2.0;
  } else {
    my $l1 = log($x);
    my $l2 = log($l1);
    my $d1 = 2 * $l1 * $l1;
    my $d2 = 3 * $l1 * $d1;
    my $d3 = 2 * $l1 * $d2;
    my $d4 = 5 * $l1 * $d3;
    $w = $l1 - $l2 + $l2/$l1 + $l2*($l2-2)/$d1
       + $l2*(6+$l2*(-9+2*$l2))/$d2
       + $l2*(-12+$l2*(36+$l2*(-22+3*$l2)))/$d3
       + $l2*(60+$l2*(-300+$l2*(350+$l2*(-125+12*$l2))))/$d4;
  }

  # Now iterate to get the answer
  #
  # Newton:
  #   $w = $w*(log($x) - log($w) + 1) / ($w+1);
  # Halley:
  #   my $e = exp($w);
  #   my $f = $w * $e - $x;
  #   $w -= $f / ($w*$e+$e - ($w+2)*$f/(2*$w+2));

  # Fritsch converges quadratically, so tolerance could be 4x smaller.  Use 2x.
  my $tol = ($xacc) ? 10**(-int(1+$xacc/2)) : 1e-16;
  $w->accuracy($xacc+10) if $xacc;
  for (1 .. 200) {
    last if $w == 0;
    my $w1 = $w + 1;
    my $zn = log($x/$w) - $w;
    my $qn = $w1 * 2 * ($w1+(2*$zn/3));
    my $en = ($zn/$w1) * ($qn-$zn)/($qn-$zn*2);
    my $wen = $w * $en;
    $w += $wen;
    last if abs($wen) < $tol;
  }
  $w->accuracy($xacc) if $xacc;

  $w;
}

my $_Pi = "3.141592653589793238462643383279503";
sub Pi {
  my $digits = shift;
  return 0.0+$_Pi unless $digits;
  return 0.0+sprintf("%.*lf", $digits-1, $_Pi) if $digits < 15;
  return _upgrade_to_float($_Pi, $digits) if $digits < 30;

  # Performance ranking:
  #   MPU::GMP         Uses AGM or Ramanujan/Chudnosky with binary splitting
  #   MPFR             Uses AGM, from 1x to 1/4x the above
  #   Perl AGM w/GMP   also AGM, nice growth rate, but slower than above
  #   C pidigits       much worse than above, but faster than the others
  #   Perl AGM         without Math::BigInt::GMP, it's sluggish
  #   Math::BigFloat   new versions use AGM, old ones are *very* slow
  #
  # With a few thousand digits, any of the top 4 are fine.
  # At 10k digits, the first two are pulling away.
  # At 50k digits, the first three are 5-20x faster than C pidigits, and
  #   pray you're not having to the Perl BigFloat methods without GMP.
  # At 100k digits, the first two are 15x faster than the third, C pidigits
  #   is 200x slower, and the rest thousands of times slower.
  # At 1M digits, the first is under 1 second, MPFR under 2 seconds,
  #   Perl AGM (Math::BigInt::GMP) is over a minute, and C piigits at 1.5 hours.
  #
  # Interestingly, Math::BigInt::Pari, while greatly faster than Calc, is
  # *much* slower than GMP for these operations (both AGM and Machin).  While
  # Perl AGM with the Math::BigInt::GMP backend will pull away from C pidigits,
  # using it with the other backends doesn't do so.
  #
  # The GMP program at https://gmplib.org/download/misc/gmp-chudnovsky.c
  # will run ~4x faster than MPFR and ~1.5x faster than MPU::GMP.

  my $have_bigint_gmp = Math::BigInt->config()->{lib} =~ /GMP/;
  my $have_xdigits    = Math::Prime::Util::prime_get_config()->{'xs'};
  my $_verbose = Math::Prime::Util::prime_get_config()->{'verbose'};

  if ($Math::Prime::Util::_GMPfunc{"Pi"}) {
    print "  using MPUGMP for Pi($digits)\n" if $_verbose;
    return _upgrade_to_float( Math::Prime::Util::GMP::Pi($digits) );
  }

  # We could consider looking for Math::MPFR or Math::Pari

  # This has a *much* better growth rate than the later solutions.
  if ( !$have_xdigits || ($have_bigint_gmp && $digits > 100) ) {
    print "  using Perl AGM for Pi($digits)\n" if $_verbose;
    # Brent-Salamin (aka AGM or Gauss-Legendre)
    $digits += 8;
    my $HALF = _upgrade_to_float(0.5);
    my ($an, $bn, $tn, $pn) = ($HALF->copy->bone, $HALF->copy->bsqrt($digits),
                               $HALF->copy->bmul($HALF), $HALF->copy->bone);
    while ($pn < $digits) {
      my $prev_an = $an->copy;
      $an->badd($bn)->bmul($HALF, $digits);
      $bn->bmul($prev_an)->bsqrt($digits);
      $prev_an->bsub($an);
      $tn->bsub($pn * $prev_an * $prev_an);
      $pn->badd($pn);
    }
    $an->badd($bn);
    $an->bmul($an,$digits)->bdiv(4*$tn, $digits-8);
    return $an;
  }

  # Spigot method in C.  Low overhead but not good growth rate.
  if ($have_xdigits) {
    print "  using XS spigot for Pi($digits)\n" if $_verbose;
    return _upgrade_to_float(Math::Prime::Util::_pidigits($digits));
  }

  # We're going to have to use the Math::BigFloat code.
  # 1) it rounds incorrectly (e.g. 761, 1372, 1509,...).
  #    Fix by adding some digits and rounding.
  # 2) AGM is *much* faster once past ~2000 digits
  # 3) It is very slow without the GMP backend.  The Pari backend helps
  #    but it still pretty bad.  With Calc it's glacial for large inputs.

  #           Math::BigFloat                AGM              spigot   AGM
  # Size     GMP    Pari  Calc        GMP    Pari  Calc        C      C+GMP
  #   500   0.04    0.60   0.30      0.08    0.10   0.47      0.09    0.06
  #  1000   0.04    0.11   1.82      0.09    0.14   1.82      0.09    0.06
  #  2000   0.07    0.37  13.5       0.09    0.34   9.16      0.10    0.06
  #  4000   0.14    2.17 107.8       0.12    1.14  39.7       0.20    0.06
  #  8000   0.52   15.7              0.22    4.63 186.2       0.56    0.08
  # 16000   2.73  121.8              0.52   19.2              2.00    0.08
  # 32000  15.4                      1.42                     7.78    0.12
  #                                   ^                        ^       ^
  #                                   |      use this THIRD ---+       |
  #                use this SECOND ---+                                |
  #                                                  use this FIRST ---+
  # approx
  # growth  5.6x    7.6x   8.0x      2.7x    4.1x   4.7x      3.9x    2.0x

  print "  using BigFloat for Pi($digits)\n" if $_verbose;
  _upgrade_to_float(0);
  return Math::BigFloat::bpi($digits+10)->round($digits);
}

sub forpart {
  my($sub, $n, $rhash) = @_;
  _forcompositions(1, $sub, $n, $rhash);
}
sub forcomp {
  my($sub, $n, $rhash) = @_;
  _forcompositions(0, $sub, $n, $rhash);
}
sub _forcompositions {
  my($ispart, $sub, $n, $rhash) = @_;
  _validate_positive_integer($n);
  my($mina, $maxa, $minn, $maxn, $primeq) = (1,$n,1,$n,-1);
  if (defined $rhash) {
    croak "forpart second argument must be a hash reference"
      unless ref($rhash) eq 'HASH';
    if (defined $rhash->{amin}) {
      $mina = $rhash->{amin};
      _validate_positive_integer($mina);
    }
    if (defined $rhash->{amax}) {
      $maxa = $rhash->{amax};
      _validate_positive_integer($maxa);
    }
    $minn = $maxn = $rhash->{n} if defined $rhash->{n};
    $minn = $rhash->{nmin} if defined $rhash->{nmin};
    $maxn = $rhash->{nmax} if defined $rhash->{nmax};
    _validate_positive_integer($minn);
    _validate_positive_integer($maxn);
    if (defined $rhash->{prime}) {
      $primeq = $rhash->{prime};
      _validate_positive_integer($primeq);
    }
   $mina = 1 if $mina < 1;
   $maxa = $n if $maxa > $n;
   $minn = 1 if $minn < 1;
   $maxn = $n if $maxn > $n;
   $primeq = 2 if $primeq != -1 && $primeq != 0;
  }

  $sub->() if $n == 0 && $minn <= 1;
  return if $n < $minn || $minn > $maxn || $mina > $maxa || $maxn <= 0 || $maxa <= 0;

  my $oldforexit = Math::Prime::Util::_start_for_loop();
  my ($x, $y, $r, $k);
  my @a = (0) x ($n);
  $k = 1;
  $a[0] = $mina - 1;
  $a[1] = $n - $mina + 1;
  while ($k != 0) {
    $x = $a[$k-1]+1;
    $y = $a[$k]-1;
    $k--;
    $r = $ispart ? $x : 1;
    while ($r <= $y) {
      $a[$k] = $x;
      $x = $r;
      $y -= $x;
      $k++;
    }
    $a[$k] = $x + $y;
    # Restrict size
    while ($k+1 > $maxn) {
      $a[$k-1] += $a[$k];
      $k--;
    }
    next if $k+1 < $minn;
    # Restrict values
    if ($mina > 1 || $maxa < $n) {
      last if $a[0] > $maxa;
      if ($ispart) {
        next if $a[$k] > $maxa;
      } else {
        next if Mvecany(sub{ $_ < $mina || $_ > $maxa }, @a[0..$k]);
      }
    }
    next if $primeq == 0 && Mvecany(sub{ Mis_prime($_) }, @a[0..$k]);
    next if $primeq == 2 && Mvecany(sub{ !Mis_prime($_) }, @a[0..$k]);
    last if Math::Prime::Util::_get_forexit();
    $sub->(@a[0 .. $k]);
  }
  Math::Prime::Util::_end_for_loop($oldforexit);
}
sub forcomb {
  my($sub, $n, $k) = @_;
  _validate_positive_integer($n);

  my($begk, $endk);
  if (defined $k) {
    _validate_positive_integer($k);
    return if $k > $n;
    $begk = $endk = $k;
  } else {
    $begk = 0;
    $endk = $n;
  }

  my $oldforexit = Math::Prime::Util::_start_for_loop();
  for my $k ($begk .. $endk) {
    if ($k == 0) {
      $sub->();
    } else {
      my @c = 0 .. $k-1;
      while (1) {
        $sub->(@c);
        last if Math::Prime::Util::_get_forexit();
        next if $c[-1]++ < $n-1;
        my $i = $k-2;
        $i-- while $i >= 0 && $c[$i] >= $n-($k-$i);
        last if $i < 0;
        $c[$i]++;
        while (++$i < $k) { $c[$i] = $c[$i-1] + 1; }
      }
    }
    last if Math::Prime::Util::_get_forexit();
  }
  Math::Prime::Util::_end_for_loop($oldforexit);
}
sub _forperm {
  my($sub, $n, $all_perm) = @_;
  my $k = $n;
  my @c = reverse 0 .. $k-1;
  my $inc = 0;
  my $send = 1;
  my $oldforexit = Math::Prime::Util::_start_for_loop();
  while (1) {
    if (!$all_perm) {   # Derangements via simple filtering.
      $send = 1;
      for my $p (0 .. $#c) {
        if ($c[$p] == $k-$p-1) {
          $send = 0;
          last;
        }
      }
    }
    if ($send) {
      $sub->(reverse @c);
      last if Math::Prime::Util::_get_forexit();
    }
    if (++$inc & 1) {
      @c[0,1] = @c[1,0];
      next;
    }
    my $j = 2;
    $j++ while $j < $k && $c[$j] > $c[$j-1];
    last if $j >= $k;
    my $m = 0;
    $m++ while $c[$j] > $c[$m];
    @c[$j,$m] = @c[$m,$j];
    @c[0..$j-1] = reverse @c[0..$j-1];
  }
  Math::Prime::Util::_end_for_loop($oldforexit);
}
sub forperm {
  my($sub, $n, $k) = @_;
  _validate_positive_integer($n);
  croak "Too many arguments for forperm" if defined $k;
  return $sub->() if $n == 0;
  return $sub->(0) if $n == 1;
  _forperm($sub, $n, 1);
}
sub forderange {
  my($sub, $n, $k) = @_;
  _validate_positive_integer($n);
  croak "Too many arguments for forderange" if defined $k;
  return $sub->() if $n == 0;
  return if $n == 1;
  _forperm($sub, $n, 0);
}

sub _multiset_permutations {
  my($sub, $prefix, $ar, $sum) = @_;

  return if $sum == 0;

  # Remove any values with 0 occurances
  my @n = grep { $_->[1] > 0 } @$ar;

  if ($sum == 1) {                       # A single value
    $sub->(@$prefix, $n[0]->[0]);
  } elsif ($sum == 2) {                  # Optimize the leaf case
    my($n0,$n1) = map { $_->[0] } @n;
    if (@n == 1) {
      $sub->(@$prefix, $n0, $n0);
    } else {
      $sub->(@$prefix, $n0, $n1);
      $sub->(@$prefix, $n1, $n0) unless Math::Prime::Util::_get_forexit();
    }
  } elsif (0 && $sum == scalar(@n)) {         # All entries have 1 occurance
    # TODO:  Figure out a way to use this safely.  We need to capture any
    #        lastfor that was seen in the forperm.
    my @i = map { $_->[0] } @n;
    Math::Prime::Util::forperm(sub { $sub->(@$prefix, @i[@_]) }, 1+$#i);
  } else {                               # Recurse over each leading value
    for my $v (@n) {
      $v->[1]--;
      push @$prefix, $v->[0];
      no warnings 'recursion';
      _multiset_permutations($sub, $prefix, \@n, $sum-1);
      pop @$prefix;
      $v->[1]++;
      last if Math::Prime::Util::_get_forexit();
    }
  }
}

sub numtoperm {
  my($n,$k) = @_;
  _validate_positive_integer($n);
  _validate_integer($k);
  return () if $n == 0;
  return (0) if $n == 1;
  my $f = Mfactorial($n-1);
  $k %= Mmulint($f,$n) if $k < 0 || int($k/$f) >= $n;
  my @S = map { $_ } 0 .. $n-1;
  my @V;
  while ($n-- > 0) {
    my $i = int($k/$f);
    push @V, splice(@S,$i,1);
    last if $n == 0;
    $k -= $i*$f;
    $f /= $n;
  }
  @V;
}

sub permtonum {
  my $A = shift;
  croak "permtonum argument must be an array reference"
    unless ref($A) eq 'ARRAY';
  my $n = scalar(@$A);
  return 0 if $n == 0;
  {
    my %S;
    for my $v (@$A) {
      croak "permtonum invalid permutation array"
        if !defined $v || $v < 0 || $v >= $n || $S{$v}++;
    }
  }
  my $f = factorial($n-1);
  my $rank = 0;
  for my $i (0 .. $n-2) {
    my $k = 0;
    for my $j ($i+1 .. $n-1) {
      $k++ if $A->[$j] < $A->[$i];
    }
    $rank = Maddint($rank, Mmulint($k,$f));
    $f /= $n-$i-1;
  }
  $rank;
}

sub randperm {
  my($n,$k) = @_;
  _validate_positive_integer($n);
  if (defined $k) {
    _validate_positive_integer($k);
  }
  $k = $n if !defined($k) || $k > $n;
  return () if $k == 0;

  my @S;
  if ("$k"/"$n" <= 0.30) {
    my %seen;
    my $v;
    for my $i (1 .. $k) {
      do { $v = Murandomm($n); } while $seen{$v}++;
      push @S,$v;
    }
  } else {
    @S = map { $_ } 0..$n-1;
    for my $i (0 .. $n-2) {
      last if $i >= $k;
      my $j = Murandomm($n-$i);
      @S[$i,$i+$j] = @S[$i+$j,$i];
    }
    $#S = $k-1;
  }
  return @S;
}

sub shuffle {
  my @S=@_;
  # Note: almost all the time is spent in urandomm.
  for (my $i = $#S; $i >= 1; $i--) {
    my $j = Murandomm($i+1);
    @S[$i,$j] = @S[$j,$i];
  }
  @S;
}

###############################################################################
#       Random numbers
###############################################################################

# PPFE:  irand irand64 drand random_bytes csrand srand _is_csprng_well_seeded
sub urandomb {
  my($n) = @_;
  return 0 if $n <= 0;
  return ( Math::Prime::Util::irand() >> (32-$n) ) if $n <= 32;
  return ( Math::Prime::Util::irand64() >> (64-$n) ) if MPU_MAXBITS >= 64 && $n <= 64;
  my $bytes = Math::Prime::Util::random_bytes(($n+7)>>3);
  my $binary = substr(unpack("B*",$bytes),0,$n);
  return Math::BigInt->new("0b$binary");
}
sub urandomm {
  my($n) = @_;
  # _validate_positive_integer($n);
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::urandomm($n))
    if $Math::Prime::Util::_GMPfunc{"urandomm"};
  return 0 if $n <= 1;
  my $r;
  if ($n <= 4294967295) {
    my $rmax = int(4294967295 / $n) * $n;
    do { $r = Math::Prime::Util::irand() } while $r >= $rmax;
  } elsif (!ref($n)) {
    my $rmax = int(~0 / $n) * $n;
    do { $r = Math::Prime::Util::irand64() } while $r >= $rmax;
  } else {
    # TODO: verify and try to optimize this
    my $bits = length($n->as_bin) - 2;
    my $bytes = 1 + (($bits+7)>>3);
    my $rmax = Math::BigInt->bone->blsft($bytes*8)->bdec;
    my $overflow = $rmax - ($rmax % $n);
    do { $r = Murandomb($bytes*8); } while $r >= $overflow;
  }
  return $r % $n;
}

sub random_prime {
  my($low, $high) = @_;
  if (scalar(@_) == 1) { ($low,$high) = (2,$low);          }
  else                 { _validate_positive_integer($low); }
  _validate_positive_integer($high);

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::random_prime($low, $high))
    if $Math::Prime::Util::_GMPfunc{"random_prime"};

  require Math::Prime::Util::RandomPrimes;
  return Math::Prime::Util::RandomPrimes::random_prime($low,$high);
}

sub random_ndigit_prime {
  my($digits) = @_;
  _validate_positive_integer($digits, 1);
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::random_ndigit_prime($digits))
    if $Math::Prime::Util::_GMPfunc{"random_ndigit_prime"};
  require Math::Prime::Util::RandomPrimes;
  return Math::Prime::Util::RandomPrimes::random_ndigit_prime($digits);
}
sub random_nbit_prime {
  my($bits) = @_;
  _validate_positive_integer($bits, 2);
  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::random_nbit_prime($bits))
    if $Math::Prime::Util::_GMPfunc{"random_nbit_prime"};
  require Math::Prime::Util::RandomPrimes;
  return Math::Prime::Util::RandomPrimes::random_nbit_prime($bits);
}
sub random_safe_prime {
  my($bits) = @_;
  _validate_positive_integer($bits, 3);
  return Math::Prime::Util::_reftyped($_[0], eval "Math::Prime::Util::GMP::random_safe_prime($bits)")  ## no critic qw(ProhibitStringyEval)
    if $Math::Prime::Util::_GMPfunc{"random_safe_prime"};
  require Math::Prime::Util::RandomPrimes;
  return Math::Prime::Util::RandomPrimes::random_safe_prime($bits);
}
sub random_strong_prime {
  my($bits) = @_;
  _validate_positive_integer($bits, 128);
  return Math::Prime::Util::_reftyped($_[0], eval "Math::Prime::Util::GMP::random_strong_prime($bits)")  ## no critic qw(ProhibitStringyEval)
    if $Math::Prime::Util::_GMPfunc{"random_strong_prime"};
  require Math::Prime::Util::RandomPrimes;
  return Math::Prime::Util::RandomPrimes::random_strong_prime($bits);
}

sub random_maurer_prime {
  my($bits) = @_;
  _validate_positive_integer($bits, 2);

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::random_maurer_prime($bits))
    if $Math::Prime::Util::_GMPfunc{"random_maurer_prime"};

  require Math::Prime::Util::RandomPrimes;
  my ($n, $cert) = Math::Prime::Util::RandomPrimes::random_maurer_prime_with_cert($bits);
  croak "maurer prime $n failed certificate verification!"
        unless Math::Prime::Util::verify_prime($cert);

  return $n;
}

sub random_shawe_taylor_prime {
  my($bits) = @_;
  _validate_positive_integer($bits, 2);

  return Math::Prime::Util::_reftyped($_[0], Math::Prime::Util::GMP::random_shawe_taylor_prime($bits))
    if $Math::Prime::Util::_GMPfunc{"random_shawe_taylor_prime"};

  require Math::Prime::Util::RandomPrimes;
  my ($n, $cert) = Math::Prime::Util::RandomPrimes::random_shawe_taylor_prime_with_cert($bits);
  croak "shawe-taylor prime $n failed certificate verification!"
        unless Math::Prime::Util::verify_prime($cert);

  return $n;
}

sub miller_rabin_random {
  my($n, $k, $seed) = @_;
  _validate_positive_integer($n);
  if (scalar(@_) == 1 ) { $k = 1; } else { _validate_positive_integer($k); }

  return 1 if $k <= 0;

  if ($Math::Prime::Util::_GMPfunc{"miller_rabin_random"}) {
    return Math::Prime::Util::GMP::miller_rabin_random($n, $k, $seed) if defined $seed;
    return Math::Prime::Util::GMP::miller_rabin_random($n, $k);
  }

  # Math::Prime::Util::prime_get_config()->{'assume_rh'})  ==>  2*log(n)^2
  if ($k >= int(3*$n/4) ) {
    for (2 .. int(3*$n/4)+2) {
      return 0 unless Math::Prime::Util::is_strong_pseudoprime($n, $_);
    }
    return 1;
  }
  my $brange = $n-2;
  return 0 unless Math::Prime::Util::is_strong_pseudoprime($n, Murandomm($brange)+2 );
  $k--;
  while ($k > 0) {
    my $nbases = ($k >= 20) ? 20 : $k;
    return 0 unless is_strong_pseudoprime($n, map { Murandomm($brange)+2 } 1 .. $nbases);
    $k -= $nbases;
  }
  1;
}

sub random_semiprime {
  my($b) = @_;
  return 0 if defined $b && int($b) < 0;
  _validate_positive_integer($b,4);

  my $n;
  my $min = ($b <= MPU_MAXBITS)  ?  (1 << ($b-1))  :  BTWO->copy->bpow($b-1);
  my $max = $min + ($min - 1);
  my $L = $b >> 1;
  my $N = $b - $L;
  my $one = ($b <= MPU_MAXBITS) ? 1 : BONE;
  do {
    $n = $one * random_nbit_prime($L) * random_nbit_prime($N);
  } while $n < $min || $n > $max;
  $n = _bigint_to_int($n) if ref($n) && $n->bacmp(BMAX) <= 0;
  $n;
}

sub random_unrestricted_semiprime {
  my($b) = @_;
  return 0 if defined $b && int($b) < 0;
  _validate_positive_integer($b,3);

  my $n;
  my $min = ($b <= MPU_MAXBITS)  ?  (1 << ($b-1))  :  BTWO->copy->bpow($b-1);
  my $max = $min + ($min - 1);

  if ($b <= 64) {
    do {
      $n = $min + Murandomb($b-1);
    } while !Math::Prime::Util::is_semiprime($n);
  } else {
    # Try to get probabilities right for small divisors
    my %M = (
      2 => 1.91218397452243,
      3 => 1.33954826555021,
      5 => 0.854756717114822,
      7 => 0.635492301836862,
      11 => 0.426616792046787,
      13 => 0.368193843118344,
      17 => 0.290512701603111,
      19 => 0.263359264658156,
      23 => 0.222406328935102,
      29 => 0.181229250520242,
      31 => 0.170874199059434,
      37 => 0.146112155735473,
      41 => 0.133427839963585,
      43 => 0.127929010905662,
      47 => 0.118254609086782,
      53 => 0.106316418106489,
      59 => 0.0966989675438643,
      61 => 0.0938833658008547,
      67 => 0.0864151823151671,
      71 => 0.0820822953188297,
      73 => 0.0800964416340746,
      79 => 0.0747060914833344,
      83 => 0.0714973706654851,
      89 => 0.0672115468436284,
      97 => 0.0622818892486191,
      101 => 0.0600855891549939,
      103 => 0.0590613570015407,
      107 => 0.0570921135626976,
      109 => 0.0561691667641485,
      113 => 0.0544330141081874,
      127 => 0.0490620204315701,
    );
    my ($p,$r);
    $r = Math::Prime::Util::drand();
    for my $prime (2..127) {
      next unless defined $M{$prime};
      my $PR = $M{$prime} / $b  +  0.19556 / $prime;
      if ($r <= $PR) {
        $p = $prime;
        last;
      }
      $r -= $PR;
    }
    if (!defined $p) {
      # Idea from Charles Greathouse IV, 2010.  The distribution is right
      # at the high level (small primes weighted more and not far off what
      # we get with the uniform selection), but there is a noticeable skew
      # toward primes with a large gap after them.  For instance 3 ends up
      # being weighted as much as 2, and 7 more than 5.
      #
      # Since we handled small divisors earlier, this is less bothersome.
      my $M = 0.26149721284764278375542683860869585905;
      my $weight = $M + log($b * log(2)/2);
      my $minr = log(log(131));
      do {
        $r  = Math::Prime::Util::drand($weight) - $M;
      } while $r < $minr;
      # Using Math::BigFloat::bexp is ungodly slow, so avoid at all costs.
      my $re = exp($r);
      my $a = ($re < log(~0)) ? int(exp($re)+0.5)
                              : _upgrade_to_float($re)->bexp->bround->as_int;
      $p = $a < 2 ? 2 : Mprev_prime($a+1);
    }
    my $ranmin = ref($min) ? $min->badd($p-1)->bdiv($p)->as_int : int(($min+$p-1)/$p);
    my $ranmax = ref($max) ? $max->bdiv($p)->as_int : int($max/$p);
    my $q = random_prime($ranmin, $ranmax);
    $n = Mmulint($p,$q);
  }
  $n = _bigint_to_int($n) if ref($n) && $n->bacmp(BMAX) <= 0;
  $n;
}

sub random_factored_integer {
  my($n) = @_;
  return (0,[]) if defined $n && int($n) < 0;
  _validate_positive_integer($n,1);

  while (1) {
    my @S = ($n);
    # make s_i chain
    push @S, 1 + Murandomm($S[-1])  while $S[-1] > 1;
    # first is n, last is 1
    @S = grep { Mis_prime($_) } @S[1 .. $#S-1];
    my $r = Mvecprod(@S);
    return ($r, [@S]) if $r <= $n && (1+Murandomm($n)) <= $r;
  }
}



1;

__END__


# ABSTRACT: Pure Perl version of Math::Prime::Util

=pod

=encoding utf8


=head1 NAME

Math::Prime::Util::PP - Pure Perl version of Math::Prime::Util


=head1 VERSION

Version 0.73


=head1 SYNOPSIS

The functionality is basically identical to L<Math::Prime::Util>, as this
module is just the Pure Perl implementation.  This documentation will only
note differences.

  # Normally you would just import the functions you are using.
  # Nothing is exported by default.
  use Math::Prime::Util ':all';


=head1 DESCRIPTION

Pure Perl implementations of prime number utilities that are normally
handled with XS or GMP.  Having the Perl implementations (1) provides examples,
(2) allows the functions to run even if XS isn't available, and (3) gives
big number support if L<Math::Prime::Util::GMP> isn't available.  This is a
subset of L<Math::Prime::Util>'s functionality.

All routines should work with native integers or multi-precision numbers.  To
enable big numbers, use bigint or bignum:

    use bigint;
    say prime_count_approx(1000000000000000000000000)'
    # says 18435599767347543283712

This is still experimental, and some functions will be very slow.  The
L<Math::Prime::Util::GMP> module has much faster versions of many of these
functions.  Alternately, L<Math::Pari> has a lot of these types of functions.


=head1 FUNCTIONS

=head2 euler_phi

Takes a I<single> integer input and returns the Euler totient.

=head2 euler_phi_range

Takes two values defining a range C<low> to C<high> and returns an array
with the totient of each value in the range, inclusive.

=head2 moebius

Takes a I<single> integer input and returns the Moebius function.

=head2 moebius_range

Takes two values defining a range C<low> to C<high> and returns an array
with the Moebius function of each value in the range, inclusive.


=head1 LIMITATIONS

The SQUFOF and Fermat factoring algorithms are not implemented yet.

Some of the prime methods use more memory than they should, as the segmented
sieve is not properly used in C<primes> and C<prime_count>.


=head1 PERFORMANCE

Performance compared to the XS/C code is quite poor for many operations.  Some
operations that are relatively close for small and medium-size values:

  next_prime / prev_prime
  is_prime / is_prob_prime
  is_strong_pseudoprime
  ExponentialIntegral / LogarithmicIntegral / RiemannR
  primearray

Operations that are slower include:

  primes
  random_prime / random_ndigit_prime
  factor / factor_exp / divisors
  nth_prime
  prime_count
  is_aks_prime

Performance improvement in this code is still possible.  The prime sieve is
over 2x faster than anything I was able to find online, but it is still has
room for improvement.

L<Math::Prime::Util::GMP> offers C<C+XS+GMP> support for most of the important
functions, and will be vastly faster for most operations.  If you install that
module, L<Math::Prime::Util> will load it automatically, meaning you should
not have to think about what code is actually being used (C, GMP, or Perl).

Memory use will generally be higher for the PP code, and in some cases B<much>
higher.  Some of this may be addressed in a later release.

For small values (e.g. primes and prime counts under 10M) most of this will
not matter.


=head1 SEE ALSO

L<Math::Prime::Util>

L<Math::Prime::Util::GMP>


=head1 AUTHORS

Dana Jacobsen E<lt>dana@acm.orgE<gt>


=head1 COPYRIGHT

Copyright 2012-2021 by Dana Jacobsen E<lt>dana@acm.orgE<gt>

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

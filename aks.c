#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

/* The AKS primality algorithm for native integers.
 *
 * There are three versions here:
 *   V6         The v6 algorithm from the latest AKS paper.
 *              https://www.cse.iitk.ac.in/users/manindra/algebra/primality_v6.pdf
 *   BORNEMANN  Improvements from Bernstein, Voloch, and a clever r/s
 *              selection from Folkmar Bornemann.  Similar to Bornemann's
 *              2003 Pari/GP implementation:
 *              https://homepage.univie.ac.at/Dietrich.Burde/pari/aks.gp
 *   BERN41     My implementation of theorem 4.1 from Bernstein's 2003 paper.
 *              https://cr.yp.to/papers/aks.pdf
 *
 * Each one is orders of magnitude faster than the previous, and by default
 * we use Bernstein 4.1 as it is by far the fastest.
 *
 * Note that AKS is very, very slow compared to other methods.  It is, however,
 * polynomial in log(N), and log-log performance graphs show nice straight
 * lines for both implementations.  However APR-CL and ECPP both start out
 * much faster and the slope will be less for any sizes of N that we're
 * interested in.
 *
 * For native 64-bit integers this is purely a coding exercise, as BPSW is
 * a million times faster and gives proven results.
 *
 *
 * When n < 2^(wordbits/2)-1, we can do a straightforward intermediate:
 *      r = (r + a * b) % n
 * If n is larger, then these are replaced with:
 *      r = addmod( r, mulmod(a, b, n), n)
 * which is a lot more work, but keeps us correct.
 *
 * Software that does polynomial convolutions followed by a modulo can be
 * very fast, but will fail when n >= (2^wordbits)/r.
 *
 * This is all much easier in GMP.
 *
 * Copyright 2012-2016, Dana Jacobsen.
 */

#define SQRTN_SHORTCUT 1

#define IMPL_V6        0    /* From the primality_v6 paper */
#define IMPL_BORNEMANN 0    /* From Bornemann's 2002 implementation */
#define IMPL_BERN41    1    /* From Bernstein's early 2003 paper */

#include "ptypes.h"
#include "aks.h"
#define FUNC_isqrt 1
#define FUNC_gcd_ui 1
#include "util.h"
#include "cache.h"
#include "mulmod.h"
#include "factor.h"

#if IMPL_BORNEMANN || IMPL_BERN41
/* We could use lgamma, but it isn't in MSVC and not in pre-C99.  The only
 * sure way to find if it is available is test compilation (ala autoconf).
 * Instead, we'll just use our own implementation.
 * See http://mrob.com/pub/ries/lanczos-gamma.html for alternates. */
static double log_gamma(double x)
{
  static const double log_sqrt_two_pi =  0.91893853320467274178;
  static const double lanczos_coef[8+1] =
    { 0.99999999999980993, 676.5203681218851, -1259.1392167224028,
      771.32342877765313, -176.61502916214059, 12.507343278686905,
      -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7 };
  double base = x + 7.5, sum = 0;
  int i;
  for (i = 8; i >= 1; i--)
    sum += lanczos_coef[i] / (x + (double)i);
  sum += lanczos_coef[0];
  sum = log_sqrt_two_pi + log(sum/x) + ( (x+0.5)*log(base) - base );
  return sum;
}

/* Note: For lgammal we need logl in the above.
 * Max error drops from 2.688466e-09 to 1.818989e-12. */
#undef lgamma
#define lgamma(x) log_gamma(x)
#endif

#if IMPL_BERN41
static double log_binomial(UV n, UV k)
{
  return log_gamma(n+1) - log_gamma(k+1) - log_gamma(n-k+1);
}
static double log_bern41_binomial(UV r, UV d, UV i, UV j, UV s)
{
  return   log_binomial( 2*s,   i)
         + log_binomial( d,     i)
         + log_binomial( 2*s-i, j)
         + log_binomial( r-2-d, j);
}
static int bern41_acceptable(UV n, UV r, UV s)
{
  double scmp = ceil(sqrt( (r-1)/3.0 )) * log(n);
  UV d = (UV) (0.5 * (r-1));
  UV i = (UV) (0.475 * (r-1));
  UV j = i;
  if (d > r-2)     d = r-2;
  if (i > d)       i = d;
  if (j > (r-2-d)) j = r-2-d;
  return (log_bern41_binomial(r,d,i,j,s) >= scmp);
}
#endif

#if 0
/* Naive znorder.  Works well if limit is small.  Note arguments.  */
static UV order(UV r, UV n, UV limit) {
  UV j;
  UV t = 1;
  for (j = 1; j <= limit; j++) {
    t = mulmod(t, n, r);
    if (t == 1)
      break;
  }
  return j;
}
static void poly_print(UV* poly, UV r)
{
  int i;
  for (i = r-1; i >= 1; i--) {
    if (poly[i] != 0)
      printf("%lux^%d + ", poly[i], i);
  }
  if (poly[0] != 0) printf("%lu", poly[0]);
  printf("\n");
}
#endif

static void poly_mod_mul(UV* px, UV* py, UV* res, UV r, UV mod)
{
  UV degpx, degpy;
  UV i, j, pxi, pyj, rindex;

  /* Determine max degree of px and py */
  for (degpx = r-1; degpx > 0 && !px[degpx]; degpx--) ; /* */
  for (degpy = r-1; degpy > 0 && !py[degpy]; degpy--) ; /* */
  /* We can sum at least j values at once */
  j = (mod >= HALF_WORD) ? 0 : (UV_MAX / ((mod-1)*(mod-1)));

  if (j >= degpx || j >= degpy) {
    /* res will be written completely, so no need to set */
    for (rindex = 0; rindex < r; rindex++) {
      UV sum = 0;
      j = rindex;
      for (i = 0; i <= degpx; i++) {
        if (j <= degpy)
          sum += px[i] * py[j];
        j = (j == 0) ? r-1 : j-1;
      }
      res[rindex] = sum % mod;
    }
  } else {
    memset(res, 0, r * sizeof(UV));  /* Zero result accumulator */
    for (i = 0; i <= degpx; i++) {
      pxi = px[i];
      if (pxi == 0)  continue;
      if (mod < HALF_WORD) {
        for (j = 0; j <= degpy; j++) {
          pyj = py[j];
          rindex = i+j;   if (rindex >= r)  rindex -= r;
          res[rindex] = (res[rindex] + (pxi*pyj) ) % mod;
        }
      } else {
        for (j = 0; j <= degpy; j++) {
          pyj = py[j];
          rindex = i+j;   if (rindex >= r)  rindex -= r;
          res[rindex] = muladdmod(pxi, pyj, res[rindex], mod);
        }
      }
    }
  }
  memcpy(px, res, r * sizeof(UV)); /* put result in px */
}
static void poly_mod_sqr(UV* px, UV* res, UV r, UV mod)
{
  UV c, d, s, sum, rindex, maxpx;
  UV degree = r-1;
  int native_sqr = (mod > isqrt(UV_MAX/(2*r))) ? 0 : 1;

  memset(res, 0, r * sizeof(UV)); /* zero out sums */
  /* Discover index of last non-zero value in px */
  for (s = degree; s > 0; s--)
    if (px[s] != 0)
      break;
  maxpx = s;
  /* 1D convolution */
  for (d = 0; d <= 2*degree; d++) {
    UV *pp1, *pp2, *ppend;
    UV s_beg = (d <= degree) ? 0 : d-degree;
    UV s_end = ((d/2) <= maxpx) ? d/2 : maxpx;
    if (s_end < s_beg) continue;
    sum = 0;
    pp1 = px + s_beg;
    pp2 = px + d - s_beg;
    ppend = px + s_end;
    if (native_sqr) {
      while (pp1 < ppend)
        sum += 2 * *pp1++  *  *pp2--;
      /* Special treatment for last point */
      c = px[s_end];
      sum += (s_end*2 == d)  ?  c*c  :  2*c*px[d-s_end];
      rindex = (d < r) ? d : d-r;  /* d % r */
      res[rindex] = (res[rindex] + sum) % mod;
#if HAVE_UINT128
    } else {
      uint128_t max = ((uint128_t)1 << 127) - 1;
      uint128_t c128, sum128 = 0;

      while (pp1 < ppend) {
        c128 = ((uint128_t)*pp1++)  *  ((uint128_t)*pp2--);
        if (c128 > max) c128 %= mod;
        c128 <<= 1;
        if (c128 > max) c128 %= mod;
        sum128 += c128;
        if (sum128 > max) sum128 %= mod;
      }
      c128 = px[s_end];
      if (s_end*2 == d) {
        c128 *= c128;
      } else {
        c128 *= px[d-s_end];
        if (c128 > max) c128 %= mod;
        c128 <<= 1;
      }
      if (c128 > max) c128 %= mod;
      sum128 += c128;
      if (sum128 > max) sum128 %= mod;
      rindex = (d < r) ? d : d-r;  /* d % r */
      res[rindex] = ((uint128_t)res[rindex] + sum128) % mod;
#else
    } else {
      while (pp1 < ppend) {
        UV p1 = *pp1++;
        UV p2 = *pp2--;
        sum = addmod(sum, mulmod(2, mulmod(p1, p2, mod), mod), mod);
      }
      c = px[s_end];
      if (s_end*2 == d)
        sum = addmod(sum, sqrmod(c, mod), mod);
      else
        sum = addmod(sum, mulmod(2, mulmod(c, px[d-s_end], mod), mod), mod);
      rindex = (d < r) ? d : d-r;  /* d % r */
      res[rindex] = addmod(res[rindex], sum, mod);
#endif
    }
  }
  memcpy(px, res, r * sizeof(UV)); /* put result in px */
}

static UV* poly_mod_pow(UV* pn, UV power, UV r, UV mod)
{
  UV *res, *temp;

  Newz(0, res, r, UV);
  New(0, temp, r, UV);
  res[0] = 1;

  while (power) {
    if (power & 1)  poly_mod_mul(res, pn, temp, r, mod);
    power >>= 1;
    if (power)      poly_mod_sqr(pn, temp, r, mod);
  }
  Safefree(temp);
  return res;
}

static int test_anr(UV a, UV n, UV r)
{
  UV* pn;
  UV* res;
  UV i;
  int retval = 1;

  Newz(0, pn, r, UV);
  if (a >= n) a %= n;
  pn[0] = a;
  pn[1] = 1;
  res = poly_mod_pow(pn, n, r, n);
  res[n % r] = addmod(res[n % r], n - 1, n);
  res[0]     = addmod(res[0],     n - a, n);

  for (i = 0; i < r; i++)
    if (res[i] != 0)
      retval = 0;
  Safefree(res);
  Safefree(pn);
  return retval;
}

/*
 * Avanzi and Mihǎilescu, 2007
 * http://www.uni-math.gwdg.de/preda/mihailescu-papers/ouraks3.pdf
 * "As a consequence, one cannot expect the present variants of AKS to
 *  compete with the earlier primality proving methods like ECPP and
 *  cyclotomy." - conclusion regarding memory consumption
 */
bool is_aks_prime(UV n)
{
  UV r, s, a, starta = 1;

  if (n < 2)
    return 0;
  if (n == 2)
    return 1;

  if (powerof(n) > 1)
    return 0;

  if (n > 11 && ( !(n%2) || !(n%3) || !(n%5) || !(n%7) || !(n%11) )) return 0;
  /* if (!is_prob_prime(n)) return 0; */

#if IMPL_V6
  {
    UV sqrtn = isqrt(n);
    double log2n = log(n) / log(2);   /* C99 has a log2() function */
    UV limit = (UV) floor(log2n * log2n);

    MPUverbose(1, "# aks limit is %lu\n", (unsigned long) limit);

    for (r = 2; r < n; r++) {
      if ((n % r) == 0)
        return 0;
#if SQRTN_SHORTCUT
      if (r > sqrtn)
        return 1;
#endif
      if (znorder(n, r) > limit)
        break;
    }

    if (r >= n)
      return 1;

    s = (UV) floor(sqrt(r-1) * log2n);
  }
#endif
#if IMPL_BORNEMANN
  {
    UV fac[MPU_MAX_FACTORS+1];
    UV slim;
    double c1, c2, x;
    double const t = 48;
    double const t1 = (1.0/((t+1)*log(t+1)-t*log(t)));
    double const dlogn = log(n);
    r = next_prime( (UV) (t1*t1 * dlogn*dlogn) );
    while (!is_primitive_root(n,r,1))
      r = next_prime(r);

    slim = (UV) (2*t*(r-1));
    c1 = lgamma(r-1);
    c2 = dlogn * floor(sqrt(r));
    { /* Binary search for first s in [1,slim] where x >= 0 */
      UV i = 1;
      UV j = slim;
      while (i < j) {
        s = i + (j-i)/2;
        x = (lgamma(r-1+s) - c1 - lgamma(s+1)) / c2 - 1.0;
        if (x < 0)  i = s+1;
        else        j = s;
      }
      s = i-1;
    }
    s = (s+3) >> 1;
    /* Bornemann checks factors up to (s-1)^2, we check to max(r,s) */
    /* slim = (s-1)*(s-1); */
    slim = (r > s) ? r : s;
    MPUverbose(2, "# aks trial to %lu\n", slim);
    if (trial_factor(n, fac, 2, slim) > 1)
      return 0;
    if (slim >= HALF_WORD || (slim*slim) >= n)
      return 1;
  }
#endif
#if IMPL_BERN41
  {
    UV slim, fac[MPU_MAX_FACTORS+1];
    double const log2n = log(n) / log(2);
    /* Tuning: Initial 'r' selection.  Search limit for 's'. */
    double const r0 = ((log2n > 32) ? 0.010 : 0.003) * log2n * log2n;
    UV const rmult  =  (log2n > 32) ? 6    : 30;

    r = next_prime(r0 < 2 ? 2 : (UV)r0);  /* r must be at least 3 */
    while ( !is_primitive_root(n,r,1) || !bern41_acceptable(n,r,rmult*(r-1)) )
      r = next_prime(r);

    { /* Binary search for first s in [1,slim] where conditions met */
      UV bi = 1;
      UV bj = rmult * (r-1);
      while (bi < bj) {
        s = bi + (bj-bi)/2;
        if (!bern41_acceptable(n, r, s))  bi = s+1;
        else                              bj = s;
      }
      s = bj;
      if (!bern41_acceptable(n, r, s)) croak("AKS: bad s selected");
      /* S goes from 2 to s+1 */
      starta = 2;
      s = s+1;
    }
    /* Check divisibility to s * (s-1) to cover both gcd conditions */
    slim = s * (s-1);
    MPUverbose(2, "# aks trial to %lu\n", (unsigned long)slim);
    if (trial_factor(n, fac, 2, slim) > 1)
      return 0;
    if (slim >= HALF_WORD || (slim*slim) >= n)
      return 1;
    /* Check b^(n-1) = 1 mod n for b in [2..s] */
    for (a = 2; a <= s; a++) {
      if (powmod(a, n-1, n) != 1)
        return 0;
    }
  }
#endif

  MPUverbose(1, "# aks r = %lu  s = %lu\n", (unsigned long) r, (unsigned long) s);

  /* Almost every composite will get recognized by the first test.
   * However, we need to run 's' tests to have the result proven for all n
   * based on the theorems we have available at this time. */
  for (a = starta; a <= s; a++) {
    if (! test_anr(a, n, r) )
      return 0;
    MPUverbose(2, ".");
  }
  MPUverbose(2, "\n");
  return 1;
}

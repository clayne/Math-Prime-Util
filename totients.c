#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ptypes.h"
#define FUNC_isqrt 1
#define FUNC_icbrt 1
#define FUNC_ctz 1
#define FUNC_ipow 1
#include "util.h"
#include "totients.h"
#include "sieve.h"
#include "factor.h"
#include "keyval.h"


static UV _totient_fac(uint32_t nfacs, UV* facs) {
  uint32_t i;
  UV totient = 1, lastf = 0;
  /* n=0 is factored as (0) so it correctly returns 0. */
  for (i = 0; i < nfacs; i++) {
    UV f = facs[i];
    if (f == lastf) { totient *= f;               }
    else            { totient *= f-1;  lastf = f; }
  }
  return totient;
}


UV totient(UV n) {
  UV factors[MPU_MAX_FACTORS+1];
  uint32_t nfactors = factor(n, factors);
  return _totient_fac(nfactors, factors);
}


UV* range_totient(UV lo, UV hi) {
  UV i, count = hi-lo+1, *totients;

  if (hi < lo) croak("range_totient error hi %"UVuf" < lo %"UVuf"\n", hi, lo);
  New(0, totients, count, UV);

  if (lo > 0) {  /* With a non-zero start, use our ranged factoring */

    factor_range_context_t fctx;
    fctx = factor_range_init(lo, hi, 0);
    for (i = 0; i < count; i++) {
      uint32_t nfactors = factor_range_next(&fctx);
      totients[i] = _totient_fac(nfactors, fctx.factors);
    }
    factor_range_destroy(&fctx);

  } else {  /* start at zero */

    static const uint8_t small_totients[] = {0,1,1,2,2,4,2,6,4,6,4,10,4,12,6,8};
    uint32_t sqrthi, nprimes, *prime, j;

    if (hi < sizeof small_totients/sizeof *small_totients) {
      for (i = 0; i <= hi; i++)
        totients[i] = small_totients[i];
      return totients;
    }

    if (hi == UV_MAX) {
      totients[--count] = totient(UV_MAX);
      hi--;
    }

    sqrthi = isqrt(hi);
    New(0, prime, max_nprimes(sqrthi), uint32_t);
    nprimes = 0;
    prime[nprimes++] = 2;

    memset(totients, 0, count * sizeof(UV));
    totients[1] = 1;
    totients[2] = 1;

    for (i = 2; i <= hi/2; i++) {
      UV toti = totients[i];
      if (i % 2 == 0) {
        totients[i*2] = toti * 2;
        continue;
      }
      if (toti == 0) {
        totients[i] = toti = i-1;
        if (i <= sqrthi)
          prime[nprimes++] = i;
      }
      totients[i*2] = toti;
      for (j=1; j < nprimes; j++) {
        UV index = i*prime[j];
        if (index > hi) break;
        if (i % prime[j] == 0) {
          totients[index] = toti * prime[j];
          break;
        }
        totients[index] = toti * (prime[j] - 1);
      }
    }
    Safefree(prime);

    /* All totient values have been filled in except the primes.  Mark them. */
    for (i |= 1; i <= hi; i += 2)
      if (totients[i] == 0)
        totients[i] = i-1;

  }

  return totients;
}



/******************************************************************************/


#define HAVE_SUMTOTIENT_128 (BITS_PER_WORD == 64 && HAVE_UINT128)
#define MAX_TOTSUM ( (BITS_PER_WORD == 64) ? UVCONST(7790208950) : 118868 )
/* sumtotient(7790208950) = 2^64 - 1664739356 */
/* sumtotient(7790208951) = 2^64 + 2584983748 */


/* Direct method: split the computation into two loops running over sqrtn.
 *
 * Page 7 of https://www.mimuw.edu.pl/~pan/papers/farey-esa.pdf
 * https://math.stackexchange.com/a/1740370/117584
 */

static UV _sumtotient_direct(UV n) {
  UV finalsum, *sumcache2;
  uint32_t sqrtn, sum, i, j, k, *sumcache1;
  bool flag;

  if (n <= 2)  return n;
  if (n > MAX_TOTSUM)  return 0;

  sqrtn = isqrt(n);
  flag = (n < (UV)sqrtn * ((UV)sqrtn+1));   /* Does n/r == r ? */

  sumcache2 = range_totient(0, sqrtn);

  New(0, sumcache1, sqrtn+1, uint32_t);
  for (sum = 1, i = 2; i <= sqrtn; i++) {
    sum += sumcache2[i];
    sumcache1[i] = sum;
  }
  if (flag)  sumcache2[sqrtn] = sumcache1[sqrtn];

  for (i = sqrtn - flag;  i > 0;  i--) {
    const UV m = n/i;
    const uint32_t s = isqrt(m);
    UV sum = (m+1)/2 * (m|1);      /* m*(m+1)/2; */
    sum -= (m - m/2);              /* k=1 */

    for (k = 2, j = k*i; j <= sqrtn; k++) {
      sum -= sumcache2[j];
      sum -= (m/k - m/(k+1)) * sumcache1[k];
      j += i;
    }
    for (; k <= s; k++) {
      sum -= sumcache1[m/k];
      sum -= (m/k - m/(k+1)) * sumcache1[k];
    }
    if (m < (UV)s * ((UV)s+1))
      sum += sumcache1[s];

    sumcache2[i] = sum;
  }
  finalsum = sumcache2[1];
  Safefree(sumcache1);
  Safefree(sumcache2);
  return finalsum;
}


/* Recursive method using a cache.  */

typedef struct {
  UV    hsize;
  UV   *nhash;  /* n value */
  UV   *shash;  /* sum for n */
} sumt_hash_t;
#define _CACHED_SUMT(x) \
  (((x)<csize)  ?  cdata[x]  :  _sumt((x), cdata, csize, thash))
static UV _sumt(UV n, const UV *cdata, UV csize, sumt_hash_t thash) {
  UV sum, s, k, lim, hn = n % thash.hsize;

  if (n < csize) return cdata[n];
  if (thash.nhash[hn] == n)  return thash.shash[hn];

  sum = (n & 1)  ?  n*((n+1)>>1)  :  (n>>1)*(n+1);
  s = isqrt(n);
  lim = n/(s+1);

  sum -= (n - n/2) * _CACHED_SUMT(1);
  for (k = 2; k <= lim; k++) {
    sum -= _CACHED_SUMT(n/k);
    sum -= ((n/k) - (n/(k+1))) * _CACHED_SUMT(k);
  }
  if (s > lim)
    sum -= ((n/s) - (n/(s+1))) * _CACHED_SUMT(s);

  if (thash.nhash[hn] == 0 || thash.nhash[hn] > n) {
    thash.nhash[hn] = n;
    thash.shash[hn] = sum;
  }
  return sum;
}

UV sumtotient(UV n) {
  UV sum, i, csize, *sumcache;
  sumt_hash_t thash;

  if (n <= 2)  return n;
  if (n > MAX_TOTSUM)  return 0;

  if (n < 3500) return _sumtotient_direct(n);

  csize = icbrt(n) * icbrt(n);

  sumcache = range_totient(0, csize-1);
  for (i = 2; i < csize; i++)
    sumcache[i] += sumcache[i-1];

  thash.hsize = next_prime(10 + csize/16);
  Newz(0, thash.nhash, thash.hsize, UV);
  New( 0, thash.shash, thash.hsize, UV);

  sum = _sumt(n, sumcache, csize, thash);
  Safefree(thash.nhash);
  Safefree(thash.shash);
  Safefree(sumcache);
  return sum;
}



#if HAVE_SUMTOTIENT_128
#define _CACHED_SUMT128(x) \
  (((x)<csize)  ?  (uint128_t)cdata[x]  :  _sumt128((x), cdata, csize, thash))
typedef struct {
  UV         hsize;
  UV        *nhash;  /* n value */
  uint128_t *shash;  /* sum for n */
} sumt_hash_128_t;
static uint128_t _sumt128(UV n, const UV *cdata, UV csize, sumt_hash_128_t thash) {
  uint128_t sum;
  UV s, k, lim, hn = n % thash.hsize;

  if (n < csize) return cdata[n];
  if (thash.nhash[hn] == n)  return thash.shash[hn];

  sum = (n & 1)  ?  (uint128_t)n * ((n+1)>>1)  :  (uint128_t)(n+1) * (n>>1);
  s = isqrt(n);
  lim = n/(s+1);
  sum -= (n - n/2);
  for (k = 2; k <= lim; k++) {
    sum -= _CACHED_SUMT128(n/k);
    sum -= ((n/k) - (n/(k+1))) * _CACHED_SUMT128(k);
  }
  if (s > lim)
    sum -= ((n/s) - (n/(s+1))) * _CACHED_SUMT128(s);

  thash.nhash[hn] = n;
  thash.shash[hn] = sum;

  return sum;
}

int sumtotient128(UV n, UV *hi_sum, UV *lo_sum) {
  UV i, cbrtn, csize, *sumcache;
  uint128_t sum;
  sumt_hash_128_t thash;

  if (n <= 2)  { *hi_sum = 0;  *lo_sum = n; return 1; }

  cbrtn = icbrt(n);
  csize = 1 * cbrtn * cbrtn;
  if (csize > 400000000U)  csize = 400000000;  /* Limit to 3GB */

  sumcache = range_totient(0, csize-1);
  for (i = 2; i < csize; i++)
    sumcache[i] += sumcache[i-1];

#if 0
  thash.hsize = (n <= UVCONST( 10000000000000))  ?    500009
              : (n <= UVCONST(100000000000000))  ?   8000009
                                                 :  24000001;
#else
  thash.hsize = next_prime(10 + (cbrtn * cbrtn)/128);
  /* if (thash.hsize > 290000000U) thash.hsize=290000000U; */ /* Limit to 7GB */
#endif
  /* printf("hsize %lu  csize %lu  sumcache[%lu] = %lu\n", thash.hsize, csize, csize-1, sumcache[csize-1]); */
  Newz(0, thash.nhash, thash.hsize, UV);
  New( 0, thash.shash, thash.hsize, uint128_t);

  sum = _sumt128(n, sumcache, csize, thash);
  *hi_sum = (sum >> 64) & UV_MAX;
  *lo_sum = (sum      ) & UV_MAX;
  Safefree(thash.nhash);
  Safefree(thash.shash);
  Safefree(sumcache);
  return 1;
}
#else
int sumtotient128(UV n, UV *hi_sum, UV *lo_sum) {
  return 0;
}
#endif


/******************************************************************************/
/******************************************************************************/


static const UV jordan_overflow[5] =
#if BITS_PER_WORD == 64
  {UVCONST(4294967311), 2642249, 65537, 7133, 1627};
#else
  {UVCONST(     65537),    1627,   257,   85,   41};
#endif
UV jordan_totient(UV k, UV n) {
  UV factors[MPU_MAX_FACTORS+1];
  int nfac, i;
  UV totient;
  if (k == 0 || n <= 1) return (n == 1);
  if (k > 6 || (k > 1 && n >= jordan_overflow[k-2])) return 0;

  totient = 1;
  /* Similar to Euler totient, shortcut even inputs */
  while ((n & 0x3) == 0) { n >>= 1; totient *= (1<<k); }
  if ((n & 0x1) == 0) { n >>= 1; totient *= ((1<<k)-1); }
  nfac = factor(n,factors);
  for (i = 0; i < nfac; i++) {
    UV p = factors[i];
    UV pk = ipow(p,k);
    totient *= (pk-1);
    while (i+1 < nfac && p == factors[i+1]) {
      i++;
      totient *= pk;
    }
  }
  return totient;
}


/******************************************************************************/


static bool _totpred(UV n, UV maxd) {
  UV i, ndivisors, *divs;
  bool res;

  if (n & 1) return 0;
  if ((n & (n-1)) == 0) return 1;
  n >>= 1;
  if (n == 1) return 1;
  if (n < maxd && is_prime(2*n+1)) return 1;

  divs = divisor_list(n, &ndivisors, maxd);
  for (i = 0, res = 0; i < ndivisors && divs[i] < maxd && res == 0; i++) {
    UV r, d = divs[i], p = 2*d+1;
    if (!is_prime(p)) continue;
    r = n/d;
    while (1) {
      if (r == p || _totpred(r, d)) { res = 1; break; }
      if (r % p) break;
      r /= p;
    }
  }
  Safefree(divs);
  return res;
}

bool is_totient(UV n) {
  return (n == 0 || (n & 1))  ?  (n==1)  :  _totpred(n,n);
}


/******************************************************************************/


UV inverse_totient_count(UV n) {
  set_t set, sumset;
  keyval_t keyval;
  UV res, i, ndivisors, *divs;

  if (n == 1) return 2;
  if (n < 1 || n & 1) return 0;
  if (is_prime(n >> 1)) { /* Coleman Remark 3.3 (Thm 3.1) and Prop 6.2 */
    if (!is_prime(n+1)) return 0;
    if (n >= 10)        return 2;
  }

  divs = divisor_list(n, &ndivisors, n);

  init_set(&set, 2*ndivisors);
  keyval.key = 1;  keyval.val = 1;
  set_addsum(&set, keyval);

  for (i = 0; i < ndivisors; i++) {
    UV d = divs[i],  p = d+1;
    if (is_prime(p)) {
      UV j,  np = d,  v = valuation(n, p);
      init_set(&sumset, ndivisors/2);
      for (j = 0; j <= v; j++) {
        UV k, ndiv = n/np;  /* Loop over divisors of n/np */
        if (np == 1) {
          keyval_t kv;  kv.key = 1; kv.val = 1;
          set_addsum(&sumset, kv);
        } else {
          for (k = 0; k < ndivisors && divs[k] <= ndiv; k++) {
            UV val, d2 = divs[k];
            if ((ndiv % d2) != 0) continue;
            val = set_getval(set, d2);
            if (val > 0) {
              keyval_t kv;  kv.key = d2*np; kv.val = val;
              set_addsum(&sumset, kv);
            }
          }
        }
        /* if (j < v && np > UV_MAX/p) croak("overflow np  d %lu", d); */
        np *= p;
      }
      set_merge(&set, sumset);
      free_set(&sumset);
    }
  }
  Safefree(divs);
  res = set_getval(set, n);
  free_set(&set);
  return res;
}

UV* inverse_totient_list(UV *ntotients, UV n) {
  set_list_t setlist, divlist;
  UV i, ndivisors, *divs, *tlist;
  UV *totlist = 0;

  MPUassert(n <= UV_MAX/7.5, "inverse_totient_list n too large");

  if (n == 1) {
    New(0, totlist, 2, UV);
    totlist[0] = 1;  totlist[1] = 2;
    *ntotients = 2;
    return totlist;
  }
  if (n < 1 || n & 1) {
    *ntotients = 0;
    return totlist;
  }
  if (is_prime(n >> 1)) { /* Coleman Remark 3.3 (Thm 3.1) and Prop 6.2 */
    if (!is_prime(n+1)) {
      *ntotients = 0;
      return totlist;
    }
    if (n >= 10) {
      New(0, totlist, 2, UV);
      totlist[0] = n+1;  totlist[1] = 2*n+2;
      *ntotients = 2;
      return totlist;
    }
  }

  divs = divisor_list(n, &ndivisors, n);

  init_setlist(&setlist, 2*ndivisors);
  setlist_addval(&setlist, 1, 1);   /* Add 1 => [1] */

  for (i = 0; i < ndivisors; i++) {
    UV d = divs[i],  p = d+1;
    if (is_prime(p)) {
      UV j,  dp = d,  pp = p,  v = valuation(n, p);
      init_setlist(&divlist, ndivisors/2);
      for (j = 0; j <= v; j++) {
        UV k, ndiv = n/dp;  /* Loop over divisors of n/dp */
        if (dp == 1) {
          setlist_addval(&divlist, 1, 2);   /* Add 1 => [2] */
        } else {
          for (k = 0; k < ndivisors && divs[k] <= ndiv; k++) {
            UV nvals, *vals, d2 = divs[k];
            if ((ndiv % d2) != 0) continue;
            vals = setlist_getlist(&nvals, setlist, d2);
            if (vals != 0)
              setlist_addlist(&divlist, d2 * dp, nvals, vals, pp);
          }
        }
        dp *= p;
        pp *= p;
      }
      setlist_merge(&setlist, divlist);
      free_setlist(&divlist);
    }
  }
  Safefree(divs);
  tlist = setlist_getlist(ntotients, setlist, n);
  if (tlist != 0 && *ntotients > 0) {
    New(0, totlist, *ntotients, UV);
    memcpy(totlist, tlist, *ntotients * sizeof(UV));
    sort_uv_array(totlist, *ntotients);
  }
  free_setlist(&setlist);
  return totlist;
}

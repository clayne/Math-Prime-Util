#ifndef MPU_UTIL_H
#define MPU_UTIL_H

#include "ptypes.h"

extern int  _XS_get_verbose(void);
extern void _XS_set_verbose(int v);
extern int  _XS_get_callgmp(void);
extern void _XS_set_callgmp(int v);
/* Disable all manual seeding */
extern bool  _XS_get_secure(void);
extern void _XS_set_secure(void);

extern unsigned long index_in_sorted_uv_array(UV v, UV* L, unsigned long len);
extern unsigned long index_in_sorted_iv_array(IV v, IV* L, unsigned long len);
#define is_in_sorted_uv_array(v,L,len) (index_in_sorted_uv_array(v,L,len) > 0)
#define is_in_sorted_iv_array(v,L,len) (index_in_sorted_iv_array(v,L,len) > 0)

extern bool do_arrays_intersect_uv(const UV* A, size_t alen, const UV* B, size_t blen);
extern bool do_arrays_intersect_iv(const IV* A, size_t alen, const IV* B, size_t blen);

extern bool is_prime(UV x);
extern UV   next_prime(UV x);
extern UV   prev_prime(UV x);

/* Simple estimate for upper limit:  max_nprimes(n) >= prime_count(n) */
extern UV   max_nprimes(UV n) ISCONSTFUNC;

extern void print_primes(UV low, UV high, int fd);

/* Returns maximal k for c^k = n for k > 1, n > 1.  0 otherwise. */
extern uint32_t powerof_ret(UV n, uint32_t *root);
#define powerof(n) powerof_ret(n,0)

/* Return true if n = r^k for the given k, sets root if given */
extern bool is_power_ret(UV n, uint32_t k, uint32_t *root);
#define is_power(n,k) is_power_ret(n,k,0)

extern uint32_t icbrt(UV n) ISCONSTFUNC;
extern UV rootint(UV n, uint32_t k) ISCONSTFUNC;
extern UV ipowsafe(UV n, UV k) ISCONSTFUNC;  /* returns UV_MAX if overflows */
extern UV lcmsafe(UV x, UV u) ISCONSTFUNC;   /* returns 0 if overflows */
extern UV valuation(UV n, UV k) ISCONSTFUNC;
extern UV valuation_remainder(UV n, UV k, UV *r);
extern UV logint(UV n, UV b) ISCONSTFUNC;
extern UV mpu_popcount_string(const char* ptr, uint32_t len);

extern unsigned char* range_issquarefree(UV lo, UV hi);

extern UV powersum(UV n, UV k) ISCONSTFUNC;

extern signed char* range_moebius(UV low, UV high);
extern signed char* range_liouville(UV low, UV high);

extern int liouville(UV n);
extern IV  mertens(UV n);
extern IV  sumliouville(UV n);

extern int kronecker_uu(UV a, UV b) ISCONSTFUNC;
extern int kronecker_su(IV a, UV b) ISCONSTFUNC;
extern int kronecker_ss(IV a, IV b) ISCONSTFUNC;

extern UV pn_primorial(UV n) ISCONSTFUNC;
extern UV primorial(UV n) ISCONSTFUNC;
extern UV factorial(UV n) ISCONSTFUNC;
extern UV subfactorial(UV n) ISCONSTFUNC;
extern UV fubini(UV n) ISCONSTFUNC;
extern UV binomial(UV n, UV k) ISCONSTFUNC;
extern UV falling_factorial(UV n, UV m) ISCONSTFUNC;
extern UV rising_factorial(UV n, UV m) ISCONSTFUNC;
extern IV falling_factorial_s(IV n, UV m) ISCONSTFUNC;
extern IV rising_factorial_s(IV n, UV m) ISCONSTFUNC;
extern IV gcdext(IV a, IV b, IV* u, IV* v, IV* s, IV* t); /* Ext Euclidean */
extern UV modinverse(UV a, UV p) ISCONSTFUNC;  /* Returns 1/a mod p */
extern UV divmod(UV a, UV b, UV n) ISCONSTFUNC;/* Returns a/b mod n */
extern UV gcddivmod(UV a, UV b, UV n) ISCONSTFUNC; /* divmod(a/gcd,b/gcd,n) */

extern UV pisano_period(UV n);

/* 0 overflow, -1 no inverse, 1 ok */
/* The a/n arrays will be sorted by descending n. */
extern int chinese(UV *r, UV *lcm, UV* a, UV* n, UV num);/* Chinese Remainder */

/* Do the inverse for a negative modular power / root. a^-k => (1/a)^k mod n */
extern bool prep_pow_inv(UV *a, UV *k, int kstatus, UV n);

/* Signed division and remainder.  Returns remainder.*/
extern IV tdivrem(IV *q, IV *r, IV D, IV d);   /* divrem trunc */
extern IV fdivrem(IV *q, IV *r, IV D, IV d);   /* divrem floor */
extern IV cdivrem(IV *q, IV *r, IV D, IV d);   /* divrem ceiling */
extern IV edivrem(IV *q, IV *r, IV D, IV d);   /* divrem Euclidian */
extern UV ivmod(IV a, UV n) ISCONSTFUNC;       /* Returns a mod n (trunc) */

extern UV   carmichael_lambda(UV n);
extern int  moebius(UV n);
extern UV   exp_mangoldt(UV n);
extern UV   znprimroot(UV n);
extern UV   znorder(UV a, UV n);
/* nprime says to assume n = p or n = 2p.  Skips power and primality tests. */
extern bool is_primitive_root(UV a, UV n, bool nprime);
extern UV   factorialmod(UV n, UV m);
extern bool binomialmod(UV *res, UV n, UV k, UV m);

extern bool is_square_free(UV n);
extern bool is_perfect_number(UV n);
extern bool is_fundamental(UV n, bool neg);
extern bool is_semiprime(UV n);
extern bool is_almost_prime(UV k, UV n);
extern bool is_cyclic(UV n);
extern bool is_carmichael(UV n);
extern UV   is_quasi_carmichael(UV n);  /* Returns number of bases */
extern UV   pillai_v(UV n) ISCONSTFUNC; /* v: v! % n == n-1 && n % v != 1 */
extern UV   qnr(UV n);
extern bool is_qr(UV a, UV n);         /* kronecker that works for composites */
extern bool is_practical(UV n);
extern int  is_delicate_prime(UV n, uint32_t b);
extern int  happy_height(UV n, uint32_t base, uint32_t exponent) ISCONSTFUNC;

extern bool is_smooth(UV n, UV k);
extern bool is_rough(UV n, UV k);

extern bool is_sum_of_two_squares(UV n);
extern bool is_sum_of_three_squares(UV n);
extern bool cornacchia(UV *x, UV *y, UV d, UV p);

extern UV debruijn_psi(UV x, UV y);
extern UV buchstab_phi(UV x, UV y);

extern UV stirling3(UV n, UV m) ISCONSTFUNC;
extern IV stirling2(UV n, UV m) ISCONSTFUNC;
extern IV stirling1(UV n, UV m) ISCONSTFUNC;

extern IV hclassno(UV n);
extern IV ramanujan_tau(UV n);

extern char* pidigits(uint32_t digits);

/* min defines if min or max.  Return of 0 means select a, 1 means select b. */
extern bool strnum_minmax(bool min, const char* a, STRLEN alen, const char* b, STRLEN blen);
extern int strnum_cmp(const char* a, STRLEN alen, const char* b, STRLEN blen);

extern bool from_digit_string(UV* n, const char* s, int base);
extern bool from_digit_to_UV(UV* rn, const UV* r, int len, int base);
extern bool from_digit_to_str(char** rstr, const UV* r, int len, int base);
/* These return length */
extern int  to_digit_array(int* bits, UV n, int base, int length);
extern int  to_digit_string(char *s, UV n, int base, int length);
extern int  to_string_128(char s[40], IV hi, UV lo);

/* Returns 1 if good, 0 if bad, -1 if non canon, 2 ok but out of range */
extern int validate_zeckendorf(const char* str);
extern UV  from_zeckendorf(const char* str);
extern char* to_zeckendorf(UV n);

extern bool is_catalan_pseudoprime(UV n);

extern UV  polygonal_root(UV n, UV k, bool* overflow);

extern UV  npartitions(UV n);
extern UV  consecutive_integer_lcm(UV n);

extern UV  frobenius_number(UV* A, uint32_t alen);

extern bool num_to_perm(UV rank, int n, int *vec);
extern bool perm_to_num(int n, int *vec, UV *rank);
extern void randperm(void* ctx, UV n, UV k, UV *S);

extern UV random_factored_integer(void* ctx, UV n, int *nf, UV *factors);

extern UV gcdz(UV x, UV y) ISCONSTFUNC;


/* Inputs are assumed to be UNSIGNED */
/* These could use a static table if that turned out better */

#define is_divis_2_3(n)     ( (n)%2 == 0 || (n) % 3 == 0 )

#if defined(__arm64__)
#define is_divis_2_3_5(n)   ( (n)%2 == 0 || (0x1669>>((n)%15))&1 )
#else
#define is_divis_2_3_5(n)   ( (n)%2 == 0 || (n) % 3 == 0 || (n) % 5 == 0 )
#endif
/* 2,3,5 could use the single test:  (0x1f75d77d >> (n % 30)) & 1  */

#define is_divis_2_3_5_7(n) ( is_divis_2_3_5(n) || (n) % 7 == 0 )


/******************************************************************************/

#if defined(FUNC_is_perfect_square) && !defined(FUNC_isqrt)
  #define FUNC_isqrt 1
#endif
#if defined(FUNC_lcm_ui) && !defined(FUNC_gcd_ui)
  #define FUNC_gcd_ui 1
#endif

/******************************************************************************/

/* I think uint32_t is a better return type, but we follow GCC's prototype. */

#if defined(FUNC_clz) || defined(FUNC_ctz) || defined(FUNC_log2floor)
/* log2floor(n) gives the location of the first set bit (starting from left)
 * ctz(n)       gives the number of times n is divisible by 2
 * clz(n)       gives the number of zeros on the left                       */
#if defined(__GNUC__) && 100*__GNUC__ + __GNUC_MINOR >= 304
 #if BITS_PER_WORD == 64
  #define ctz(n)        ((n) ?    __builtin_ctzll(n) : 64)
  #define clz(n)        ((n) ?    __builtin_clzll(n) : 64)
  #define log2floor(n)  ((n) ? 63-__builtin_clzll(n) : 0)
 #else
  #define ctz(n)        ((n) ?    __builtin_ctzl(n) : 32)
  #define clz(n)        ((n) ?    __builtin_clzl(n) : 32)
  #define log2floor(n)  ((n) ? 31-__builtin_clzl(n) : 0)
 #endif

 /* For MSC, we need to use _BitScanForward and _BitScanReverse.  The way to
  * get to them has changed, so we're going to only use them on new systems.
  * The performance of these functions are not super critical.
  * What is:  popcnt, mulmod, and muladd.
  */
#elif defined (_MSC_VER) && _MSC_VER >= 1400 && !defined(__clang__) && !defined(_WIN32_WCE)
 #include <intrin.h>
 #ifdef FUNC_ctz
  static int ctz(UV n) {
    UV tz = 0;
   #if BITS_PER_WORD == 64
    if (_BitScanForward64(&tz, n)) return tz; else return 64;
   #else
    if (_BitScanForward(&tz, n))   return tz; else return 32;
   #endif
  }
 #endif
 #if defined(FUNC_clz) || defined(FUNC_log2floor)
  static int log2floor(UV n) {
    UV lz = 0;
   #if BITS_PER_WORD == 64
    if (_BitScanReverse64(&lz, n)) return lz; else return 0;
   #else
    if (_BitScanReverse(&lz, n))   return lz; else return 0;
   #endif
  }
 #endif
#elif BITS_PER_WORD == 64
 static const unsigned char _debruijn64[64] = {
     63, 0,58, 1,59,47,53, 2, 60,39,48,27,54,33,42, 3, 61,51,37,40,49,18,28,20,
     55,30,34,11,43,14,22, 4, 62,57,46,52,38,26,32,41, 50,36,17,19,29,10,13,21,
     56,45,25,31,35,16, 9,12, 44,24,15, 8,23, 7, 6, 5 };
 #ifdef FUNC_ctz
   static int ctz(UV n) {
     return n ? _debruijn64[((n & -n)*UVCONST(0x07EDD5E59A4E28C2)) >> 58] : 64;
   }
 #endif
 #if defined(FUNC_clz) || defined(FUNC_log2floor)
   static int log2floor(UV n) {
     if (n == 0) return 0;
     n |= n >> 1;   n |= n >> 2;   n |= n >> 4;
     n |= n >> 8;   n |= n >> 16;  n |= n >> 32;
     return _debruijn64[((n-(n>>1))*UVCONST(0x07EDD5E59A4E28C2)) >> 58];
   }
 #endif
#else
 #ifdef FUNC_ctz
   static const unsigned char _trail_debruijn32[32] = {
      0, 1,28, 2,29,14,24, 3,30,22,20,15,25,17, 4, 8,
     31,27,13,23,21,19,16, 7,26,12,18, 6,11, 5,10, 9 };
   static int ctz(UV n) {
     return n ? _trail_debruijn32[((n & -n) * UVCONST(0x077CB531)) >> 27] : 32;
   }
 #endif
 #if defined(FUNC_clz) || defined(FUNC_log2floor)
   static const unsigned char _lead_debruijn32[32] = {
      0, 9, 1, 10, 13, 21, 2, 29, 11, 14, 16, 18, 22, 25, 3, 30,
      8, 12, 20, 28, 15, 17, 24, 7, 19, 27, 23, 6, 26, 5, 4, 31 };
   static int log2floor(UV n) {
     if (n == 0) return 0;
     n |= n >> 1;   n |= n >> 2;   n |= n >> 4;   n |= n >> 8;   n |= n >> 16;
     return _lead_debruijn32[(n * UVCONST(0x07C4ACDD)) >> 27];
   }
 #endif
#endif
#if defined(FUNC_clz) && !defined(clz)
 #define clz(n)  ( (n) ? BITS_PER_WORD-1-log2floor(n) : BITS_PER_WORD )
#endif
#endif  /* End of log2floor, clz, and ctz */

#ifdef FUNC_popcnt
/* GCC 3.4 - 4.1 has broken 64-bit popcount.
 * GCC 4.2+ can generate awful code when it doesn't have asm (GCC bug 36041).
 * When the asm is present (e.g. compile with -march=native on a platform that
 * has them, like Nahelem+), then it is almost as fast as manually written asm. */
#if BITS_PER_WORD == 64
 #if defined(__POPCNT__) && defined(__GNUC__) && 100*__GNUC__ + __GNUC_MINOR >= 402
   #define popcnt(b)  __builtin_popcountll(b)
 #else
   static int popcnt(UV b) {
     b -= (b >> 1) & 0x5555555555555555;
     b = (b & 0x3333333333333333) + ((b >> 2) & 0x3333333333333333);
     b = (b + (b >> 4)) & 0x0f0f0f0f0f0f0f0f;
     return (b * 0x0101010101010101) >> 56;
   }
 #endif
#else
 static int popcnt(UV b) {
   b -= (b >> 1) & 0x55555555;
   b = (b & 0x33333333) + ((b >> 2) & 0x33333333);
   b = (b + (b >> 4)) & 0x0f0f0f0f;
   return (b * 0x01010101) >> 24;
 }
#endif
#endif


/******************************************************************************/


#if defined(FUNC_ipow)
static UV ipow(UV n, UV k) {
  UV p = 1;
  while (k) {
    if (k & 1) p *= n;
    k >>= 1;
    if (k)     n *= n;
  }
  return p;
}
#endif


#if defined(FUNC_gcd_ui)
/* If we have a very fast ctz, then use the fast FLINT version of gcd */
#if defined(__GNUC__) && 100*__GNUC__ + __GNUC_MINOR >= 304
#define gcd_ui(x,y) gcdz(x,y)
#else
static UV gcd_ui(UV x, UV y) {
  UV t;
  if (y > x) { t = x; x = y; y = t; }
  while (y > 0) {
    t = y;  y = x % y;  x = t;  /* y1 <- x0 % y0 ; x1 <- y0 */
  }
  return x;
}
#endif
#endif

#ifdef FUNC_lcm_ui
static UV lcm_ui(UV x, UV y) {
  /* Can overflow if lcm(x,y) > 2^64 (e.g. two primes each > 2^32) */
  return x * (y / gcd_ui(x,y));
}
#endif


#if defined(FUNC_isqrt)
/* Correct for all 64-bit inputs and all FP rounding modes. */
#include <math.h>
static uint32_t isqrt(UV n) {
  /* The small addition means we only need to check for fixing downwards. */
  IV r = sqrt((double)n) + 1e-6f;
  IV diff = n - (UV)r*r;
  return r - (diff < 0);
}
#endif

#ifdef FUNC_is_perfect_square
static bool is_perfect_square_ret(UV n, uint32_t *root)
{
  uint32_t r;
  /* Fast filters reject 95.0% of non-squares */
#if BITS_PER_WORD == 64
  if ((UVCONST(1) << (n&63)) & UVCONST(0xfdfdfdedfdfcfdec)) return 0;
  /* if ((UVCONST(1) << (n%45)) & UVCONST(0xfffffeeb7df6f9ec)) return 0; */
#else
  /* uint32_t m; */
  if ((1U << (n&31)) & 0xfdfcfdec) return 0;
  /* m = n % 105; if ((m*0xd24554cd) & (m*0x0929579a) & 0x38020141) return 0; */
#endif
  r = isqrt(n);
  if (root != 0) *root = r;
  return ((UV)r*r == n);
}
#define is_perfect_square(n)  is_perfect_square_ret(n,0)
#endif

#endif

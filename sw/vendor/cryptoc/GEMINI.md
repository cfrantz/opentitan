# cryptoc - Embedded Cryptographic Library Reference Guide

This document provides an overview of the stand-alone, endian-neutral, zero-dependency C cryptographic library `cryptoc`. It serves as a guide for understanding the library's layout, APIs, build configuration, and known caveats.

---

## 1. Directory Structure and Map

The library is split between headers in `include/cryptoc/` and implementation source files in the root directory.

| File | Type | Description |
|---|---|---|
| [LICENSE](LICENSE) | Text | Apache License, Version 2.0. |
| [BUILD.bazel](BUILD.bazel) | Build | Bazel build definition file. |
| [MODULE.bazel](MODULE.bazel) | Build | Bazel module configuration file. |
| [README](README) | Text | Short library description. |
| [OWNERS](OWNERS) | Metadata | Authors and maintainers directory. |
| [hmac.c](hmac.c) | Source | HMAC implementation using virtual-table hashing. |
| [p256.c](p256.c) | Source | Large integer arithmetic implementation for curve computations (P-256). |
| [p256_ec.c](p256_ec.c) | Source | Low-level Elliptic Curve group arithmetic for P-256. |
| [p256_ecdsa.c](p256_ecdsa.c) | Source | ECDSA sign and verify implementations (P-256). |
| [p256_prng.c](p256_prng.c) | Source | NIST SP 800-90A-inspired HMAC-DRBG pseudo-random generator. |
| [p384.c](p384.c) | Source | Large integer arithmetic implementation for curve computations (P-384). |
| [p384_ec.c](p384_ec.c) | Source | Low-level Elliptic Curve group arithmetic for P-384. |
| [p384_ecdsa.c](p384_ecdsa.c) | Source | ECDSA sign and verify implementations (P-384). |
| [sha.c](sha.c) | Source | SHA-1 hashing algorithm. |
| [sha256.c](sha256.c) | Source | SHA-256 hashing algorithm. |
| [sha384.c](sha384.c) | Source | SHA-384 hashing algorithm (conditional on compile flag). |
| [sha512.c](sha512.c) | Source | SHA-512 hashing algorithm (conditional on compile flag). |
| [util.c](util.c) | Source | Utilities (e.g. constant-time scrub memory `always_memset`). |
| [include/cryptoc/hash-internal.h](include/cryptoc/hash-internal.h) | Header | Common hashing structure abstraction using virtual tables. |
| [include/cryptoc/hmac.h](include/cryptoc/hmac.h) | Header | Declarations for HMAC contexts and APIs. |
| [include/cryptoc/p256.h](include/cryptoc/p256.h) | Header | Declarations for 256-bit big integers and EC group operations. |
| [include/cryptoc/p256_ecdsa.h](include/cryptoc/p256_ecdsa.h) | Header | Declarations for P-256 ECDSA sign/verify routines. |
| [include/cryptoc/p256_prng.h](include/cryptoc/p256_prng.h) | Header | Declarations for pseudo-random number generator routines. |
| [include/cryptoc/p384.h](include/cryptoc/p384.h) | Header | Declarations for 384-bit big integers and EC group operations. |
| [include/cryptoc/p384_ecdsa.h](include/cryptoc/p384_ecdsa.h) | Header | Declarations for P-384 ECDSA sign/verify routines. |
| [include/cryptoc/sha.h](include/cryptoc/sha.h) | Header | Declarations for SHA-1. |
| [include/cryptoc/sha256.h](include/cryptoc/sha256.h) | Header | Declarations for SHA-256. |
| [include/cryptoc/sha384.h](include/cryptoc/sha384.h) | Header | Declarations for SHA-384. |
| [include/cryptoc/sha512.h](include/cryptoc/sha512.h) | Header | Declarations for SHA-512. |
| [include/cryptoc/util.h](include/cryptoc/util.h) | Header | Declarations for scrub memory utility. |
| [p256_unittest.c](p256_unittest.c) | Test | Unit test suite for `p256` big integer arithmetic. |
| [p256_ecdsa_unittest.c](p256_ecdsa_unittest.c) | Test | Unit test suite for P-256 ECDSA signatures. |
| [p256_prng_unittest.c](p256_prng_unittest.c) | Test | Unit test suite verifying PRNG outputs against test vectors. |
| [p384_unittest.c](p384_unittest.c) | Test | Unit test suite for `p384` big integer arithmetic. |
| [p384_ecdsa_unittest.c](p384_ecdsa_unittest.c) | Test | Unit test suite for P-384 ECDSA signatures. |
| [sha2_testvectors.c](sha2_testvectors.c) | Test | Unit test verifying SHA-256/384/512 against CAVP NIST vectors. |

---

## 2. Core Cryptographic Components

### 2.1 Hashing & HMAC Abstraction
All hashing functions are designed around the virtual-table construct [HASH_VTAB](include/cryptoc/hash-internal.h#L26-L32) and the hashing context [HASH_CTX](include/cryptoc/hash-internal.h#L34-L44).

```c
typedef struct HASH_VTAB {
  void (* const init)(struct HASH_CTX*);
  void (* const update)(struct HASH_CTX*, const void*, size_t);
  const uint8_t* (* const final)(struct HASH_CTX*);
  const uint8_t* (* const hash)(const void*, size_t, uint8_t*);
  unsigned int size;
} HASH_VTAB;
```

This abstraction allows [LITE_HMAC_CTX](include/cryptoc/hmac.h#L24-L27) to wrap any underlying hash algorithm transparently and drive the execution using common virtual-table macros.

- **SHA-1**: Declared in [sha.h](include/cryptoc/sha.h) and implemented in [sha.c](sha.c). Digest size is 20 bytes.
- **SHA-256**: Declared in [sha256.h](include/cryptoc/sha256.h) and implemented in [sha256.c](sha256.c). Digest size is 32 bytes.
- **SHA-384**: Declared in [sha384.h](include/cryptoc/sha384.h) and implemented in [sha384.c](sha384.c). Digest size is 48 bytes. Requires the macro `SHA512_SUPPORT` to be defined.
- **SHA-512**: Declared in [sha512.h](include/cryptoc/sha512.h) and implemented in [sha512.c](sha512.c). Digest size is 64 bytes. Requires the macro `SHA512_SUPPORT` to be defined.

> [!NOTE]
> Unimplemented MD5 and HMAC-MD5 support has been completely removed from the repository.

### 2.2 P-256 and P-384 Big Integer Arithmetic (`p256_int` / `p384_int`)

#### P-256 Representation
Large integers are represented as an array of 8 32-bit digits:
```c
typedef struct {
  p256_digit a[P256_NDIGITS]; // P256_NDIGITS = 8
} p256_int;
```
This is defined in [p256.h](include/cryptoc/p256.h#L40-L46). The curve parameters (such as curve prime $p$ [SECP256r1_p](p256.c#L24) and curve order $n$ [SECP256r1_n](p256.c#L20)) are defined globally in [p256.c](p256.c).

#### P-384 Representation
Large integers are represented as an array of 12 32-bit digits:
```c
typedef struct {
  p384_digit a[P384_NDIGITS]; // P384_NDIGITS = 12
} p384_int;
```
This is defined in [p384.h](include/cryptoc/p384.h). The curve parameters (such as curve prime $p$ [SECP384r1_p](p384.c) and curve order $n$ [SECP384r1_n](p384.c)) are defined globally in [p384.c](p384.c).

Key arithmetic routines (`p256_*` / `p384_*`):
- `add`, `sub`, `cmp`
- `shl`, `shr`
- `modmul` (modular multiplication)
- `modinv` (constant-time modular inversion)
- `modinv_vartime` (variable-time modular inversion)

### 2.3 P-256 and P-384 ECDSA

#### P-256 ECDSA
Located in [p256_ecdsa.c](p256_ecdsa.c).
- [p256_ecdsa_sign](p256_ecdsa.c#L43-L73): Signs a 256-bit message with a private key. It determines the random value $k$ deterministically (using HMAC-SHA-256 key-message hashing in [determine_k](p256_ecdsa.c#L20-L41)) to avoid bad entropy vulnerabilities.
- [p256_ecdsa_verify](p256_ecdsa.c#L75-L98): Verifies an ECDSA signature $\{r,s\}$ against a public key $\{key_x, key_y\}$ on the curve.

#### P-384 ECDSA
Located in [p384_ecdsa.c](p384_ecdsa.c).
- `p384_ecdsa_sign`: Signs a 384-bit message with a private key. It determines the random value $k$ deterministically (using HMAC-SHA-256 key-message hashing in `determine_k` twice to draw 48 bytes) to avoid bad entropy vulnerabilities.
- `p384_ecdsa_verify`: Verifies an ECDSA signature $\{r,s\}$ against a public key $\{key_x, key_y\}$ on the curve.

### 2.4 NIST-inspired PRNG
Located in [p256_prng.c](p256_prng.c).
- Inspired by NIST SP 800-90A HMAC-DRBG.
- Maintains internal state `Key` and `V` of `P256_PRNG_SIZE` (32 bytes).
- Initialized with entropy via [p256_prng_init](p256_prng.c#L63-L74) and mixes additional seed material via [p256_prng_add](p256_prng.c#L55-L61).

---

## 3. Build & Compilation Guide

### 3.1 Bazel Build Setup
This repository is configured as a Bazel repository. You can build the library and run tests using standard Bazel targets.

- **Build all library targets**:
  ```bash
  bazel build //...
  ```
- **Run all unit tests**:
  ```bash
  bazel test //...
  ```

### 3.2 Propagation of compilation defines
To enable SHA-384 and SHA-512, the preprocessing flag `SHA512_SUPPORT` is defined globally via `defines` in the `:cryptoc` library target in [BUILD.bazel](BUILD.bazel). This ensures the define is correctly propagated to all dependent test suites and binaries, preventing struct layout mismatches.

---

## 4. Key Implementation Details & Potential Issues

### 4.1 PRNG Context Buffer Types
The PRNG context [P256_PRNG_CTX](include/cryptoc/p256_prng.h#L36-L41) defines state buffers as:
```c
typedef struct P256_PRNG_CTX {
  uint8_t Key[P256_PRNG_SIZE];  // P256_PRNG_SIZE = 32
  uint8_t V[P256_PRNG_SIZE];
  ...
} P256_PRNG_CTX;
```

> [!NOTE]
> Originally, these buffers were declared as `uint32_t` arrays, which created a mismatch with byte-based length operations (`memset(ctx->Key, 0, P256_PRNG_SIZE)`), causing modern compilers to trigger `-Wmemset-elt-size` errors. This has been resolved by converting the array types to `uint8_t`.

### 4.2 Compiler Dependency: Arithmetic Right Shifts
The big integer arithmetic relies on the system compiler executing an arithmetic (signed-preserving) right shift when shifting a signed negative integer. This assumption is explicitly tested in [p256_unittest.c:L35-L48](p256_unittest.c#L35-L48):
```c
void test_cpu_behavior() {
  int32_t i;
  volatile int32_t val = -1;
  uint32_t one = 1;

  for (i = 0; i < 32; i++) {
    CHECK((val>>i) == (-1));
  }
  ...
}
```
If compile targets an architecture or compiler that performs logical right shifts for signed types, the unit tests will fail and modular operations will break.

### 4.3 Constant-Time vs. Variable-Time Operations
For security-critical private key operations, the code must run in constant time to prevent side-channel timing analysis.
- **Constant-Time**:
  - `p256_modinv` / `p384_modinv`: Run in constant time using modular exponentiation. Note that `p384_modinv` dynamically selects the exponent (`SECP384r1_nMin2` or `SECP384r1_pMin2`) based on the modulus passed to it.
  - `p256_base_point_mul` / `p256_point_mul` / `p384_base_point_mul` / `p384_point_mul`: Perform constant-time EC point multiplication.
- **Variable-Time**:
  - `p256_modinv_vartime` / `p384_modinv_vartime`: Use variable-time Euclidean modular inversion. Much faster but vulnerable to timing side-channels.
  - `p256_points_mul_vartime` / `p384_points_mul_vartime`: Used for public-key verification (`n1*G + n2*PubKey`). Safe since public keys and messages are public.
  > [!WARNING]
  > Never use variable-time modular inversion or point multiplication when working with sensitive private values (such as decryption, private key scalar multiplication, or signature generation).

### 4.4 Avoidance of pointer aliasing in EC additions/doubling
The Elliptic Curve point doubling and addition functions in `p384_ec.c` compute their final coordinates in local temporary variables before assigning them to the output point structure. This avoids corruption due to pointer aliasing in standard operations such as `jacobian_double(&R, &R)`.

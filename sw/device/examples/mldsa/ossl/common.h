#ifndef LOCAL_GOOGLE_HOME_CFRANTZ_SRC_OPENTITAN_EXTERNAL_EXAMPLE_MLDSA_OSSL_COMMON_H_
#define LOCAL_GOOGLE_HOME_CFRANTZ_SRC_OPENTITAN_EXTERNAL_EXAMPLE_MLDSA_OSSL_COMMON_H_

#include <stdlib.h>

#define OQS_API
#define OQS_MEM_malloc malloc
#define OQS_MEM_insecure_free free

/**
 * Represents return values from functions.
 *
 * Callers should compare with the symbol rather than the individual value.
 * For example,
 *
 *     ret = OQS_KEM_encaps(...);
 *     if (ret == OQS_SUCCESS) { ... }
 *
 * rather than
 *
 *     if (!OQS_KEM_encaps(...) { ... }
 *
 */
typedef enum {
        /** Used to indicate that some undefined error occurred. */
        OQS_ERROR = -1,
        /** Used to indicate successful return from function. */
        OQS_SUCCESS = 0,
        /** Used to indicate failures in external libraries (e.g., OpenSSL). */
        OQS_EXTERNAL_LIB_ERROR_OPENSSL = 50,
} OQS_STATUS;


#endif  // LOCAL_GOOGLE_HOME_CFRANTZ_SRC_OPENTITAN_EXTERNAL_EXAMPLE_MLDSA_OSSL_COMMON_H_

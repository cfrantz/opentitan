#define str(s) #s
#define xstr(s) str(s)

#ifndef NAMESPACE
#define NAMESPACE SPX_
#endif
#define PASTE_(a, b) a ## b
#define PASTE(a, b) PASTE_(a, b)

#include xstr(params/params-PARAMS.h)


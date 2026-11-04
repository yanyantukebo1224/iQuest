#ifndef IQUEST_APK_INSPECTOR_H
#define IQUEST_APK_INSPECTOR_H

#include <stddef.h>

// Inspect an APK without executing or extracting guest code. Writes a
// newline-delimited, UTF-8 key=value report into output.
// Returns 0 on success, nonzero on malformed/unsupported APK.
int iquest_apk_inspect(const char *path, char *output, size_t output_capacity,
                       char *error, size_t error_capacity);

#endif

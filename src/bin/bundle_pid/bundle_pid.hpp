#pragma once

/**
 * Find the corresponding PID according to the Bundle ID or process name
 * @param target target identifier (Bundle ID such as “com.apple.Safari”, or process name such as “Safari”)
 * @return found PID, not found return -1
 */
extern "C" {
int bundle_pid(const char *target);
}

#ifdef __cplusplus
namespace a1::bin {
int bundle_pid(const char *target);
} /* namespace a1::bin */
#endif

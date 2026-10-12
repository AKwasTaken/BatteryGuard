//
//  SMC.c
//  BatteryGuardHelper
//
//  Created by Aneeth Kumaar on 12/10/26.
//

#include <IOKit/IOKitLib.h>
#include <string.h>
#include "SMC.h"

static io_connect_t conn = 0;
static uint32_t fourcc(const char *s) { return (s[0]<<24)|(s[1]<<16)|(s[2]<<8)|s[3]; }

static kern_return_t smc_call(SMCKeyData *in, SMCKeyData *out) {
    size_t n = sizeof(*out);
    return IOConnectCallStructMethod(conn, 2 /* kSMCHandleYPCEvent */, in, sizeof(*in), out, &n);
}

int smc_open(void) {
    if (conn) return 0;
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!svc) return -1;
    kern_return_t kr = IOServiceOpen(svc, mach_task_self(), 0, &conn);
    IOObjectRelease(svc);
    return kr == KERN_SUCCESS ? 0 : -1;
}

int smc_write(const char *key, const uint8_t *bytes, uint32_t len) {
    SMCKeyData in = {0}, out = {0};
    in.key = fourcc(key); in.data8 = 9;                  // 9 = get key info
    if (smc_call(&in, &out) != KERN_SUCCESS) return -4;  // call refused (not privileged / gated)
    if (out.result != 0) return -2;                      // key not found
    if (out.keyInfo.dataSize == 0) return -6;            // empty placeholder key
    in.keyInfo = out.keyInfo; in.data8 = 6;              // 6 = write bytes
    memcpy(in.bytes, bytes, len < 32 ? len : 32);
    memset(&out, 0, sizeof(out));
    if (smc_call(&in, &out) != KERN_SUCCESS) return -5;
    return out.result == 0 ? 0 : -3;
}

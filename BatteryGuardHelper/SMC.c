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

int smc_keyinfo(const char *key, uint32_t *size) {
    SMCKeyData in = {0}, out = {0};
    in.key = fourcc(key); in.data8 = 9;                  // 9 = get key info
    if (smc_call(&in, &out) != KERN_SUCCESS) return -4;
    if (out.result != 0) return -2;
    *size = out.keyInfo.dataSize;
    return 0;
}

static int smc_info_and_read(uint32_t key, uint8_t *bytes, uint32_t *size) {
    SMCKeyData in = {0}, out = {0};
    in.key = key; in.data8 = 9;                          // 9 = get key info
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0) return -1;
    *size = out.keyInfo.dataSize;
    if (*size > 32) *size = 32;
    in.keyInfo = out.keyInfo; in.data8 = 5;              // 5 = read bytes
    memset(&out, 0, sizeof(out));
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0) return -2;
    memcpy(bytes, out.bytes, *size);
    return 0;
}

int smc_read_key(uint32_t key, uint8_t *bytes, uint32_t *size) {
    return smc_info_and_read(key, bytes, size);
}

int smc_key_count(uint32_t *count) {
    uint8_t b[32]; uint32_t sz = 0;
    if (smc_info_and_read(fourcc("#KEY"), b, &sz) != 0 || sz < 4) return -1;
    *count = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) | ((uint32_t)b[2] << 8) | b[3];
    return 0;
}

int smc_key_at(uint32_t index, uint32_t *key) {
    SMCKeyData in = {0}, out = {0};
    in.data8 = 8; in.data32 = index;                     // 8 = get key by index
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0) return -1;
    *key = out.key;
    return 0;
}

int smc_read_key_attr(uint32_t key, uint8_t *attr) {
    SMCKeyData in = {0}, out = {0};
    in.key = key; in.data8 = 9;                          // 9 = get key info
    if (smc_call(&in, &out) != KERN_SUCCESS || out.result != 0) return -1;
    *attr = out.keyInfo.dataAttributes;
    return 0;
}

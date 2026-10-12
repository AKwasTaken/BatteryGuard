//
//  SMC.h
//  BatteryGuardHelper
//
//  Created by Aneeth Kumaar on 12/10/26.
//

#include <stdint.h>
typedef struct { char major, minor, build, reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimit;
typedef struct { uint32_t dataSize, dataType; uint8_t dataAttributes; } SMCKeyInfo;
typedef struct {
    uint32_t key; SMCVersion vers; SMCPLimit pLimit; SMCKeyInfo keyInfo;
    uint8_t result, status, data8; uint32_t data32; uint8_t bytes[32];
} SMCKeyData;

int smc_open(void);
int smc_write(const char *key, const uint8_t *bytes, uint32_t len);

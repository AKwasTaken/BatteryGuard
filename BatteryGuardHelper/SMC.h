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
int smc_keyinfo(const char *key, uint32_t *size);

int smc_key_count(uint32_t *count);
int smc_key_at(uint32_t index, uint32_t *key);
int smc_read_key(uint32_t key, uint8_t *bytes, uint32_t *size);

int smc_read_key_attr(uint32_t key, uint8_t *attr);

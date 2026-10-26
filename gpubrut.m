#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>

#define MAX_LEN 7

static const uint32_t K[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

static const int S[64] = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
};

static uint32_t rotl(uint32_t x, int c) {
    return (x << c) | (x >> (32 - c));
}

static void md5_short(const unsigned char *msg, int len, unsigned char out[16]) {
    uint32_t M[16] = {0};
    unsigned char *bytes = (unsigned char *)M;
    memcpy(bytes, msg, len);
    bytes[len] = 0x80;
    M[14] = (uint32_t)len * 8;

    uint32_t a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
    uint32_t A = a0, B = b0, C = c0, D = d0;

    for (int i = 0; i < 64; i++) {
        uint32_t F;
        int g;
        if (i < 16)      { F = (B & C) | (~B & D); g = i; }
        else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }
        else if (i < 48) { F = B ^ C ^ D;          g = (3 * i + 5) % 16; }
        else             { F = C ^ (B | ~D);       g = (7 * i) % 16; }
        F = F + A + K[i] + M[g];
        A = D;
        D = C;
        C = B;
        B = B + rotl(F, S[i]);
    }

    a0 += A; b0 += B; c0 += C; d0 += D;
    uint32_t r[4] = {a0, b0, c0, d0};
    for (int i = 0; i < 4; i++) {
        out[i * 4 + 0] = (unsigned char)(r[i]);
        out[i * 4 + 1] = (unsigned char)(r[i] >> 8);
        out[i * 4 + 2] = (unsigned char)(r[i] >> 16);
        out[i * 4 + 3] = (unsigned char)(r[i] >> 24);
    }
}

static void print_hash(const unsigned char h[16]) {
    for (int i = 0; i < 16; i++)
        printf("%02x", h[i]);
}

static double now_ms(void) {
    return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1e6;
}

static NSString *const kSource =
@"#include <metal_stdlib>\n"
@"using namespace metal;\n"
@"\n"
@"constant uint K[64] = {\n"
@"0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,\n"
@"0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,\n"
@"0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,\n"
@"0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,\n"
@"0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,\n"
@"0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,\n"
@"0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,\n"
@"0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391 };\n"
@"\n"
@"constant uint Sh[64] = {\n"
@"7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,\n"
@"5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,\n"
@"4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,\n"
@"6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21 };\n"
@"\n"
@"kernel void brute_k(device const uchar* target [[buffer(0)]],\n"
@"                    constant uint& len [[buffer(1)]],\n"
@"                    device atomic_int* foundFlag [[buffer(2)]],\n"
@"                    device ulong* foundIndex [[buffer(3)]],\n"
@"                    uint gid [[thread_position_in_grid]]) {\n"
@"    ulong n = (ulong)gid;\n"
@"    uchar cand[7];\n"
@"    for (int p = (int)len - 1; p >= 0; p--) {\n"
@"        cand[p] = (uchar)('a' + (n % 26));\n"
@"        n /= 26;\n"
@"    }\n"
@"\n"
@"    uint M[16];\n"
@"    for (int i = 0; i < 16; i++) M[i] = 0;\n"
@"    thread uchar* bytes = (thread uchar*)M;\n"
@"    for (uint i = 0; i < len; i++) bytes[i] = cand[i];\n"
@"    bytes[len] = 0x80;\n"
@"    M[14] = len * 8;\n"
@"\n"
@"    uint A = 0x67452301, B = 0xefcdab89, C = 0x98badcfe, D = 0x10325476;\n"
@"    for (int i = 0; i < 64; i++) {\n"
@"        uint F; int g;\n"
@"        if (i < 16)      { F = (B & C) | (~B & D); g = i; }\n"
@"        else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }\n"
@"        else if (i < 48) { F = B ^ C ^ D;          g = (3 * i + 5) % 16; }\n"
@"        else             { F = C ^ (B | ~D);       g = (7 * i) % 16; }\n"
@"        F = F + A + K[i] + M[g];\n"
@"        A = D; D = C; C = B;\n"
@"        B = B + rotate(F, Sh[i]);\n"
@"    }\n"
@"\n"
@"    uint r0 = 0x67452301 + A;\n"
@"    uint r1 = 0xefcdab89 + B;\n"
@"    uint r2 = 0x98badcfe + C;\n"
@"    uint r3 = 0x10325476 + D;\n"
@"    uint regs[4] = {r0, r1, r2, r3};\n"
@"\n"
@"    bool match = true;\n"
@"    for (int i = 0; i < 4 && match; i++) {\n"
@"        uint r = regs[i];\n"
@"        if (target[i*4+0] != (uchar)(r))       match = false;\n"
@"        if (match && target[i*4+1] != (uchar)(r >> 8))  match = false;\n"
@"        if (match && target[i*4+2] != (uchar)(r >> 16)) match = false;\n"
@"        if (match && target[i*4+3] != (uchar)(r >> 24)) match = false;\n"
@"    }\n"
@"\n"
@"    if (match) {\n"
@"        atomic_store_explicit(foundFlag, 1, memory_order_relaxed);\n"
@"        foundIndex[0] = (ulong)gid;\n"
@"    }\n"
@"}\n";

static uint64_t pow26(int n) {
    uint64_t r = 1;
    for (int i = 0; i < n; i++) r *= 26;
    return r;
}

int main(void) {
    @autoreleasepool {
        id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
        if (!dev) { printf("No Metal device\n"); return 1; }

        NSError *err = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:kSource options:nil error:&err];
        if (!lib) {
            printf("Metal compile error: %s\n", [[err localizedDescription] UTF8String]);
            return 1;
        }
        id<MTLFunction> fn = [lib newFunctionWithName:@"brute_k"];
        id<MTLComputePipelineState> pso = [dev newComputePipelineStateWithFunction:fn error:&err];
        if (!pso) { printf("Pipeline error\n"); return 1; }
        id<MTLCommandQueue> q = [dev newCommandQueue];

        printf("GPU: %s\n", [[dev name] UTF8String]);

        while (1) {
            char pwd[64];
            printf("\nEnter password (a-z, 1-%d letters, 0 to exit): ", MAX_LEN);
            fflush(stdout);
            if (scanf("%63s", pwd) != 1) break;
            if (strcmp(pwd, "0") == 0) break;

            int len = (int)strlen(pwd);
            int valid = (len >= 1 && len <= MAX_LEN);
            for (int i = 0; i < len && valid; i++)
                if (pwd[i] < 'a' || pwd[i] > 'z') valid = 0;
            if (!valid) {
                printf("Use only lowercase letters a-z, length 1-%d\n", MAX_LEN);
                continue;
            }

            unsigned char target[16];
            md5_short((const unsigned char *)pwd, len, target);
            printf("MD5 hash: ");
            print_hash(target);
            printf("\n");

            uint64_t totalCandidates = pow26(len);
            uint32_t lenU = (uint32_t)len;

            id<MTLBuffer> bufTarget = [dev newBufferWithBytes:target length:16
                                        options:MTLResourceStorageModeShared];
            id<MTLBuffer> bufLen = [dev newBufferWithBytes:&lenU length:sizeof(uint32_t)
                                     options:MTLResourceStorageModeShared];
            int32_t zero = 0;
            id<MTLBuffer> bufFlag = [dev newBufferWithBytes:&zero length:sizeof(int32_t)
                                      options:MTLResourceStorageModeShared];
            uint64_t idxInit = 0;
            id<MTLBuffer> bufIndex = [dev newBufferWithBytes:&idxInit length:sizeof(uint64_t)
                                       options:MTLResourceStorageModeShared];

            double t0 = now_ms();

            id<MTLCommandBuffer> cb = [q commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
            [enc setComputePipelineState:pso];
            [enc setBuffer:bufTarget offset:0 atIndex:0];
            [enc setBuffer:bufLen offset:0 atIndex:1];
            [enc setBuffer:bufFlag offset:0 atIndex:2];
            [enc setBuffer:bufIndex offset:0 atIndex:3];
            NSUInteger tgSize = pso.maxTotalThreadsPerThreadgroup;
            if (tgSize > 256) tgSize = 256;
            [enc dispatchThreads:MTLSizeMake((NSUInteger)totalCandidates, 1, 1)
           threadsPerThreadgroup:MTLSizeMake(tgSize, 1, 1)];
            [enc endEncoding];
            [cb commit];
            [cb waitUntilCompleted];

            double t1 = now_ms();

            int32_t *flagPtr = (int32_t *)[bufFlag contents];
            uint64_t *idxPtr = (uint64_t *)[bufIndex contents];

            if (*flagPtr) {
                uint64_t n = *idxPtr;
                char found[MAX_LEN + 1];
                for (int p = len - 1; p >= 0; p--) {
                    found[p] = (char)('a' + (n % 26));
                    n /= 26;
                }
                found[len] = '\0';
                printf("Found: %s\n", found);
                printf("Candidates checked: %llu\n", (unsigned long long)totalCandidates);
                printf("Time: %.4f ms\n", t1 - t0);
                printf("Check: %s\n", strcmp(found, pwd) == 0 ? "OK" : "MISMATCH");
            } else {
                printf("Not found\n");
            }
        }
    }
    return 0;
}


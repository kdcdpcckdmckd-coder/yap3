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
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}


static long long brute_force(const unsigned char target[16], int len, char *found) {
    int idx[MAX_LEN] = {0};
    unsigned char cand[MAX_LEN];
    unsigned char h[16];
    long long attempts = 0;

    while (1) {
        for (int i = 0; i < len; i++)
            cand[i] = (unsigned char)('a' + idx[i]);

        attempts++;
        md5_short(cand, len, h);
        if (memcmp(h, target, 16) == 0) {
            memcpy(found, cand, len);
            found[len] = '\0';
            return attempts;
        }

        int p = len - 1;
        while (p >= 0 && ++idx[p] == 26) {
            idx[p] = 0;
            p--;
        }
        if (p < 0) return -1;
    }
}

int main(void) {
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

        char found[MAX_LEN + 1];
        double t0 = now_ms();
        long long attempts = brute_force(target, len, found);
        double t1 = now_ms();

        if (attempts < 0) {
            printf("Not found\n");
        } else {
            printf("Found: %s\n", found);
            printf("Attempts: %lld\n", attempts);
            printf("Time: %.4f ms\n", t1 - t0);
        }
    }
    return 0;
}


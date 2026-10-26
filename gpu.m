#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define TG 16

static NSString *const kSource =
@"#include <metal_stdlib>\n"
@"using namespace metal;\n"
@"kernel void transpose_k(device const float* A [[buffer(0)]],\n"
@"                        device float* B [[buffer(1)]],\n"
@"                        constant uint& rows [[buffer(2)]],\n"
@"                        constant uint& cols [[buffer(3)]],\n"
@"                        uint2 gid [[thread_position_in_grid]]) {\n"
@"    uint j = gid.x;\n"
@"    uint i = gid.y;\n"
@"    if (i < rows && j < cols) {\n"
@"        B[j * rows + i] = A[i * cols + j];\n"
@"    }\n"
@"}\n";

static double now_ms(void) {
    return clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1e6;
}

static void transpose_cpu(const float *A, float *B, int rows, int cols) {
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            B[j * rows + i] = A[i * cols + j];
}

static void print_matrix(const float *M, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++)
            printf("%5.0f", M[i * cols + j]);
        printf("\n");
    }
}

static void run_gpu(id<MTLCommandQueue> q,
                    id<MTLComputePipelineState> pso,
                    id<MTLBuffer> bufA, id<MTLBuffer> bufB,
                    uint32_t rows, uint32_t cols) {
    id<MTLCommandBuffer> cb = [q commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:pso];
    [enc setBuffer:bufA offset:0 atIndex:0];
    [enc setBuffer:bufB offset:0 atIndex:1];
    [enc setBytes:&rows length:sizeof(uint32_t) atIndex:2];
    [enc setBytes:&cols length:sizeof(uint32_t) atIndex:3];
    [enc dispatchThreads:MTLSizeMake(cols, rows, 1)
   threadsPerThreadgroup:MTLSizeMake(TG, TG, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
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
        id<MTLFunction> fn = [lib newFunctionWithName:@"transpose_k"];
        id<MTLComputePipelineState> pso = [dev newComputePipelineStateWithFunction:fn error:&err];
        if (!pso) { printf("Pipeline error\n"); return 1; }
        id<MTLCommandQueue> q = [dev newCommandQueue];

        printf("GPU: %s\n", [[dev name] UTF8String]);

        while (1) {
            int rows, cols;
            printf("\nEnter rows and cols : ");
            fflush(stdout);
            if (scanf("%d %d", &rows, &cols) != 2) break;
            if (rows <= 0 || cols <= 0) break;

            size_t total = (size_t)rows * cols;
            size_t bytes = total * sizeof(float);

            id<MTLBuffer> bufA = [dev newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            id<MTLBuffer> bufB = [dev newBufferWithLength:bytes options:MTLResourceStorageModeShared];
            float *C = (float *)malloc(bytes);
            if (!bufA || !bufB || !C) {
                printf("Not enough memory\n");
                free(C);
                continue;
            }

            float *A = (float *)[bufA contents];
            float *B = (float *)[bufB contents];
            for (size_t k = 0; k < total; k++)
                A[k] = (float)(rand() % 100);

            run_gpu(q, pso, bufA, bufB, rows, cols);

            double t0 = now_ms();
            run_gpu(q, pso, bufA, bufB, rows, cols);
            double t1 = now_ms();

            double total_ms = t1 - t0;

            transpose_cpu(A, C, rows, cols);
            int ok = (memcmp(B, C, bytes) == 0);

            if (rows <= 10 && cols <= 10) {
                printf("\nMatrix A (%d x %d):\n", rows, cols);
                print_matrix(A, rows, cols);
                printf("\nMatrix B = transposed A (%d x %d):\n", cols, rows);
                print_matrix(B, cols, rows);
            }

            printf("\n%d x %d: %.4f ms\n", rows, cols, total_ms);
            printf("Check with CPU: %s\n", ok ? "OK" : "MISMATCH");

            free(C);
        }
    }
    return 0;
}

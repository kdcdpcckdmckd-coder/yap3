#include <stdio.h>
#include <stdlib.h>
#include <time.h>

void transpose_cpu(const float* A, float* B, int rows, int cols) {
    for (int i = 0; i < rows; i++)
        for (int j = 0; j < cols; j++)
            B[j * rows + i] = A[i * cols + j];
}

void print_matrix(const float* M, int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++)
            printf("%5.0f", M[i * cols + j]);
        printf("\n");
    }
}

int main(void) {
    while (1) {
        int rows, cols;
        printf("\nEnter rows and cols : ");
        fflush(stdout);
        if (scanf("%d %d", &rows, &cols) != 2) break;
        if (rows <= 0 || cols <= 0) break;

        size_t total = (size_t)rows * cols;
        float* A = (float*)malloc(total * sizeof(float));
        float* B = (float*)malloc(total * sizeof(float));
        if (!A || !B) {
            printf("Not enough memory\n");
            free(A);
            free(B);
            continue;
        }

        for (size_t k = 0; k < total; k++)
            A[k] = (float)(rand() % 100);

        uint64_t t0 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
        transpose_cpu(A, B, rows, cols);
        uint64_t t1 = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);

        double ms = (t1 - t0) / 1e6;

        if (rows <= 10 && cols <= 10) {
            printf("\nMatrix A (%d x %d):\n", rows, cols);
            print_matrix(A, rows, cols);
            printf("\nMatrix B = transposed A (%d x %d):\n", cols, rows);
            print_matrix(B, cols, rows);
        }

        printf("\n%d x %d: %.4f ms\n", rows, cols, ms);

        free(A);
        free(B);
    }
    return 0;
}


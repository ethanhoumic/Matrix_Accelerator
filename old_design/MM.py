import numpy as np

def tiled_MM(A, B, VS, VL, AD):

    M, K = A.shape
    K, N = B.shape

    A_buffer = np.zeros((VL, VS))
    B_buffer = np.zeros((VS,))
    C = np.zeros((M, N))
    Accumulator = np.zeros((VL, AD))

    for m in range(0, M, VL):
        for n in range(0, N, AD):

            Accumulator.fill(0)    # clean accumulation collector

            for k in range(0, K, VS):

                A_tile = A[m:m + VL, k:k + VS]    # submatrix of A
                A_buffer[:A_tile.shape[0], :A_tile.shape[1]] = A_tile    # loads into buffer
                
                for a in range(AD):

                    B_vector = B[k:k + VS, n + a]    # subvector of B
                    B_buffer[:B_vector.shape[0]] = B_vector   # loads into buffer

                    for l in range(VL):
                        for v in range(VS):

                            Accumulator[l, a] += A_buffer[l, v] * B_buffer[v]    # MAC calculation

            C[m:m+VL, n:n+AD] = Accumulator[:VL, :AD]

    return C

A = np.array([[1, 0, 1, 1],
              [1, 0, 0, 1],
              [0, 0, 1, 1],
              [1, 1, 1, 1]])

B = np.array([[0, 1, 0, 1],
              [1, 1, 0, 1],
              [0, 1, 1, 0],
              [1, 1, 1, 1]])

VL = 16  # Vector Lanes
AD = 384  # Accumulation Depth
VS = 2  # Vector Size

C = tiled_MM(A, B, VS, VL, AD)
print("Result Matrix C:")
print(C)
print("Correct Answer of C:")
print(A @ B)

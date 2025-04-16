import numpy as np

# 生成兩個 64x64 只包含 0 和 1 的矩陣
matrix1 = np.random.randint(0, 2, (64, 64), dtype=np.uint8)
matrix2 = np.random.randint(0, 2, (64, 64), dtype=np.uint8)
matrix3 = matrix1 @ matrix2

np.savetxt("matrix_a.txt", matrix1, fmt="%d")
np.savetxt("matrix_b.txt", matrix2, fmt="%d")
np.savetxt("ans.txt", matrix3, fmt="%d")
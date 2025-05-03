import numpy as np

# 生成兩個 64x1 的隨機 0/1 向量
matrix1 = np.random.randint(0, 2, (64, 1), dtype=np.uint8)
matrix2 = np.random.randint(0, 2, (64, 1), dtype=np.uint8)

# 計算內積
inner_product = np.dot(matrix1.T, matrix2).item()

# 轉換內積為 24 位元的二進位數字
inner_product_bin = format(inner_product, '024b')

# 轉換每個元素為 4 位元，並補足 264 位元
bin_matrix1 = int("".join(f"{x:04b}" for x in matrix1.flatten()), 2)
bin_matrix2 = int("".join(f"{x:04b}" for x in matrix2.flatten()), 2)

a_vec = bin_matrix1  # 保持單獨的 264-bit 數字
b_vec = bin_matrix2  # 保持單獨的 264-bit 數字

# 將結果存入檔案
with open("a_vec.txt", "w") as f:
    f.write(format(a_vec, '0264b'))

with open("b_vec.txt", "w") as f:
    f.write(format(b_vec, '0264b'))

with open("vec_ans.txt", "w") as f:
    f.write(inner_product_bin)

# 轉換為一維陣列以便輸出格式美觀
print("Matrix1:", matrix1.flatten())
print("Matrix2:", matrix2.flatten())
print("Inner Product:", inner_product)
print("Inner Product (24-bit):", inner_product_bin)
print("A_Vec (264-bit):", format(a_vec, '0264b'))
print("B_Vec (264-bit):", format(b_vec, '0264b'))


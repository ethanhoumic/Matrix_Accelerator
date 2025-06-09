import numpy as np
import os


# generation
def generate_activation(shape=(64, 64)):
    linear_output = np.random.randn(*shape)
    activation = 10 * np.maximum(0, linear_output)
    return activation

def generate_weight(shape=(64, 64)):
    limit = np.sqrt(6 / (shape[0] + shape[1]))
    weight = 100 * np.random.uniform(-limit, limit, size=shape)
    return weight

def save_matrix_txt(matrix, filename):
    np.savetxt(filename, matrix, fmt="%.6f")

# softmax function
def softmax_matrix_rows(X):
    e_x = np.exp(X - np.max(X, axis=1, keepdims=True))
    return e_x / np.sum(e_x, axis=1, keepdims=True)

# quantization functions
def quantize_tensor(tensor, num_bits=8):
    assert num_bits in [8, 4], "Only int8 or int4 supported"
    qmin = -2 ** (num_bits - 1)
    qmax = 2 ** (num_bits - 1) - 1

    max_abs = np.max(np.abs(tensor))
    scale = max_abs / qmax if max_abs != 0 else 1

    tensor_q = np.round(tensor / scale).astype(np.int8)
    tensor_q = np.clip(tensor_q, qmin, qmax)
    return tensor_q, scale

def save_quantized_matrix(path, matrix):
    np.savetxt(path, matrix, fmt='%d')

# saving the scale
def float_to_fp8(x):
    # Vectorized float32 to E4M3N (NVIDIA FP8) conversion (simplified)
    x = np.array(x, dtype=np.float32).flatten()
    fp8_vals = np.zeros_like(x, dtype=np.uint8)

    for i, val in enumerate(x):
        if np.isnan(val):
            fp8_vals[i] = 0x7F
        elif val == 0:
            fp8_vals[i] = 0
        elif np.isinf(val):
            fp8_vals[i] = 0x78 if val > 0 else 0xF8
        else:
            sign = 0 if val >= 0 else 1
            val = abs(val)

            exp = np.floor(np.log2(val))
            mant = val / (2 ** exp) - 1

            exp_int = int(exp + 7)  # bias = 7 for E4M3
            mant_int = int(mant * 8 + 0.5)  # 3-bit mantissa

            if exp_int <= 0:
                exp_int = 0
                mant_int = 0
            elif exp_int >= 15:
                exp_int = 15
                mant_int = 0

            fp8 = (sign << 7) | (exp_int << 3) | (mant_int & 0x7)
            fp8_vals[i] = fp8

    return fp8_vals

def save_fp8_txt(fp, path):
    fp8 = float_to_fp8(fp)
    np.savetxt(path, fp8, fmt='%d')

def quantize_per_row_int4_with_scale_append(matrix):
    matrix = np.array(matrix, dtype=np.float32)
    rows, cols = matrix.shape
    quantized = np.zeros((rows, cols), dtype=np.int8)
    scales = np.zeros(rows, dtype=np.float32)

    # Step 1: quantize each row (vector) to int4
    for i in range(rows):
        row = matrix[i]
        max_abs = np.max(np.abs(row))
        scale = max_abs / 7.0 if max_abs != 0 else 1.0
        q_row = np.round(row / scale).astype(np.int8)
        q_row = np.clip(q_row, -8, 7)
        quantized[i] = q_row
        scales[i] = scale

    # Step 2: quantize all scales to int8
    max_scale = np.max(np.abs(scales))
    scale_of_scale = max_scale / 127.0 if max_scale != 0 else 1.0
    q_scales = np.round(scales / scale_of_scale).astype(np.int8)
    q_scales = np.clip(q_scales, -128, 127)

    # Step 3: append quantized scale to each vector
    final_quantized = np.zeros((rows, cols + 1), dtype=np.int8)
    final_quantized[:, :-1] = quantized
    final_quantized[:, -1] = q_scales

    return final_quantized, scale_of_scale


def quantize_per_col_int4_with_scale_append(matrix):
    matrix = np.array(matrix, dtype=np.float32)
    rows, cols = matrix.shape
    quantized = np.zeros((rows, cols), dtype=np.int8)
    scales = np.zeros(cols, dtype=np.float32)

    # Step 1: int4 quantization for each column (vector)
    for j in range(cols):
        col = matrix[:, j]
        max_abs = np.max(np.abs(col))
        scale = max_abs / 7.0 if max_abs != 0 else 1.0
        q_col = np.round(col / scale).astype(np.int8)
        q_col = np.clip(q_col, -8, 7)
        quantized[:, j] = q_col
        scales[j] = scale

    # Step 2: second int8 quantization
    max_scale = np.max(np.abs(scales))
    meta_scale = max_scale / 127.0 if max_scale != 0 else 1.0
    q_scales = np.round(scales / meta_scale).astype(np.int8)
    q_scales = np.clip(q_scales, -128, 127)

    # Step 3: append quantized scale to each vector
    final_quantized = np.zeros((rows + 1, cols), dtype=np.int8)
    final_quantized[:-1, :] = quantized
    final_quantized[-1, :] = q_scales

    return final_quantized, meta_scale

# ===== main =====
A = generate_activation((64, 64))
B = generate_weight((64, 64))
C = A @ B

# save answers
save_matrix_txt(A, "./data_files/A_correct.txt")
print("saved A_correct.txt")
save_matrix_txt(B, "./data_files/B_correct.txt")
print("saved B_correct.txt")
save_matrix_txt(C, "./data_files/C_correct.txt")
print("saved C_correct.txt")
C_softmax = softmax_matrix_rows(C)
save_matrix_txt(C_softmax, "./data_files/C_softmax.txt")

# save quantized matrices
A_quantized_int8, A_int8_scale= quantize_tensor(A, num_bits=8)
B_quantized_int8, B_int8_scale= quantize_tensor(A, num_bits=8)
save_quantized_matrix("./data_files/A_int8.txt", A_quantized_int8)
save_quantized_matrix("./data_files/B_int8.txt", B_quantized_int8)
save_fp8_txt(127/A_int8_scale, "./data_files/A_int8_fp8.txt")
save_fp8_txt(127/B_int8_scale, "./data_files/B_int8_fp8.txt")

A_quantized_int4, A_int4_scale = quantize_tensor(A, num_bits=4)
B_quantized_int4, B_int4_scale = quantize_tensor(B, num_bits=4)
save_quantized_matrix("./data_files/A_int4.txt", A_quantized_int4)
save_quantized_matrix("./data_files/B_int4.txt", B_quantized_int4)
save_fp8_txt(7/A_int4_scale, "./data_files/A_int4_fp8.txt")
save_fp8_txt(7/B_int4_scale, "./data_files/B_int4_fp8.txt")

A_quantized_int4_vsq, A_int4_scale_vsq = quantize_per_row_int4_with_scale_append(A)
B_quantized_int4_vsq, B_int4_scale_vsq = quantize_per_col_int4_with_scale_append(B)
save_quantized_matrix("./data_files/A_int4_vsq.txt", A_quantized_int4_vsq)
save_quantized_matrix("./data_files/B_int4_vsq.txt", B_quantized_int4_vsq)
print(A_int4_scale_vsq)
print(B_int4_scale_vsq)
save_fp8_txt(A_int4_scale_vsq, "./data_files/A_vsq_fp8.txt")
save_fp8_txt(B_int4_scale_vsq, "./data_files/B_vsq_fp8.txt")


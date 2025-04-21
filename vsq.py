import numpy as np

# 原始浮點 weights 和 activations
w_float = np.array([[0.3, -0.6, 0.9], [0.7, -0.7, 0.2], [0.1, -0.4, 0.5]])
a_float = np.array([[0.5, -0.2, 0.7], [0.4, -0.1, 0.3], [0.6, -0.5, 0.8]])

# 1. 計算每個 vector 的 scale（Per-vector quantization）
s_w = []
s_a = []
for i in range(3):
    s_w.append(np.max(np.abs(w_float[i])) / 127)
    s_a.append(np.max(np.abs(a_float[i])) / 127)

# 2. 量化成 int8
w_int8 = np.round(w_float / s_w).astype(np.int8)
a_int8 = np.round(a_float / s_a).astype(np.int8)

# 3. 在硬體中做整數乘加（MAC）
int_mac = []
for i in range(3):
    int_mac.append(np.dot(w_int8[i].astype(np.int32), a_int8[i].astype(np.int32)))
int_mac = np.array(int_mac).flatten()  # Flatten the list

# 4. 還原為浮點（第一層 scale）
float_mac = []
for i in range(3):
    float_mac.append(s_w[i] * s_a[i] * int_mac[i])
float_mac = np.array(float_mac).flatten()  # Flatten the list

# 5. 根據 float_mac 決定 per-layer scale（第二層 scale）
s_layer = np.max(np.abs(np.maximum(s_w, s_a))) / 7
output_float = s_layer * np.array(float_mac)

# 6. 再次量化成 int8 輸出
s_out = np.max(np.abs(output_float)) / 127
output_int8 = np.round(output_float / s_out).astype(np.int8)

# 7. 輸出所有細節
print("=== Two-Level Quantization Simulation ===")
print(f"Original w_float: \n{w_float}")
print(f"Original a_float: \n{a_float}")
print(f"Quantized w_int8: \n{w_int8}, \nscale: \n{[f'{scale:.5f}' for scale in s_w]}")
print(f"Quantized a_int8: \n{a_int8}, \nscale: \n{[f'{scale:.5f}' for scale in s_a]}")
print(f"Integer MAC result: \n{int_mac}")
print(f"Float MAC (1st scale): \n{[f'{value:.5f}' for value in float_mac]}")
print(f"Layer scale (2nd scale): {s_layer:.5f}")
print(f"Float output (after 2-level scaling): {[f'{output:.5f}' for output in output_float]}")
print(f"Output scale (for quantization): {s_out:.10f}")
print(f"Quantized output_int8: {output_int8}")
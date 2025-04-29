import numpy as np

# original weights and activations
w_float = np.array([[0.3, -0.6, 0.9], [0.7, -0.7, 0.2], [0.1, -0.4, 0.5]])
a_float = np.array([[0.5, -0.2, 0.7], [0.4, -0.1, 0.3], [0.6, -0.5, 0.8]])

# 1. scale for every vector（Per-vector quantization）
s_w = []
s_a = []
for i in range(3):
    s_w.append(np.max(np.abs(w_float[i])) / 127)
    s_a.append(np.max(np.abs(a_float[i])) / 127)

# 2. per-layer scale factor（Per-layer quantization）
s_layer = np.max(np.abs(np.maximum(s_w, s_a))) / 127

# 3. int8 quantization
w_int8 = np.round(w_float / s_w).astype(np.int8)
a_int8 = np.round(a_float / s_a).astype(np.int8)

# 4. updating per-vector scale factor
for i in range(3):
    s_w[i] = np.round(s_w[i] / s_layer, 0)
    s_a[i] = np.round(s_a[i] / s_layer, 0)

# 5. MAC
int_mac = []
for i in range(3):
    int_mac.append(np.dot(w_int8[i].astype(np.int32), a_int8[i].astype(np.int32)))
int_mac = np.array(int_mac).flatten()  # Flatten the list

# 6. first scale
float_mac = []
for i in range(3):
    float_mac.append(s_w[i] * s_a[i] * int_mac[i])
float_mac = np.array(float_mac).flatten()  # Flatten the list

# 7. second scale
output_float = s_layer * np.array(float_mac)

# 8. int8 quantization for output
s_out = np.max(np.abs(output_float)) / 127
output_int8 = np.round(output_float / s_out).astype(np.int8)

print("=== Two-Level Quantization Simulation ===")
print(f"Original w_float: \n{w_float}")
print(f"Original a_float: \n{a_float}")
print(f"Quantized w_int8: \n{w_int8}, \nscale: \n{[f'{scale}' for scale in s_w]}")
print(f"Quantized a_int8: \n{a_int8}, \nscale: \n{[f'{scale}' for scale in s_a]}")
print(f"Layer scale (2nd scale): {s_layer:.5f}")
print(f"Integer MAC result: \n{int_mac}")
print(f"Integer MAC (1st scale): \n{[f'{value}' for value in float_mac]}")
print(f"Float output (after 2-level scaling): \n{[f'{output:.5f}' for output in output_float]}")
print(f"Output scale (for quantization): {s_out:.5f}")
print(f"Quantized output_int8: {output_int8}")
import numpy as np

def round_to_nbit(x, n):
    return np.round(x * (2 ** (n - 1))) / (2 ** (n - 1))

def scale_factor(v, n):

    v_max = np.abs(np.max(v))
    s = (2 ** (n - 1) - 1) / v_max

    return s

def quantize(v, s):

    v = np.array(v)
    v_q = np.round(v * s) // s

    return v_q

# assume int8 mode
n = 8

w = [[1.65, 9.47, 6.18, 4.13], 
     [1.54, 0.11, 9.01, 8.11], 
     [6.20, 6.31, 4.74, 5.28], 
     [1.13, 9.32, 4.13, 0.11]]
a = [[0.13, 7.18, 5.42, 1.34],
     [6.31, 4.54, 8.13, 0.44],
     [1.32, 6.47, 4.99, 3.21],
     [1.66, 6.13, 6.12, 4.97]]

print("Input weights: ", w)
print("Input activations: ", a)

s_w = []
s_a = []
for i in range(len(w)):
    s_w.append(round_to_nbit(scale_factor(w[i], n), 8))
for i in range(len(a)):
    s_a.append(round_to_nbit(scale_factor(a[i], n), 8))

print("Scale factor for weights: ", s_w)
print("Scale factor for activations: ", s_a)

dot_product = []
for i in range(len(w)):
    dot_product.append(round_to_nbit(np.dot(w[i], a[i]), 24))
s_product = []
for i in range(len(w)):
    s_product.append(round_to_nbit(s_a[i] * s_w[i], 8))
partial_sum = []
for i in range(len(w)):
    partial_sum.append(round_to_nbit(dot_product[i] * s_product[i], 24))

print("Dot product: ", dot_product)
print("Scale factor for product: ", s_product)
print("Partial sum: ", partial_sum)

per_layer_scale_factor = round_to_nbit(scale_factor(np.ravel(partial_sum), n), 10)
print("Per-layer scale factor: ", per_layer_scale_factor)
partial_sum = round_to_nbit(np.array(partial_sum) * per_layer_scale_factor, 24)

s_final =[]
for i in range(len(partial_sum)):
    s_final.append(round_to_nbit(scale_factor(partial_sum[i], n), 8))
    partial_sum[i] = quantize(partial_sum[i], s_final[i])
print("after final quantization: ", partial_sum)







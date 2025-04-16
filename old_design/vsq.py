import numpy as np

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
per_layer_scale_factor = 1

w = [1.65, 9.47, 6.18, 4.13]
a = [0.13, 7.18, 5.42, 1.34]
dot_product = np.dot(w, a)
print("Input weights: ", w)
print("Input activations: ", a)

s_w = scale_factor(w, n)
s_a = scale_factor(a, n)

print("Scale factor for weights: ", s_w)
print("Scale factor for activations: ", s_a)
print("Quantized weights: ", quantize(w, s_w))
print("Quantized activations: ", quantize(a, s_a))

s_product = np.round(s_w * s_a, 2)
partial_sum = dot_product * s_product

print("Dot product: ", dot_product)
print("Scale factor for product: ", s_product)
print("Partial sum: ", partial_sum)

# skip per-layer scale factor for now

s_final = scale_factor(partial_sum, 2*n)
final_product = quantize(partial_sum, s_final)
print("Final product: ", final_product)
print("Final scale factor: ", s_final)







import numpy as np

def quantize_bias(bias, num_bits):
    assert num_bits in [4, 8], "Only int4 or int8 supported"
    qmin = -2 ** (num_bits - 1)
    qmax = 2 ** (num_bits - 1) - 1

    max_abs = np.max(np.abs(bias))
    scale = max_abs / qmax if max_abs != 0 else 1.0
    q_bias = np.round(bias / scale).astype(np.int8)
    q_bias = np.clip(q_bias, qmin, qmax)
    return q_bias, scale

def save_bias_binary_txt(filename, q_bias, num_bits):
    with open(filename, 'w') as f:
        for val in q_bias:
            if num_bits == 8:
                bin_str = f'{np.uint8(val) & 0xFF:08b}'
            else:  # int4
                bin_str = f'{val & 0xF:04b}'
                bin_str = '0000' + bin_str  # 4-bit padding to 8-bit
            f.write(bin_str + '\n')
    print(f"Saved {num_bits}-bit bias to {filename}")

np.random.seed(0)
bias = np.random.uniform(-1.0, 1.0, size=(64,)).astype(np.float32)

q_bias_int8, scale_int8 = quantize_bias(bias, num_bits=8)
save_bias_binary_txt("./data_files/bias_int8.txt", q_bias_int8, num_bits=8)

q_bias_int4, scale_int4 = quantize_bias(bias, num_bits=4)
save_bias_binary_txt("./data_files/bias_int4.txt", q_bias_int4, num_bits=4)

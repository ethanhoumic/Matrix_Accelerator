import random

A_WIDTH = 264
B_WIDTH = 264
BANKS = 16
CYCLES = 128
ELEMENTS = 33  # 264 bits / 8 = 33 int8 values

def generate_bin_string(n):
    return ''.join(random.choice('01') for _ in range(n))

# --- 1. Generate input files ---
with open("a_sram_binary.txt", "w") as f:
    for _ in range(BANKS * CYCLES):  # 2048 entries
        f.write(generate_bin_string(A_WIDTH) + "\n")

with open("b_sram_binary.txt", "w") as f:
    for _ in range(BANKS * CYCLES):  # 2048 entries
        f.write(generate_bin_string(B_WIDTH) + "\n")

# --- 2. Read input ---
with open("a_sram_binary.txt", "r") as f:
    a_buffer = [line.strip() for line in f.readlines()]

with open("b_sram_binary.txt", "r") as f:
    b_buffer = [line.strip() for line in f.readlines()]

# --- 3. Initialize latch [bank][counter] = 24-bit int ---
latch_array = [[0 for _ in range(16)] for _ in range(16)]  # 16 banks × 16 counters

# --- 4. Simulate Verilog behavior ---
for cycle in range(CYCLES):
    # 固定 16 組 a_vec
    a_vectors = []
    for bank in range(16):
        bits = a_buffer[cycle * 16 + bank]
        a_vals = [int(bits[i*8:(i+1)*8], 2) for i in range(ELEMENTS)]
        a_vectors.append(a_vals)

    # 依序處理 16 次 counter（b_vec 不同）
    for counter in range(16):
        b_bits = b_buffer[cycle * 16 + counter]
        b_vals = [int(b_bits[i*8:(i+1)*8], 2) for i in range(ELEMENTS)]

        for bank in range(16):
            acc = latch_array[bank][counter]
            dot = sum(a_vectors[bank][i] * b_vals[i] for i in range(ELEMENTS))
            acc = (acc + dot) & 0xFFFFFF  # 24-bit wrap
            latch_array[bank][counter] = acc

# --- 5. Dump output ---
with open("output_sram_binary.txt", "w") as f:
    for bank in range(16):
        line = ''.join(format(latch_array[bank][counter], '024b') for counter in range(16))
        f.write(line + "\n")

print("Correct simulation output saved to output_sram_binary.txt")

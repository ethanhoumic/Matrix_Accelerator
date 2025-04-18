
import random
from collections import deque

A_WIDTH = 264
B_WIDTH = 264
BANKS = 16
CYCLES = 128
ELEMENTS = 33
COUNTER_MOD = 16

def generate_bin_string(n):
    return ''.join(random.choice('01') for _ in range(n))

def generate_input_files():
    with open("a_sram_binary.txt", "w") as f:
        for _ in range(BANKS * CYCLES):
            f.write(generate_bin_string(A_WIDTH) + "\n")

    with open("b_sram_binary.txt", "w") as f:
        for _ in range(BANKS * CYCLES):
            f.write(generate_bin_string(B_WIDTH) + "\n")

def read_input_file(path):
    with open(path, 'r') as f:
        return [line.strip() for line in f.readlines()]

def write_output_file(path, lines):
    with open(path, 'w') as f:
        for line in lines:
            f.write(line + '\n')

def simulate_mac_with_delay(a_buffer, b_buffer):
    latch_array = [[0 for _ in range(COUNTER_MOD)] for _ in range(BANKS)]
    pending_write_queue = deque()

    for cycle in range(CYCLES):
        a_vectors = []
        for bank in range(BANKS):
            bits = a_buffer[cycle * 16 + bank]
            a_vals = [int(bits[i * 8:(i + 1) * 8], 2) for i in range(ELEMENTS)]
            a_vectors.append(a_vals)

        for counter in range(COUNTER_MOD):
            while pending_write_queue:
                bank, delayed_counter, val = pending_write_queue.popleft()
                latch_array[bank][delayed_counter] = val

            b_bits = b_buffer[cycle * 16 + counter]
            b_vals = [int(b_bits[i * 8:(i + 1) * 8], 2) for i in range(ELEMENTS)]

            for bank in range(BANKS):
                acc = latch_array[bank][counter]
                dot = sum(a_vectors[bank][i] * b_vals[i] for i in range(ELEMENTS))
                result = (acc + dot) & 0xFFFFFF
                pending_write_queue.append((bank, counter, result))

    while pending_write_queue:
        bank, delayed_counter, val = pending_write_queue.popleft()
        latch_array[bank][delayed_counter] = val

    output_lines = []
    for bank in range(BANKS):
        line = ''.join(format(latch_array[bank][i], '024b') for i in range(COUNTER_MOD))
        output_lines.append(line)

    return output_lines

def simulate_mac_with_vsq(a_buffer, b_buffer):
    latch_array = [[0 for _ in range(COUNTER_MOD)] for _ in range(BANKS)]
    pending_write_queue = deque()

    for cycle in range(CYCLES):
        a_factors = [int(a_buffer[cycle * 16 + bank][0:8], 2) for bank in range(BANKS)]
        b_factor = int(b_buffer[cycle * 16][0:8], 2)

        for counter in range(COUNTER_MOD):
            while pending_write_queue:
                bank, delayed_counter, val = pending_write_queue.popleft()
                latch_array[bank][delayed_counter] = val

            for bank in range(BANKS):
                acc = latch_array[bank][counter]
                product = a_factors[bank] * b_factor
                product &= 0xFF  # 模擬 8-bit mask
                scaled_product = (acc * product) & 0x3FFFFF
                result = (acc + scaled_product) & 0xFFFFFF
                pending_write_queue.append((bank, counter, result))

    while pending_write_queue:
        bank, delayed_counter, val = pending_write_queue.popleft()
        latch_array[bank][delayed_counter] = val

    output_lines = []
    for bank in range(BANKS):
        line = ''.join(format(latch_array[bank][i], '024b') for i in range(COUNTER_MOD))
        output_lines.append(line)

    return output_lines

if __name__ == '__main__':
    generate_input_files()
    a_buffer = read_input_file("a_sram_binary.txt")
    b_buffer = read_input_file("b_sram_binary.txt")
    output_lines = simulate_mac_with_vsq(a_buffer, b_buffer)
    write_output_file("output_sram_binary.txt", output_lines)
    print("a_sram_binary.txt, b_sram_binary.txt 和 output_sram_binary.txt 已成功產生")

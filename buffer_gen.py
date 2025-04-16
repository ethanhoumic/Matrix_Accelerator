import random
import numpy as np

A_BUFFER_SIZE = 2048
B_BUFFER_SIZE = 2048
A_WIDTH = 264
B_WIDTH = 264
OUTPUT_WIDTH = 384
BANK_NUM = 16

def generate_bin_string(size):
    """Generate a binary string of the given size."""
    return ''.join(random.choice('01') for _ in range(size))

with open("a_sram_binary.txt", "w") as a_file:
    for _ in range(A_BUFFER_SIZE):
        a_file.write(generate_bin_string(A_WIDTH) + "\n")

with open("b_sram_binary.txt", "w") as b_file:
    for _ in range(B_BUFFER_SIZE):
        b_file.write(generate_bin_string(B_WIDTH) + "\n")

with open("a_sram_binary.txt", "r") as a_file, open("b_sram_binary.txt", "r") as b_file, open("output_sram_binary.txt", "w") as output_file:
    a_vector = []
    for j in range(A_BUFFER_SIZE // BANK_NUM):
        for i in range(BANK_NUM):
            a_vector.append(np.array([int(bit) for bit in a_file.readline().strip()]))
        for i in range(BANK_NUM):
            b_vector = np.array([int(bit) for bit in b_file.readline().strip()])
            for k in range(BANK_NUM):
                output_vector = np.dot(a_vector[k], b_vector)
                output_file.write(f"{output_vector:024b}")
            output_file.write("\n")

    print("Binary files generated successfully.")
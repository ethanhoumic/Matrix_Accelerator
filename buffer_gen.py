import random
from collections import deque

A_PATTERN = 4
B_PATTERN = 5
HEIGHT = 32
A_FILE = 'a_sram_binary.txt'
B_FILE = 'b_sram_binary.txt'
OUTPUTFILE = 'output_sram_binary.txt'

def generate_buffer(file, pattern, height, mode, scale_factor=0):
    """Generate a buffer with a specific pattern and height."""
    if mode == 'int8':
        if not (-128 <= pattern <= 127):
            raise ValueError("pattern must be between -128 and 127 for signed int8 mode")

        pattern_bin = format((pattern + (1 << 8)) % (1 << 8), '08b')
        repeated = pattern_bin * 32  # 256 bits
        full_pattern = repeated + '0' * 8

        with open(file, 'w') as f:
            for _ in range(height):
                f.write(full_pattern + '\n')

    elif mode == 'int4':
        if not (-8 <= pattern <= 7):
            raise ValueError("pattern must be between -8 and 7 for signed int4 mode")

        pattern_bin = format((pattern + (1 << 4)) % (1 << 4), '04b')
        repeated = pattern_bin * 64  # 256 bits

        scale_bin = format(scale_factor, '08b')
        full_pattern = scale_bin + repeated  # total 264 bits

    else:
        raise ValueError("mode must be either 'int8' or 'int4'")
    
def generate_output(file, pattern_a, pattern_b, height, mode):
    """Generate output buffer based on two input patterns."""
    if mode == 'int8':
        product = pattern_a * pattern_b * 32 * HEIGHT // 16
        with open(file, 'w') as f:
            pattern_bin = format((product + (1 << 24)) % (1 << 24), '024b')
            repeated = pattern_bin * 16
            for _ in range(height):
                f.write(repeated + '\n')

    elif mode == 'int4':
        product = pattern_a * pattern_b * 64 * HEIGHT // 16
        with open(file, 'w') as f:
            for _ in range(height):
                pattern_bin = format((product + (1 << 24)) % (1 << 24), '024b')
                repeated = pattern_bin * 16
                for _ in range(height):
                    f.write(repeated + '\n')
    else:
        raise ValueError("mode must be either 'int8' or 'int4'")

# 主流程
if __name__ == '__main__':
    generate_buffer(A_FILE, A_PATTERN, HEIGHT, 'int8')
    generate_buffer(B_FILE, B_PATTERN, HEIGHT, 'int8')
    generate_output(OUTPUTFILE, A_PATTERN, B_PATTERN, HEIGHT, 'int8')

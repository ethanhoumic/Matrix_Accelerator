import random
from collections import deque

A_PATTERN = 24
B_PATTERN = 24
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

def generate_linear_pattern(file, start, end, step, mode, scale_factor=0):
    """Generate a linear pattern buffer."""
    if mode == 'int8':
        with open(file, 'w') as f:
            if (end - start + 1) / step != 32:
                raise ValueError("The range must be evenly divisible by 32 for int8 mode")
            for h in range(HEIGHT):
                pattern_bin = ''
                for value in range(start, end, step):
                    if not (-128 <= value <= 127):
                        raise ValueError("value must be between -128 and 127 for signed int8 mode")
                    pattern_bin += format((value + (1 << 8)) % (1 << 8), '08b')
                full_pattern = pattern_bin + '00000000'
                f.write(full_pattern + '\n')

    elif mode == 'int4':
        with open(file, 'w') as f:
            if (end - start + 1) / step != 64:
                raise ValueError("The range must be evenly divisible by 64 for int4 mode")
            for h in range(HEIGHT):
                pattern_bin = ''
                for value in range(start, end, step):
                    if not (-8 <= value <= 7):
                        raise ValueError("value must be between -8 and 7 for signed int4 mode")
                    pattern_bin = format((value + (1 << 4)) % (1 << 4), '04b')
                scale_bin = format(scale_factor, '08b')
                repeated = pattern_bin + scale_bin
                f.write(repeated + '\n')

    else:
        raise ValueError("mode must be either 'int8' or 'int4'")

# 主流程
if __name__ == '__main__':
    generate_linear_pattern(A_FILE, 1, 32, 1, 'int8')
    generate_linear_pattern(B_FILE, 1, 32, 1, 'int8')

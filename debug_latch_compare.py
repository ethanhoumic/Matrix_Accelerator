def read_latch_file(path):
    with open(path) as f:
        return [line.strip() for line in f.readlines()]

def compare_outputs(py_lines, rtl_lines):
    assert len(py_lines) == len(rtl_lines) == 16, "Each output must have 16 lines (one per bank)"
    mismatches = []
    for bank in range(16):
        for counter in range(16):
            py_val = py_lines[bank][counter*24:(counter+1)*24]
            rtl_val = rtl_lines[bank][counter*24:(counter+1)*24]
            if py_val != rtl_val:
                mismatches.append((bank, counter, py_val, rtl_val))
    return mismatches

def print_debug(mismatches):
    for bank, counter, py_val, rtl_val in mismatches:
        print(f"Mismatch at Bank {bank}, Counter {counter}")
        print(f"  Python : {py_val}")
        print(f"  Verilog: {rtl_val}")
        diff = ''.join('^' if a != b else ' ' for a, b in zip(py_val, rtl_val))
        print(f"           {diff}\n")

if __name__ == '__main__':
    python_out = read_latch_file("output_sram_binary.txt")
    verilog_out = read_latch_file("latch_array_output.txt")
    mismatches = compare_outputs(python_out, verilog_out)

    if not mismatches:
        print("All outputs match!")
    else:
        print(f"Found {len(mismatches)} mismatches:")
        print_debug(mismatches)

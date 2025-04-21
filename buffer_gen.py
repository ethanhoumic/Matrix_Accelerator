import random
from collections import deque

# 常數設定
A_WIDTH = 264
B_WIDTH = 264
BANKS = 16
CYCLES = 128
ELEMENTS = 33
COUNTER_MOD = 16

# 隨機生成指定長度的二進位字串
def generate_bin_string(n):
    return ''.join(random.choice('01') for _ in range(n))

# 產生 A 與 B 的 SRAM 輸入檔案
def generate_input_files():
    with open("a_sram_binary.txt", "w") as fa, open("b_sram_binary.txt", "w") as fb:
        for _ in range(BANKS * CYCLES):
            fa.write(generate_bin_string(A_WIDTH) + "\n")
            fb.write(generate_bin_string(B_WIDTH) + "\n")

# 讀取檔案並回傳為字串列表
def read_input_file(path):
    with open(path, 'r') as f:
        return [line.strip() for line in f.readlines()]

# 將結果寫入輸出檔案
def write_output_file(path, lines):
    with open(path, 'w') as f:
        for line in lines:
            f.write(line + '\n')

# 模擬一般 MAC（乘加）邏輯，支援延遲寫入機制
def simulate_mac(a_buffer, b_buffer):
    latch_array = [[0] * COUNTER_MOD for _ in range(BANKS)]
    pending_queue = deque()

    for cycle in range(CYCLES):
        # 取得 A 各 bank 的資料（33 個 int8）
        a_vectors = [
            [int(a_buffer[cycle * BANKS + bank][i * 8:(i + 1) * 8], 2) for i in range(ELEMENTS)]
            for bank in range(BANKS)
        ]

        for counter in range(COUNTER_MOD):
            # 處理上一輪延遲寫入的結果
            while pending_queue:
                bank, idx, val = pending_queue.popleft()
                latch_array[bank][idx] = val

            # 取得 B 各 counter 對應的資料（33 個 int8）
            b_bits = b_buffer[cycle * BANKS + counter]
            b_vector = [int(b_bits[i * 8:(i + 1) * 8], 2) for i in range(ELEMENTS)]

            # 計算 dot product 並進行累加
            for bank in range(BANKS):
                acc = latch_array[bank][counter]
                dot = sum(a_vectors[bank][i] * b_vector[i] for i in range(ELEMENTS))
                result = (acc + dot) & 0xFFFFFF
                pending_queue.append((bank, counter, result))

    # 處理最後剩下的延遲寫入
    while pending_queue:
        bank, idx, val = pending_queue.popleft()
        latch_array[bank][idx] = val

    # 格式化輸出
    return [
        ''.join(format(latch_array[bank][i], '024b') for i in range(COUNTER_MOD))
        for bank in range(BANKS)
    ]

# 模擬 VSQ 模式：特殊乘加邏輯
def simulate_mac_vsq(a_buffer, b_buffer):
    latch_array = [[0] * COUNTER_MOD for _ in range(BANKS)]
    pending_queue = deque()

    for cycle in range(CYCLES):
        # A 每個 bank 取前 8 bits 當作係數
        a_factors = [int(a_buffer[cycle * BANKS + bank][:8], 2) for bank in range(BANKS)]
        # B 取第 0 筆的前 8 bits 作為共享因子
        b_factor = int(b_buffer[cycle * BANKS][:8], 2)

        for counter in range(COUNTER_MOD):
            while pending_queue:
                bank, idx, val = pending_queue.popleft()
                latch_array[bank][idx] = val

            for bank in range(BANKS):
                acc = latch_array[bank][counter]
                product = (a_factors[bank] * b_factor) & 0xFF
                scaled = (acc * product) & 0x3FFFFF  # 限制為 22-bit
                result = (acc + scaled) & 0xFFFFFF
                pending_queue.append((bank, counter, result))

    while pending_queue:
        bank, idx, val = pending_queue.popleft()
        latch_array[bank][idx] = val

    return [
        ''.join(format(latch_array[bank][i], '024b') for i in range(COUNTER_MOD))
        for bank in range(BANKS)
    ]

# 主流程
if __name__ == '__main__':
    generate_input_files()
    a_buffer = read_input_file("a_sram_binary.txt")
    b_buffer = read_input_file("b_sram_binary.txt")

    # 可切換使用 simulate_mac 或 simulate_mac_vsq
    output_lines = simulate_mac_vsq(a_buffer, b_buffer)

    write_output_file("output_sram_binary.txt", output_lines)
    print("已產生: a_sram_binary.txt, b_sram_binary.txt, output_sram_binary.txt")

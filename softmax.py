import numpy as np

def approx_softmax_8bit(x):
    x = np.array(x, dtype=np.float32)
    max_val = np.max(x)
    shifted_x = 0.5 ** (-1 * x + max_val)
    exp_sum = np.sum(shifted_x)
    return shifted_x * 255 / exp_sum

def softmax(x):
    max_val = np.max(x)
    shifted_x = np.exp(x - max_val)
    exp_sum = np.sum(shifted_x)
    return shifted_x * 255 / exp_sum

# Test cases
test_cases = [
    [120, 120, 121, 121, 122, 122, 123, 123, 124, 124, 125, 125, 126, 126, 127, 127]
]

for i, x in enumerate(test_cases):
    print(f"Test case {i+1}:")
    print("Input:", x)
    print("Approx. Softmax output:", np.round(approx_softmax_8bit(x), 0))
    print("Softmax output:", np.round(softmax(x), 4))
# Matrix Accelerator
Recreating the DNN inference accelerator proposed in [1]. 

## Usage

Please make sure the below hierarchy is satisfied:

<pre>
project
├── data_files
│    ├──── A_correct.txt
│    ├──── A_int4_fp8.txt
│    ├──── A_int4_vsq.txt
│    ├──── A_int4.txt
│    ├──── A_int8_fp8.txt
│    ├──── A_int8.txt
│    ├──── A_vsq_fp8.txt
│    ├──── (all above files with A replaced by B)
│    ├──── bias_int4.txt
│    ├──── bias_int8.txt
│    └──── cmd.txt
├── final_testbench.v
├── mac_acc_testbench.v
├── mac_16.v
├── int4_mac.v
├── int8_mac.v
├── ppu.v
├── license.cshrc
└── vsq_support.v
</pre>

Then, run the follow lines:

<pre>
source license.cshrc
vcs -sverilog -full64 -debug_access final_testbench.v -o simv
./simv
</pre>

This will print the results of quantized data and softmax values. 

P.S. I apologize for the bad output format. I didn't figure out a good way to display the outcomes in terminal.

If you want to take a look at the results of accumulation collector, run the following lines:

<pre>
source license.cshrc
vcs -sverilog -full64 -debug_access mac_acc_testbench.v -o simv
./simv
</pre>

Each row of accumulation collector is stored in output buffer and displayed. 

## Reference
[1] B. Keller et al., "A 95.6-TOPS/W Deep Learning Inference Accelerator With Per-Vector Scaled 4-bit Quantization in 5 nm", *IEEE J. Solid-State Circuits*, vol. 58, no. 4, pp. 1129–1141, Apr. 2023.

[2] Steve Dai et al., *VS-QUANT: Per-Vector Scaled Quantization for Accurate Low-Precision Neural Network Inference*, NVIDIA, 2021. Available: https://arxiv.org/abs/2102.04503
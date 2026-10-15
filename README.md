# 32-bit IEEE-754 Floating-Point, Complex Arithmetic and CORDIC Math Accelerator in Verilog

This is a Verilog-2001 RTL implementation of a small reusable math accelerator. It has an explicit IEEE-754 single-precision datapath, a shared complex datapath, and a 28-iteration fixed-point CORDIC engine. The RTL contains no `real`, floating-point behavioral operators, vendor IP, or timing controls.

## Project layout

```text
rtl/       synthesizable datapaths and scheduler
tb/        block and top-level Verilog testbenches
vectors/   generated hexadecimal IEEE-754 test vectors
reference/ Python-only golden vector generator
scripts/   vector, simulation, and benchmark entry points
results/   verification and benchmark reports
```

## Interface and opcodes

`math_accelerator` accepts a request when `start && !busy`. `done` and `valid` are one-cycle completion pulses, and `result`/`result_imag` remain registered after completion.

| Opcode | Operation | Operand mapping |
|---:|---|---|
| 0 | FP_ADD | `A+B` |
| 1 | FP_SUB | `A-B` |
| 2 | FP_MUL | `A*B` |
| 3 | FP_MAC | `A*B+C` (non-fused) |
| 4 | C_ADD | `(A+jB)+(C+jD)` |
| 5 | C_SUB | `(A+jB)-(C+jD)` |
| 6 | C_MUL | `(A+jB)(C+jD)` |
| 7 | C_MAC | `(A+jB)(C+jD)+(E+jF)` |
| 8 | C_CONJ | `conj(A+jB)` |
| 9 | SIN | `sin(A)` |
| 10 | COS | `cos(A)` |
| 11 | ATAN2 | `atan2(A,B)` (`A=y`, `B=x`) |

`error[0]` is an invalid IEEE operation, `[1]` indicates NaN, `[2]` infinity, `[3]` overflow, `[4]` the underflow/inexact region, and `[5]` an invalid opcode. The arithmetic cores return canonical quiet NaN `7fc00000` for invalid operations.

## FP32 datapath

`fp32_unpack.v` extracts sign, exponent, fraction, and classification. Addition/subtraction performs:

1. effective exponent and hidden-bit insertion;
2. exponent comparison and 27-bit significand right-shift with sticky bit;
3. sign-magnitude add or subtract and magnitude/sign selection;
4. leading-bit normalization, including cancellation;
5. round-to-nearest-even using guard, round, and sticky bits;
6. overflow, subnormal, zero, and final packing in `fp32_round.v`.

Multiplication explicitly forms a 24x24 integer product, normalizes the 48-bit product, then shares the same round/pack block. NaN, infinity, infinity-times-zero, signed zero, overflow, underflow, and subnormal inputs are handled in the datapath.

MAC is deliberately a transparent **non-fused** pipeline: `fp32_mul` followed by `fp32_add`. This makes the resource reuse and the two rounding points explicit. A fused 48-bit accumulator could improve numerical accuracy but would require a different datapath and wider alignment logic.

## Complex datapath

Complex add/sub use two parallel scalar adders. Complex multiply uses four scalar multipliers and two scalar adders for `ac-bd` and `ad+bc`. Complex MAC adds two component accumulators after the same four-product tree. Conjugation is a sign-bit inversion on the imaginary component.

## CORDIC

`cordic.v` is an iterative rotation/vectoring engine. Angles are signed Q4.28 radians; Cartesian values are signed Q2.30. The arctangent table is a synthesizable case ROM with 28 entries. The rotation path applies quadrant reduction, starts with the inverse CORDIC gain constant, and returns sine or cosine. Vectoring negates a negative-x vector and applies the corresponding ±pi correction for `atan2`.

The convergence interval after quadrant reduction is `[-pi/2, +pi/2]`. Twenty-eight iterations give a residual angle on the order of `2^-28` radians; the external FP32 conversion and fixed-point quantization add at most a few final-bit ulps. The CORDIC testbench checks the core on zero, pi/4, and invalid zero-vector atan2; `reference/generate_vectors.py` also emits the requested pi/6, pi/4, pi/2, pi, and negative-angle cases.

## Scheduler and timing

`arithmetic_pipeline.v` is a real five-register streaming datapath. Stage 1 captures the command, stage 2 performs the explicit products, stage 3 performs component add/subtract operations, stage 4 performs MAC accumulation, and stage 5 registers the result/status. Its `valid` bit propagates through every stage, so the arithmetic pipeline can accept one command per clock when driven directly. The external command scheduler latches one request and holds `busy` until its response, providing a simple five-cycle command latency. CORDIC accepts one request, performs 28 iterative updates, and completes after the start/observation overhead (the supplied protocol benchmark records 30 cycles). Valid is propagated as a completion pulse and reset clears all state and outputs.

| Operation class | Measured latency | Measured command-port interval |
|---|---:|---:|
| FP add/sub/mul/MAC | 5 cycles | 6 cycles; 1/cycle inside pipeline |
| complex operations | 5 cycles | 6 cycles; 1/cycle inside pipeline |
| sin/cos/atan2 | 30 cycles | 31 cycles |

These values are from `tb/math_accelerator_tb.v` using a 10 ns clock and 100 samples per opcode. The one-cycle difference between latency and command-port interval is the required post-completion handshake edge. No FPGA/ASIC synthesis tool is assumed in this repository, so LUT, flip-flop, DSP, RAM, critical-path, and Fmax numbers are intentionally not fabricated.

## Verification

The Python reference uses Python only outside RTL to pack/unpack FP32 values and generate hexadecimal vectors. It includes edge values, special values, subnormals, boundary values, and 512 deterministic random pairs for scalar arithmetic. The Verilog testbenches cover scalar add, multiply, MAC, complex arithmetic, CORDIC control, and every top-level arithmetic dispatch path.

Run:

```sh
./scripts/run_tests.sh
./scripts/benchmark.sh
```

`run_tests.sh` uses Icarus Verilog when installed and always regenerates the vector files. The expected numerical report format is `tests`, `passed`, `failed`, `max_error`, and `average_error`; CORDIC comparisons use absolute/relative tolerances because it is an iterative fixed-point approximation.

## Demonstration workload

The FP_MAC opcode directly implements the vector kernel `Y[i] = A[i] * B[i] + C[i]` by repeatedly issuing requests while observing `busy/done`. C_MUL repeatedly implements complex vector multiplication, and SIN/COS requests evaluate a stream of angles. The input mapping and fixed operation latency make all three workloads straightforward to drive from a DMA or software command queue.

# Coder-Next — fork validation baseline

## Final base: 122880 context, utilization 0.92

The base now reserves headroom rather than maximizing bootable context.
At 0.95, formal stress recalled through 169348 tokens but FAILED its 1024 MB
margin gate (615 MB free). At 0.92, 131072 failed KV allocation; 122880 booted.
Formal stress then PASSED: boundary 5/5, recall 3/3 through 112927 tokens,
1337 MB free. Continuous soak PASSED 25/25 requests, zero errors/empty outputs,
zero VRAM growth, 100% throughput retention (median decode 152.33 tok/s).

Final canonical bench: 157.39 narrative / 156.92 code wall tok/s; prefill
8069.34 at 10K and 3067.68 at 90K; sampled peak 22790 / 22786 MiB.
Medium quality, thinking OFF, validity valid: tools 13/15, instructions 12/15,
structured output 15/15, extraction 10/15, math 10/15 (60/75 total).
These are this model's baseline, not a comparison against a thinking model.
Full behavioral suite and cross-rig validation remain outstanding; incubating
status is retained, including the expected verify-full reasoning-field failure.

Evidence: `/tmp/coder-base-validation/` files `stress-092-120k.log`,
`soak-092-120k.log`, `bench-092-120k.log`, `quality-092-120k.log`;
quality JSON `results/quality/quality-2026-09-18T12-03-35.json` and soak directory
`results/soak-20260918-115732`. The following sections preserve the earlier
0.95 capacity experiment; their context and performance are NOT base defaults.

## Historical capacity experiment: incubating, not production-qualified

Measured 2026-09-18 on @TreyThomasCodes's 2× RTX 3090 **with NVLink**, PCIe gen4 x8,
121.5 GiB host RAM, deliberate **250 W/card** caps. Not the reference PCIe-only rig.
Slug: `vllm/qwen3-coder-next-dual-int4`; endpoint `:8180`.
Intel AutoRound INT4 revision `79c8a6bb73b7946095d7ece1f8fc68535f7c9ab8`;
original weights unchanged, all 11 shards SHA-verified by setup.

Stock vLLM v0.29.0 plus the scoped AutoRound/INC router patch is required:
see [upstream tracker](../../docs/UPSTREAM.md#vllm-vllm-projectvllm).
The stock loader expects unquantized router weights and fails on `mlp.gate.qweight`.
The mounted installer checks the release and exact source block, fails closed
on drift, and is idempotent. No other quantization formats or shared-expert gates
are changed. The runtime source patch—not checkpoint conversion—cleared loading.

## Tested configuration

TP=2, BF16 KV, memory utilization 0.95, one sequence, 2048-token prefill chunks,
CUDA graphs on, no speculative decoding, no CPU offload. NVLink/custom all-reduce
engaged. Model allocation logged as 19.75 GiB/card; available KV about 2.16 GiB.
The capacity experiment used **184320**, the tested high-context baseline,
not a production safety margin. No curated model/default selection changed.
Non-thinking, text-only; server sampler is 1.0/.95/top-k 40/min-p 0.
Canonical bench explicitly overrides sampling to .6/.95/20/0.

## Capacity ladder

| Configured context | Probe | Result |
|---|---|---|
| 32768 | 27853 input, three retrieval markers | PASS |
| 65536 | 55705 input, three retrieval markers | PASS |
| 98304 | 83557 input, three retrieval markers | PASS |
| 131072 | Startup and models endpoint | Boot PASS; no near-limit probe |
| 184320 | 182271 input + 37 output | Retrieval PASS, 107.3 s total |
| 184320 | 178172 input + 4096 output | Sustained generation PASS, 130.5 s total |
| 196608 | Startup | FAIL: 2.29 GiB KV needed versus 2.16 GiB available |

192K failure estimated a maximum length of 184960; this is not an exact measured
ceiling. 184320 boot reported a 185388-token pool. Pool figures vary with context
and hybrid-cache allocation; do not extrapolate them as validated usable limits.
Largest probes peaked at **23512 / 23508 MiB** (sampled), not an OOM.

Prompts were repetitive filler with markers at beginning/middle/end, not real
repositories. The 4096-output test forced `min_tokens=4096, ignore_eos=true`:
its repetitive ending cannot establish normal-use degeneration. Generated queue
code had visible correctness issues and was not executed; capacity success is
not a coding-quality claim. At this stage no repeated soak or formal stress suite had been run; see final base results above.

## Functional and performance baseline

At 184320, verify-full passed serving, completion, tools, SSE, streamed tools,
and output stability. It exited nonzero on its reasoning-field expectation:
this model does not think. Genesis, speculative acceptance and vision skipped.
Benchmark was run after the user explicitly accepted that expected failure;
do not describe verification as unconditionally green.

Canonical bench: 3 warm + 5 measured narrative/code requests; 10K prefill n=3,
90K n=1. Wall throughput **157.60 narrative / 157.12 code tok/s**;
short TTFT **83 ms**; prefill **8050 tok/s at 10K**, **4864.67 at 90K**
(90K TTFT 18.5 s). Peak **23512 / 23508 MiB**. NVLink engaged.
See [benchmarks](../../BENCHMARKS.md#qwen3-coder-next--treythomascodes-fork-baseline).
No medium/full quality result, production promotion, or upstream PR yet.

## Evidence on rig

- `/tmp/coder-180k-eval/{verify.log,bench.log}`
- `/tmp/coder-180k-boot.log`, `/tmp/coder-192k-boot.log`
- `/tmp/coder-180k-nearlimit.log`, `/tmp/coder-184320/response.json`
- `/tmp/coder-180k-longgen.log`, `/tmp/coder-longgen-184320/response.json`

These are rig-local temporary artifacts, not repository attachments. Preserve
copies before cleanup or upstream submission. The capacity-trial container ran at 184320;
DavidAU remains stopped. Subsequent runtime state may differ from this baseline.

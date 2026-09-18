#!/usr/bin/env bash
set -euo pipefail
export PYTHONUTF8="${PYTHONUTF8:-1}"
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 - <<'PY'
import runpy
from pathlib import Path
import yaml
from scripts.lib.profiles.compat import load_profiles
from scripts.lib.profiles.compose_registry import COMPOSE_REGISTRY, DEFAULTS

slug = 'vllm/qwen3-coder-next-dual-int4'
e = COMPOSE_REGISTRY[slug]
m = load_profiles().models[e['model']]
assert (m.num_hidden_layers, m.num_gdn_layers, m.num_attn_layers) == (48, 36, 12)
assert (m.num_experts, m.num_experts_per_tok, m.num_kv_heads) == (512, 10, 2)
assert not m.vision_capable and not m.compatible_drafters
assert e['status'] == 'incubating' and e['drafter'] is None
assert e['max_ctx'] == 122880 and e['default_port'] == 8180
assert e['mem_util'] == 0.92
assert not any(key[0] == m.id for key in DEFAULTS)
w = m.weights[e['weights_variant']]
assert w['revision'] == '79c8a6bb73b7946095d7ece1f8fc68535f7c9ab8'
assert '*.jinja' in w['files'] and '*.json' in w['files']
compose = yaml.safe_load(Path(e['compose_path']).read_text(encoding='utf-8'))
service, = compose['services'].values()
cmd = service['command']
assert cmd[cmd.index('--tool-call-parser') + 1] == 'qwen3_coder'
assert cmd[cmd.index('--dtype') + 1] == 'bfloat16'
assert '--reasoning-parser' not in cmd and '--speculative-config' not in cmd
assert '--cpu-offload-gb' not in cmd
assert '"top_k":${TOP_K:-40}' in cmd[-1]
assert '"temperature":${TEMP:-${TEMPERATURE:-1.0}}' in cmd[-1]
calc = runpy.run_path('tools/kv-calc.py', run_name='coder_profile_test')
spec = calc['MODEL_SPECS'][m.id]
assert spec['num_attn_layers'] == 12 and spec['weights_total_gb'] == 43.52
patch = runpy.run_path('models/qwen3-coder-next/vllm/patches/autoround-router/install.py')
assert patch['patched'](patch['OLD']) == patch['NEW']
assert patch['patched'](patch['NEW']) == patch['NEW']
for source in ('unexpected upstream source', patch['OLD'] * 2):
    try:
        patch['patched'](source)
    except RuntimeError:
        pass
    else:
        raise AssertionError('router drift must fail closed')
assert 'python3 /etc/club3090/autoround-router/install.py' in service['entrypoint'][2]
print('PASS: Coder-Next profile and router patch/idempotency/drift guards')
PY

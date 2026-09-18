"""Pinned v0.29.0 AutoRound-only router fix. See docs/UPSTREAM.md."""
from pathlib import Path
import os
from importlib.metadata import version

OLD = '''        self.gate = ReplicatedLinear(
            config.hidden_size,
            config.num_experts,
            bias=False,
            quant_config=None,
            prefix=f"{prefix}.gate",
        )'''
NEW = OLD.replace('quant_config=None', 'quant_config=(quant_config if quant_config is not None and quant_config.get_name() in ("auto_round", "inc") else None)')

def patched(source):
    if source.count(NEW) == 1 and OLD not in source:
        return source
    if source.count(OLD) != 1 or NEW in source:
        raise RuntimeError('Router source drift; revalidate patch against engine pin')
    return source.replace(OLD, NEW)

if __name__ == '__main__':
    if version('vllm') != '0.29.0':
        raise RuntimeError('Router patch requires validated vLLM 0.29.0')
    import importlib.util
    root = Path(importlib.util.find_spec('vllm').origin).parent
    path = root / 'model_executor/models/qwen3_next.py'
    source = path.read_text(encoding='utf-8')
    result = patched(source)
    if result != source:
        temp = path.with_suffix('.router-tmp')
        temp.write_text(result, encoding='utf-8')
        os.replace(temp, path)
    print('[router] AutoRound/INC quantized router enabled; other formats unchanged')

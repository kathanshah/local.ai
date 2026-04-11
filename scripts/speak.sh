#!/usr/bin/env bash
# Quick TTS — speak text from argument or stdin
# Uses ElevenLabs if key is set, falls back to Piper
# Usage: echo "Hello" | bash scripts/speak.sh
#        bash scripts/speak.sh "Hello world"

if [ -n "$1" ]; then
    TEXT="$*"
else
    TEXT="$(cat)"
fi

[ -z "$TEXT" ] && exit 0

# Pass text safely via stdin to avoid shell injection
echo "$TEXT" | python3 << 'PYEOF'
import sys, os, subprocess, tempfile, re
from pathlib import Path

text = sys.stdin.read().strip()

# Clean markdown
text = re.sub(r'```[\s\S]*?```', '', text)
text = re.sub(r'`([^`]+)`', r'\1', text)
text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)
text = re.sub(r'\*([^*]+)\*', r'\1', text)
text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
text = text.strip()
if not text:
    sys.exit(0)

# Load API key from env or saved config
api_key = os.environ.get('ELEVEN_API_KEY') or os.environ.get('ELEVENLABS_API_KEY', '')
env_file = Path.home() / '.config/stocky-ai/.env'
if not api_key and env_file.exists():
    for line in env_file.read_text().splitlines():
        if line.startswith('ELEVEN_API_KEY='):
            api_key = line.split('=', 1)[1].strip().strip('"').strip("'")

if api_key:
    try:
        import numpy as np, sounddevice as sd
        from elevenlabs.client import ElevenLabs
        client = ElevenLabs(api_key=api_key)
        # Resolve "Rachel" voice name to ID
        voice_id = None
        for v in client.voices.get_all().voices:
            if v.name.lower() == 'rachel':
                voice_id = v.voice_id
                break
        if not voice_id:
            print('Could not find Rachel voice, using first available', file=sys.stderr)
            voices = client.voices.get_all().voices
            voice_id = voices[0].voice_id if voices else 'Rachel'
        audio = client.text_to_speech.convert(
            text=text, voice_id=voice_id,
            model_id='eleven_turbo_v2_5', output_format='pcm_22050')
        pcm = b''.join(audio)
        if pcm:
            sd.play(np.frombuffer(pcm, dtype='int16'), samplerate=22050)
            sd.wait()
        sys.exit(0)
    except Exception as e:
        print(f'ElevenLabs failed ({e}), falling back to Piper', file=sys.stderr)

# Fallback: Piper
voice = '/mnt/ai-models/piper-voices/en_US-amy-medium.onnx'
with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
    tmppath = f.name
try:
    subprocess.run(['piper', '--model', voice, '--output_file', tmppath],
                   input=text, capture_output=True, text=True)
    subprocess.run(['aplay', '-q', tmppath], capture_output=True)
finally:
    os.unlink(tmppath)
PYEOF

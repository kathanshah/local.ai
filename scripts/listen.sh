#!/usr/bin/env bash
# Record from mic with auto silence detection, transcribe with Whisper on GPU
# Usage: bash scripts/listen.sh [model]
# Default model: large-v3. Outputs transcribed text to stdout.

MODEL="${1:-large-v3}"

python3 << PYEOF
import numpy as np
import sounddevice as sd
import webrtcvad
import sys

RATE = 16000
FRAME_MS = 30
FRAME_SIZE = int(RATE * FRAME_MS / 1000)
SILENCE_TIMEOUT = 1.5
MIN_SPEECH = 0.5
MAX_RECORD_S = 60.0

vad = webrtcvad.Vad(2)
frames = []
speech_started = False
speech_start_idx = 0
silence_count = 0
silence_limit = int(SILENCE_TIMEOUT * 1000 / FRAME_MS)
min_frames = int(MIN_SPEECH * 1000 / FRAME_MS)
max_frames = int(MAX_RECORD_S * 1000 / FRAME_MS)
pre_buffer = int(0.3 * 1000 / FRAME_MS)
speech_count = 0
total = 0

print('[listening... speak now, auto-stops on silence]', file=sys.stderr)

try:
    with sd.InputStream(samplerate=RATE, channels=1, dtype='int16', blocksize=FRAME_SIZE) as stream:
        while total < max_frames:
            data, _ = stream.read(FRAME_SIZE)
            frames.append(data.copy())
            total += 1
            is_speech = vad.is_speech(data.tobytes(), RATE)
            if is_speech:
                if not speech_started:
                    speech_started = True
                    speech_start_idx = max(0, total - 1 - pre_buffer)
                    print('[hearing speech...]', file=sys.stderr)
                silence_count = 0
                speech_count += 1
            elif speech_started:
                silence_count += 1
                if silence_count >= silence_limit:
                    break
except KeyboardInterrupt:
    pass

if speech_count < min_frames:
    sys.exit(0)

trimmed = frames[speech_start_idx:]
audio = np.concatenate(trimmed).astype(np.float32) / 32768.0

from faster_whisper import WhisperModel
model = WhisperModel('${MODEL}', device='cuda', compute_type='float16')
segments, _ = model.transcribe(audio.flatten(), beam_size=5, language='en', vad_filter=True)
print(' '.join(s.text.strip() for s in segments))
PYEOF

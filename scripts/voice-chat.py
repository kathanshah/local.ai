#!/usr/bin/env python3
"""
Stocky AI Voice Chat — speak to Claude, hear it talk back.

Architecture:
  - STT: faster-whisper large-v3 on GPU (loaded once, stays in VRAM)
  - VAD: webrtcvad for automatic silence detection (no manual Ctrl+C needed)
  - LLM: Claude Code CLI (claude -p)
  - TTS: ElevenLabs streaming API (high quality, low latency)

Usage:
  python3 scripts/voice-chat.py
  python3 scripts/voice-chat.py --whisper-model medium.en  # lighter model
  python3 scripts/voice-chat.py --voice "Rachel"           # different voice
  python3 scripts/voice-chat.py --local-tts                # use Piper instead of ElevenLabs
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile
import time
import wave
from pathlib import Path

import numpy as np
import sounddevice as sd
import webrtcvad

# ── Config ──────────────────────────────────────────────────────────────────

SAMPLE_RATE = 16000          # whisper expects 16kHz
CHANNELS = 1
FRAME_DURATION_MS = 30       # webrtcvad frame size (10, 20, or 30 ms)
FRAME_SIZE = int(SAMPLE_RATE * FRAME_DURATION_MS / 1000)
VAD_AGGRESSIVENESS = 2       # 0-3, higher = more aggressive filtering

PIPER_VOICE = "/mnt/ai-models/piper-voices/en_US-amy-medium.onnx"
ENV_FILE = Path.home() / ".config" / "stocky-ai" / ".env"

# ElevenLabs defaults
DEFAULT_VOICE = "Rachel"
DEFAULT_MODEL = "eleven_turbo_v2_5"

# ── Colors ──────────────────────────────────────────────────────────────────

GREEN = "\033[0;32m"
BLUE = "\033[0;34m"
YELLOW = "\033[1;33m"
DIM = "\033[2m"
NC = "\033[0m"


def clean_markdown(text: str) -> str:
    """Strip markdown formatting for cleaner speech."""
    text = re.sub(r"```[\s\S]*?```", "", text)         # code blocks
    text = re.sub(r"`([^`]+)`", r"\1", text)            # inline code
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)      # bold
    text = re.sub(r"\*([^*]+)\*", r"\1", text)           # italic
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*[-*]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text) # links
    return text.strip()


def get_elevenlabs_key() -> str | None:
    """Get ElevenLabs API key from env or saved config."""
    key = os.environ.get("ELEVEN_API_KEY") or os.environ.get("ELEVENLABS_API_KEY")
    if key:
        return key

    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.startswith("ELEVEN_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")

    return None


def save_elevenlabs_key(key: str):
    """Save key for future sessions."""
    ENV_FILE.parent.mkdir(parents=True, exist_ok=True)
    ENV_FILE.write_text(f"ELEVEN_API_KEY={key}\n")
    ENV_FILE.chmod(0o600)
    print(f"{DIM}Key saved to {ENV_FILE}{NC}")


def setup_elevenlabs_key() -> str:
    """Prompt user for key if not found."""
    key = get_elevenlabs_key()
    if key:
        return key

    print(f"{YELLOW}ElevenLabs API key not found.{NC}")
    print("Get one at: https://elevenlabs.io/app/settings/api-keys")
    key = input("Paste your API key: ").strip()
    if not key:
        print("No key provided. Use --local-tts for offline mode.")
        sys.exit(1)
    save_elevenlabs_key(key)
    return key


# ── Whisper STT ─────────────────────────────────────────────────────────────

class WhisperSTT:
    """Persistent whisper model — loaded once, transcribes many."""

    def __init__(self, model_name: str = "large-v3"):
        from faster_whisper import WhisperModel
        print(f"{BLUE}Loading whisper {model_name} on GPU...{NC}", end=" ", flush=True)
        t0 = time.time()
        self.model = WhisperModel(model_name, device="cuda", compute_type="float16")
        print(f"{GREEN}done{NC} ({time.time() - t0:.1f}s)")

    def transcribe(self, audio: np.ndarray) -> str:
        """Transcribe numpy audio array (float32, 16kHz mono)."""
        segments, _ = self.model.transcribe(
            audio,
            beam_size=5,
            language="en",
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500),
        )
        return " ".join(seg.text.strip() for seg in segments).strip()


# ── VAD Recording ───────────────────────────────────────────────────────────

def record_with_vad(silence_timeout: float = 1.5, min_speech_s: float = 0.5,
                    max_record_s: float = 60.0) -> np.ndarray | None:
    """Record from mic, auto-stop when user finishes speaking.

    Returns trimmed audio starting ~0.3s before speech onset to avoid
    clipping the first word. Returns None if no speech detected.
    """
    vad = webrtcvad.Vad(VAD_AGGRESSIVENESS)
    audio_frames = []
    speech_started = False
    speech_start_idx = 0
    silence_frames = 0
    silence_limit = int(silence_timeout * 1000 / FRAME_DURATION_MS)
    min_speech_frames = int(min_speech_s * 1000 / FRAME_DURATION_MS)
    max_frames = int(max_record_s * 1000 / FRAME_DURATION_MS)
    pre_speech_buffer = int(0.3 * 1000 / FRAME_DURATION_MS)  # ~0.3s lead-in
    speech_frame_count = 0
    total_frames = 0

    print(f"{GREEN}🎤 Speak now...{NC} {DIM}(auto-detects when you stop){NC}")

    try:
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                            dtype="int16", blocksize=FRAME_SIZE) as stream:
            while total_frames < max_frames:
                frame_data, _ = stream.read(FRAME_SIZE)
                audio_frames.append(frame_data.copy())
                total_frames += 1

                is_speech = vad.is_speech(frame_data.tobytes(), SAMPLE_RATE)

                if is_speech:
                    if not speech_started:
                        speech_started = True
                        speech_start_idx = max(0, total_frames - 1 - pre_speech_buffer)
                        print(f"\r{GREEN}🎤 Listening...{NC}    ", end="", flush=True)
                    silence_frames = 0
                    speech_frame_count += 1
                elif speech_started:
                    silence_frames += 1
                    if silence_frames >= silence_limit:
                        break

    except KeyboardInterrupt:
        if not audio_frames:
            return None

    print()

    if speech_frame_count < min_speech_frames:
        return None

    # Trim to speech region (with lead-in buffer) to reduce whisper work
    trimmed = audio_frames[speech_start_idx:]
    audio = np.concatenate(trimmed).astype(np.float32) / 32768.0
    return audio.flatten()


# ── TTS Engines ─────────────────────────────────────────────────────────────

class ElevenLabsTTS:
    """Streaming TTS via ElevenLabs — starts playing before generation finishes."""

    def __init__(self, api_key: str, voice: str = DEFAULT_VOICE,
                 model: str = DEFAULT_MODEL):
        from elevenlabs.client import ElevenLabs
        self.client = ElevenLabs(api_key=api_key)
        self.voice_name = voice
        self.model = model
        self.voice_id = None  # resolved once below

        try:
            voices = self.client.voices.get_all()
            for v in voices.voices:
                if v.name.lower() == voice.lower():
                    self.voice_id = v.voice_id
                    break
            if not self.voice_id:
                voice_names = [v.name for v in voices.voices]
                print(f"{YELLOW}Voice '{voice}' not found. "
                      f"Available: {', '.join(voice_names[:10])}{NC}")
                if voices.voices:
                    self.voice_id = voices.voices[0].voice_id
                    self.voice_name = voices.voices[0].name
                print(f"{DIM}Using: {self.voice_name}{NC}")
        except Exception as e:
            print(f"{YELLOW}Warning: Could not list voices: {e}{NC}")
            self.voice_id = voice  # last resort: treat input as an ID

    def speak(self, text: str):
        """Generate TTS audio and play it."""
        if not text.strip():
            return

        clean = clean_markdown(text)
        if not clean:
            return

        try:
            audio_gen = self.client.text_to_speech.convert(
                text=clean,
                voice_id=self.voice_id,
                model_id=self.model,
                output_format="pcm_22050",
            )
            pcm_data = b"".join(audio_gen)
            if pcm_data:
                audio_array = np.frombuffer(pcm_data, dtype=np.int16)
                sd.play(audio_array, samplerate=22050)
                sd.wait()
        except Exception as e:
            print(f"{YELLOW}TTS error: {e}{NC}")


class PiperTTS:
    """Local TTS fallback using Piper."""

    def __init__(self, voice_path: str = PIPER_VOICE):
        self.voice_path = voice_path
        if not Path(voice_path).exists():
            print(f"{YELLOW}Piper voice not found at {voice_path}{NC}")

    def speak(self, text: str):
        if not text.strip():
            return
        clean = clean_markdown(text)
        if not clean:
            return
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as f:
            proc = subprocess.run(
                ["piper", "--model", self.voice_path, "--output_file", f.name],
                input=clean, capture_output=True, text=True,
            )
            if proc.returncode == 0:
                with wave.open(f.name, "rb") as wf:
                    sr = wf.getframerate()
                    data = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16)
                sd.play(data, samplerate=sr)
                sd.wait()


# ── Claude LLM ──────────────────────────────────────────────────────────────

def ask_claude(prompt: str) -> str:
    """Send prompt to Claude Code CLI and return response."""
    try:
        result = subprocess.run(
            ["claude", "-p", prompt],
            capture_output=True, text=True, timeout=120,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return f"Error: {result.stderr.strip()}"
    except subprocess.TimeoutExpired:
        return "Sorry, the request timed out."


# ── Main Loop ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Stocky AI Voice Chat")
    parser.add_argument("--whisper-model", default="large-v3",
                        help="Whisper model (tiny.en, base.en, small.en, medium.en, large-v3)")
    parser.add_argument("--voice", default=DEFAULT_VOICE,
                        help="ElevenLabs voice name (default: Rachel)")
    parser.add_argument("--local-tts", action="store_true",
                        help="Use Piper (local/free) instead of ElevenLabs")
    parser.add_argument("--silence-timeout", type=float, default=1.5,
                        help="Seconds of silence before auto-stop (default: 1.5)")
    parser.add_argument("--max-record", type=float, default=60.0,
                        help="Max recording duration in seconds (default: 60)")
    args = parser.parse_args()

    print(f"{YELLOW}{'='*50}{NC}")
    print(f"{YELLOW}  Stocky AI Voice Chat{NC}")
    print(f"{YELLOW}{'='*50}{NC}")
    print()

    # Load STT (stays in GPU memory)
    stt = WhisperSTT(args.whisper_model)

    # Load TTS
    if args.local_tts:
        tts = PiperTTS()
        print(f"{DIM}TTS: Piper (local){NC}")
    else:
        api_key = setup_elevenlabs_key()
        tts = ElevenLabsTTS(api_key, voice=args.voice)
        print(f"{DIM}TTS: ElevenLabs ({tts.voice_name}){NC}")

    print()
    print(f"{DIM}Just start talking — auto-detects when you stop.{NC}")
    print(f"{DIM}Say \"quit\" or \"exit\" to leave. Ctrl+C to force quit.{NC}")
    print()

    tts.speak("Ready. What can I help you with?")

    try:
        while True:
            audio = record_with_vad(
                silence_timeout=args.silence_timeout,
                max_record_s=args.max_record,
            )

            if audio is None:
                print(f"{DIM}Didn't catch that. Try again.{NC}")
                continue

            print(f"{BLUE}Transcribing...{NC}", end=" ", flush=True)
            t0 = time.time()
            text = stt.transcribe(audio)
            print(f"{DIM}({time.time() - t0:.1f}s){NC}")

            if not text:
                print(f"{DIM}Didn't catch that. Try again.{NC}")
                continue

            print(f"{GREEN}You:{NC} {text}")

            # Exit commands — normalize punctuation and whitespace
            normalized = text.strip().lower().rstrip(".,!?")
            if normalized in ("quit", "exit", "goodbye", "bye", "stop"):
                print(f"{YELLOW}Goodbye!{NC}")
                tts.speak("Goodbye!")
                break

            print(f"{BLUE}Thinking...{NC}", end=" ", flush=True)
            t0 = time.time()
            response = ask_claude(text)
            print(f"{DIM}({time.time() - t0:.1f}s){NC}")

            print(f"{BLUE}Claude:{NC} {response}")
            print()

            tts.speak(response)
            print()

    except KeyboardInterrupt:
        print(f"\n{YELLOW}Goodbye!{NC}")


if __name__ == "__main__":
    main()

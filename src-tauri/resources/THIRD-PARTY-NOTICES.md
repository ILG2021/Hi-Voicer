# Third-Party Runtime Notices

Hi-Voicer currently ships without a bundled GPU runtime. Local transcription models and the Sherpa-ONNX CPU runtime are prepared through the normal model setup flow.

CUDA support has been removed from the public product path because it requires NVIDIA-specific CUDA Toolkit and cuDNN dependencies that are difficult to distribute reliably for ordinary Windows users.

DirectML acceleration is experimental and must be validated per machine with diagnostics and CPU comparison before it is treated as a reliable path.

## FFmpeg

Hi-Voicer release packages include `ffmpeg.exe` and `ffprobe.exe` from the FFmpeg Windows release essentials builds provided by Gyan Doshi at https://www.gyan.dev/ffmpeg/builds/.

FFmpeg is a third-party multimedia framework. The bundled Gyan Windows builds are 64-bit static builds licensed as GPLv3. FFmpeg source code is available from https://github.com/FFmpeg/FFmpeg and project information is available at https://ffmpeg.org/.

Hi-Voicer does not modify FFmpeg. `ffplay.exe` is not bundled.
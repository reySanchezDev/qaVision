# FFmpeg Runtime

QAVision bundles `bin/ffmpeg.exe` for Windows video recording.

- Binary: `third_party/ffmpeg/bin/ffmpeg.exe`
- License file: `third_party/ffmpeg/bin/FFMPEG_LICENSE.txt`
- SHA-256: `1A65D5B0B10D8D9A81D2824A3538046A40ED3607C906B335A166ADD87613F705`

The Windows build installs the binary and license into `tools/ffmpeg` from the top-level `windows/CMakeLists.txt`. Keep that as the single packaging path to avoid duplicate or stale copies.

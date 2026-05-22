# QAVision

QAVision is a Windows-first Flutter desktop app for screen capture, project-based capture organization, quick annotations, recent captures, and video recording.

## Supported Platform

- Windows is the supported runtime target.
- Android, iOS, macOS, Linux, and Web folders may exist because the project was scaffolded by Flutter, but native capture and recording flows depend on Windows APIs and bundled FFmpeg.

## Local Validation

Run the same validation used during maintenance:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\validate.ps1
```

For a faster pass without producing a release build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\validate.ps1 -SkipBuild
```

The test suite should run serially:

```powershell
flutter test --concurrency 1
```

## FFmpeg

Video recording uses the FFmpeg binary stored in `third_party/ffmpeg/bin`. The Windows build installs it into `tools/ffmpeg` next to the app bundle together with its license file.

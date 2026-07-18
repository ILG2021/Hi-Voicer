use serde::Serialize;
use sherpa_onnx::{
    LinearResampler, OfflineParaformerModelConfig, OfflineQwen3ASRModelConfig, OfflineRecognizer,
    OfflineRecognizerConfig, OfflineSenseVoiceModelConfig, SileroVadModelConfig,
    VadModelConfig, VoiceActivityDetector,
};
use std::{
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
    sync::mpsc::{self, Receiver, SyncSender, TrySendError},
    thread,
};
use tauri::{AppHandle, Emitter};

const TARGET_SAMPLE_RATE: i32 = 16_000;
const VAD_WINDOW_SIZE: usize = 512;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct RealtimeTranscriptSegment {
    pub(crate) index: usize,
    pub(crate) start: f64,
    pub(crate) end: f64,
    pub(crate) text: String,
}

#[derive(Debug, Clone)]
pub(crate) struct RealtimeAsrResult {
    pub(crate) segments: Vec<RealtimeTranscriptSegment>,
    pub(crate) dropped_blocks: usize,
}

enum RealtimeCommand {
    Samples { samples: Vec<f32>, sample_rate: u32 },
    Flush,
}

#[derive(Clone)]
pub(crate) struct RealtimePcmSender {
    sender: SyncSender<RealtimeCommand>,
    dropped_blocks: Arc<AtomicUsize>,
}

impl RealtimePcmSender {
    pub(crate) fn try_send(&self, samples: Vec<f32>, sample_rate: u32) -> bool {
        match self
            .sender
            .try_send(RealtimeCommand::Samples { samples, sample_rate })
        {
            Ok(()) => true,
            Err(TrySendError::Full(_)) => {
                self.dropped_blocks.fetch_add(1, Ordering::Relaxed);
                false
            }
            Err(TrySendError::Disconnected(_)) => false,
        }
    }
}

pub(crate) struct RealtimeAsrSession {
    sender: SyncSender<RealtimeCommand>,
    dropped_blocks: Arc<AtomicUsize>,
    join: Option<thread::JoinHandle<Result<RealtimeAsrResult, String>>>,
}

impl RealtimeAsrSession {
    pub(crate) fn pcm_sender(&self) -> RealtimePcmSender {
        RealtimePcmSender {
            sender: self.sender.clone(),
            dropped_blocks: self.dropped_blocks.clone(),
        }
    }

    pub(crate) fn finish(mut self) -> Result<RealtimeAsrResult, String> {
        let _ = self.sender.send(RealtimeCommand::Flush);
        self.join
            .take()
            .ok_or_else(|| "Realtime ASR worker was not running.".to_string())?
            .join()
            .map_err(|_| "Realtime ASR worker panicked.".to_string())?
    }
}

fn required(path: PathBuf, label: &str) -> Result<String, String> {
    if !path.exists() {
        return Err(format!("Realtime ASR is missing {label}: {}", path.display()));
    }
    path.to_str()
        .map(str::to_string)
        .ok_or_else(|| format!("Realtime ASR path is not valid UTF-8: {}", path.display()))
}

fn recognizer_config(model_dir: &Path) -> Result<OfflineRecognizerConfig, String> {
    let mut config = OfflineRecognizerConfig::default();
    let sensevoice = model_dir.join("model.int8.onnx");
    let paraformer_cmvn = model_dir.join("am.mvn");
    let qwen_conv = model_dir.join("conv_frontend.onnx");

    if sensevoice.exists() && paraformer_cmvn.exists() {
        config.model_config.paraformer = OfflineParaformerModelConfig {
            model: Some(required(sensevoice, "Paraformer model")?),
            ..Default::default()
        };
        config.model_config.tokens = Some(required(model_dir.join("tokens.txt"), "tokens")?);
        config.model_config.num_threads = 4;
        return Ok(config);
    }

    if sensevoice.exists() {
        config.model_config.sense_voice = OfflineSenseVoiceModelConfig {
            model: Some(required(sensevoice, "SenseVoice model")?),
            use_itn: true,
            ..Default::default()
        };
        config.model_config.tokens = Some(required(model_dir.join("tokens.txt"), "tokens")?);
        config.model_config.num_threads = 4;
        return Ok(config);
    }

    if qwen_conv.exists() {
        config.model_config.qwen3_asr = OfflineQwen3ASRModelConfig {
            conv_frontend: Some(required(qwen_conv, "Qwen3-ASR conv frontend")?),
            encoder: Some(required(
                model_dir.join("encoder.int8.onnx"),
                "Qwen3-ASR encoder",
            )?),
            decoder: Some(required(
                model_dir.join("decoder.int8.onnx"),
                "Qwen3-ASR decoder",
            )?),
            tokenizer: Some(required(
                model_dir.join("tokenizer"),
                "Qwen3-ASR tokenizer",
            )?),
            ..Default::default()
        };
        config.model_config.tokens = Some(required(model_dir.join("tokens.txt"), "tokens")?);
        config.model_config.num_threads = 3;
        return Ok(config);
    }

    Err(format!(
        "Realtime ASR supports SenseVoice, Paraformer, or sherpa-onnx Qwen3-ASR model directories; no supported model was found in {}",
        model_dir.display()
    ))
}

fn build_runtime(
    model_dir: &Path,
    vad_model: &Path,
) -> Result<(OfflineRecognizer, VoiceActivityDetector), String> {
    let recognizer = OfflineRecognizer::create(&recognizer_config(model_dir)?)
        .ok_or_else(|| "Failed to create the realtime sherpa-onnx recognizer.".to_string())?;

    let mut vad_config = VadModelConfig::default();
    vad_config.silero_vad = SileroVadModelConfig {
        model: Some(required(vad_model.to_path_buf(), "Silero VAD model")?),
        threshold: 0.5,
        min_silence_duration: 0.5,
        min_speech_duration: 0.25,
        window_size: VAD_WINDOW_SIZE as i32,
        max_speech_duration: 20.0,
        ..Default::default()
    };
    vad_config.sample_rate = TARGET_SAMPLE_RATE;
    vad_config.num_threads = 1;
    let vad = VoiceActivityDetector::create(&vad_config, 30.0)
        .ok_or_else(|| "Failed to create the Silero VAD runtime.".to_string())?;
    Ok((recognizer, vad))
}

fn decode_ready_segments(
    app: &AppHandle,
    recognizer: &OfflineRecognizer,
    vad: &VoiceActivityDetector,
    segments: &mut Vec<RealtimeTranscriptSegment>,
) {
    while let Some(segment) = vad.front() {
        let samples = segment.samples();
        if samples.len() >= 1_600 {
            let stream = recognizer.create_stream();
            stream.accept_waveform(TARGET_SAMPLE_RATE, samples);
            recognizer.decode(&stream);
            if let Some(result) = stream.get_result() {
                let text = result.text.trim().to_string();
                if !text.is_empty() {
                    let start = segment.start() as f64 / TARGET_SAMPLE_RATE as f64;
                    let item = RealtimeTranscriptSegment {
                        index: segments.len(),
                        start,
                        end: start + samples.len() as f64 / TARGET_SAMPLE_RATE as f64,
                        text,
                    };
                    let _ = app.emit("realtime-transcription-segment", item.clone());
                    segments.push(item);
                }
            }
        }
        vad.pop();
    }
}

fn worker(
    app: AppHandle,
    recognizer: OfflineRecognizer,
    vad: VoiceActivityDetector,
    receiver: Receiver<RealtimeCommand>,
    dropped_blocks: Arc<AtomicUsize>,
) -> Result<RealtimeAsrResult, String> {
    let mut input_rate = 0u32;
    let mut resampler: Option<LinearResampler> = None;
    let mut vad_buffer = Vec::<f32>::new();
    let mut segments = Vec::new();

    while let Ok(command) = receiver.recv() {
        match command {
            RealtimeCommand::Samples {
                samples,
                sample_rate,
            } => {
                if input_rate != sample_rate {
                    input_rate = sample_rate;
                    resampler = if sample_rate == TARGET_SAMPLE_RATE as u32 {
                        None
                    } else {
                        LinearResampler::create(sample_rate as i32, TARGET_SAMPLE_RATE)
                    };
                    if sample_rate != TARGET_SAMPLE_RATE as u32 && resampler.is_none() {
                        return Err(format!("Failed to resample realtime audio from {sample_rate} Hz."));
                    }
                }
                let samples = if let Some(resampler) = resampler.as_ref() {
                    resampler.resample(&samples, false)
                } else {
                    samples
                };
                vad_buffer.extend_from_slice(&samples);
                while vad_buffer.len() >= VAD_WINDOW_SIZE {
                    vad.accept_waveform(&vad_buffer[..VAD_WINDOW_SIZE]);
                    vad_buffer.drain(..VAD_WINDOW_SIZE);
                    decode_ready_segments(&app, &recognizer, &vad, &mut segments);
                }
            }
            RealtimeCommand::Flush => break,
        }
    }

    if !vad_buffer.is_empty() {
        vad_buffer.resize(VAD_WINDOW_SIZE, 0.0);
        vad.accept_waveform(&vad_buffer);
    }
    vad.flush();
    decode_ready_segments(&app, &recognizer, &vad, &mut segments);
    Ok(RealtimeAsrResult {
        segments,
        dropped_blocks: dropped_blocks.load(Ordering::Relaxed),
    })
}

pub(crate) fn start_realtime_asr(
    app: AppHandle,
    model_dir: PathBuf,
    vad_model: PathBuf,
) -> Result<RealtimeAsrSession, String> {
    // Validate before audio capture starts so a missing model cannot silently
    // turn a dictation session into a recording-only session.
    let (recognizer, vad) = build_runtime(&model_dir, &vad_model)?;
    let (sender, receiver) = mpsc::sync_channel(64);
    let dropped_blocks = Arc::new(AtomicUsize::new(0));
    let worker_dropped_blocks = dropped_blocks.clone();
    let join = thread::spawn(move || {
        worker(
            app,
            recognizer,
            vad,
            receiver,
            worker_dropped_blocks,
        )
    });
    Ok(RealtimeAsrSession {
        sender,
        dropped_blocks,
        join: Some(join),
    })
}

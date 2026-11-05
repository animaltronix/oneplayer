// makeloop <input> <startSec> <loopSec> <fadeSec> <targetRmsDb> <output.wav>
// Cuts loopSec+fadeSec from startSec, crossfades the tail into the head (equal power) so the result
// loops seamlessly, normalizes to a target RMS (peaks capped at -1 dBFS), writes 16-bit WAV.
import AVFoundation

let a = CommandLine.arguments
guard a.count == 7 else { print("usage: makeloop in start loop fade rmsDb out"); exit(2) }
let inURL = URL(fileURLWithPath: a[1]), outURL = URL(fileURLWithPath: a[6])
let start = Double(a[2])!, loopSec = Double(a[3])!, fadeSec = Double(a[4])!, targetDb = Double(a[5])!

let file = try AVAudioFile(forReading: inURL)
let fmt = file.processingFormat
let sr = fmt.sampleRate, ch = Int(fmt.channelCount)
let L = Int(loopSec * sr), F = Int(fadeSec * sr)
file.framePosition = AVAudioFramePosition(start * sr)
let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(L + F))!
try file.read(into: buf, frameCount: AVAudioFrameCount(L + F))
guard Int(buf.frameLength) == L + F else { print("short read"); exit(1) }

let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(L))!
out.frameLength = AVAudioFrameCount(L)
var sumSq = 0.0, peak: Float = 0
for c in 0..<ch {
  let src = buf.floatChannelData![c], dst = out.floatChannelData![c]
  for i in 0..<L {
    var v = src[i]
    if i < F {
      let t = Double(i) / Double(F)
      v = Float(sin(t * .pi / 2)) * src[i] + Float(cos(t * .pi / 2)) * src[L + i]
    }
    dst[i] = v
    sumSq += Double(v * v); peak = max(peak, abs(v))
  }
}
let rms = sqrt(sumSq / Double(L * ch))
let gain = pow(10, targetDb / 20) / rms
for c in 0..<ch { let d = out.floatChannelData![c]; for i in 0..<L { d[i] *= Float(gain) } }

// Peak limiter at -1 dBFS: 5 ms look-ahead (instant attack), 150 ms release, computed around the loop
// so the loop point stays seamless. Only touches transients such as fire crackles.
let thr: Float = pow(10, -1.0 / 20)
var need = [Float](repeating: 1, count: L)
for i in 0..<L { var m: Float = 0; for c in 0..<ch { m = max(m, abs(out.floatChannelData![c][i])) }; if m > thr { need[i] = thr / m } }
let la = Int(0.005 * sr), rel = Float(exp(-1.0 / (0.15 * sr)))
var g = [Float](repeating: 1, count: L)
var cur: Float = 1
for pass in 0..<2 {   // second pass so the envelope wraps across the loop point
  for i in 0..<L {
    var target: Float = 1
    for k in 0...la { target = min(target, need[(i + k) % L]) }
    cur = target < cur ? target : min(target, 1 - (1 - cur) * rel)   // instant down, slow recovery
    if pass == 1 { g[i] = cur }
  }
}
var reduced = 0
for i in 0..<L where g[i] < 0.99 { reduced += 1 }
for c in 0..<ch { let d = out.floatChannelData![c]; for i in 0..<L { d[i] *= g[i] } }
print(String(format: "  limiter active on %.1f%% of samples, deepest %.1f dB", 100 * Double(reduced) / Double(L),
             20 * log10(Double(g.min()!))))

// Loudness per 5 s, to spot sudden events in the chosen section
var env: [String] = []
for s in stride(from: 0, to: L, by: Int(5 * sr)) {
  var q = 0.0; let e = min(L, s + Int(5 * sr))
  for c in 0..<ch { let d = out.floatChannelData![c]; for i in s..<e { q += Double(d[i] * d[i]) } }
  env.append(String(format: "%.0f", 10 * log10(q / Double((e - s) * ch))))
}
print(String(format: "%@  sr=%.0f ch=%d  gain=%+.1f dB  rms5s(dB)=[%@]", inURL.lastPathComponent, sr, ch,
             20 * log10(gain), env.joined(separator: " ")))

let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sr, AVNumberOfChannelsKey: ch,
                               AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
// Write inside a function so the file is released (and its header finalized) before the program exits
func save() throws {
  let w = try AVAudioFile(forWriting: outURL, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
  try w.write(from: out)
}
try save()

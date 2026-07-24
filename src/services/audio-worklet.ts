const audioWorkletCode = `
class PcmProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.port.onmessage = (e) => {
      if (e.data === 'close') this.port.close();
    };
  }

  process(inputs) {
    const input = inputs[0];
    if (input.length > 0) {
      const channelData = input[0];
      const pcmData = new Int16Array(channelData.length);
      for (let i = 0; i < channelData.length; i++) {
        const s = Math.max(-1, Math.min(1, channelData[i]));
        pcmData[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
      }
      this.port.postMessage(pcmData.buffer, [pcmData.buffer]);
    }
    return true;
  }
}

registerProcessor('pcm-processor', PcmProcessor);
`;

export function createAudioWorkletBlobUrl(): string {
  const blob = new Blob([audioWorkletCode], { type: 'application/javascript' });
  return URL.createObjectURL(blob);
}
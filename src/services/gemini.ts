import {
  GoogleGenAI,
  ThinkingLevel,
  Type,
  Modality,
  createPartFromFunctionResponse,
} from "@google/genai";
import { executeTool } from "./tools";
import { BEATRICE_CHAT_PROMPT, BEATRICE_VOICE_PROMPT } from "./beatricePersona";

const apiKey =
  process.env.NEXT_PUBLIC_GEMINI_API_KEY || process.env.GEMINI_API_KEY;
const ai = apiKey ? new GoogleGenAI({ apiKey }) : null;

export const models = {
  chat: "gemini-2.5-flash",
  fast: "gemini-2.5-flash",
  image: "gemini-3.1-flash-image-preview",
  imageBasic: "gemini-2.5-flash-image",
  imagePro: "gemini-3-pro-image-preview",
  audio: "gemini-3-flash-preview",
  tts: "gemini-2.5-flash-preview-tts",
  live: "gemini-3.1-flash-live-preview",
};

const BEATRICE_VOICE_NAME = "Kore";

const VOICE_PERSONALITY_PROMPT_BODY = BEATRICE_VOICE_PROMPT;

export const SYSTEM_PROMPT = BEATRICE_CHAT_PROMPT;

export function createChat(
  systemInstruction: string,
  tools: any[] = [],
  userContext = "",
  responseStyle = "",
  modelOverride?: string,
) {
  if (!ai) throw new Error("API key not configured");

  let finalSystemPrompt = systemInstruction;
  if (userContext) {
    finalSystemPrompt += `\n\nUser Context (What you should know about the user):\n${userContext}`;
  }
  if (responseStyle) {
    finalSystemPrompt += `\n\nResponse Style (How you should respond):\n${responseStyle}`;
  }

  const config: Record<string, unknown> = {
    systemInstruction: finalSystemPrompt,
  };
  if (tools.length > 0) {
    config.tools = [{ functionDeclarations: tools }, { googleSearch: {} }];
  }
  return ai.chats.create({
    model: modelOverride || models.chat,
    config,
  });
}

export async function* generateChatResponseStream(
  prompt: string,
  history: any[] = [],
  useThinking = false,
  useFast = false,
  userContext = "",
  responseStyle = "",
  tools: any[] = [],
  modelOverride?: string,
) {
  if (!ai) throw new Error("API key not configured");

  const chat = createChat(SYSTEM_PROMPT, tools, userContext, responseStyle, modelOverride);
  let message: string | import("@google/genai").Part[] = prompt;

  while (true) {
    const stream = await chat.sendMessageStream({ message });
    let lastChunk: {
      functionCalls?: Array<{
        id?: string;
        name?: string;
        args?: Record<string, unknown>;
      }>;
    } | null = null;

    for await (const chunk of stream) {
      lastChunk = chunk;
      yield {
        text: chunk.text,
        groundingMetadata: chunk.candidates?.[0]?.groundingMetadata,
        functionCalls: chunk.functionCalls,
      };
    }

    const functionCalls = lastChunk?.functionCalls;
    if (!functionCalls || functionCalls.length === 0) break;

    const parts = [];
    for (const fc of functionCalls) {
      try {
        const result = await executeTool(fc.name!, fc.args || {});
        parts.push(
          createPartFromFunctionResponse(fc.id || "fc", fc.name!, { result }),
        );
      } catch (err) {
        parts.push(
          createPartFromFunctionResponse(fc.id || "fc", fc.name!, {
            error: String(err),
          }),
        );
      }
    }
    message = parts;
  }
}

export async function generateChatResponse(
  prompt: string,
  history: any[] = [],
  useThinking = false,
  useFast = false,
  userContext = "",
  responseStyle = "",
  tools: any[] = [],
) {
  if (!ai) throw new Error("API key not configured");

  let finalSystemPrompt = SYSTEM_PROMPT;
  if (userContext) {
    finalSystemPrompt += `\n\nUser Context (What you should know about the user):\n${userContext}`;
  }
  if (responseStyle) {
    finalSystemPrompt += `\n\nResponse Style (How you should respond):\n${responseStyle}`;
  }

  const config: any = {
    systemInstruction: finalSystemPrompt,
  };
  if (tools.length > 0) {
    config.tools = [{ functionDeclarations: tools }, { googleSearch: {} }];
  }

  if (useThinking) {
    config.thinkingConfig = { thinkingLevel: ThinkingLevel.HIGH };
  }

  const response = await ai.models.generateContent({
    model: useFast ? models.fast : models.chat,
    contents: [...history, { role: "user", parts: [{ text: prompt }] }],
    config,
  });

  return {
    text: response.text,
    groundingMetadata: response.candidates?.[0]?.groundingMetadata,
  };
}

export async function generateImage(
  prompt: string,
  size: "1K" | "2K" | "4K" = "1K",
  aspectRatio: string = "1:1",
) {
  if (!ai) throw new Error("API key not configured");

  const isBasic = size === "1K" && aspectRatio === "1:1";
  const model = isBasic ? models.imageBasic : models.image;

  const config: any = {
    imageConfig: {
      aspectRatio: aspectRatio as any,
    },
  };

  if (!isBasic) {
    config.imageConfig.imageSize = size;
  }

  const response = await ai.models.generateContent({
    model: model,
    contents: [{ parts: [{ text: prompt }] }],
    config,
  });

  const imagePart = response.candidates?.[0]?.content?.parts.find(
    (p) => p.inlineData,
  );
  if (imagePart?.inlineData) {
    return `data:image/png;base64,${imagePart.inlineData.data}`;
  }
  return null;
}

export async function editImage(
  prompt: string,
  base64Data: string,
  mimeType: string,
) {
  if (!ai) throw new Error("API key not configured");

  const response = await ai.models.generateContent({
    model: models.imageBasic,
    contents: {
      parts: [{ inlineData: { data: base64Data, mimeType } }, { text: prompt }],
    },
  });

  const imagePart = response.candidates?.[0]?.content?.parts.find(
    (p) => p.inlineData,
  );
  if (imagePart?.inlineData) {
    return `data:image/png;base64,${imagePart.inlineData.data}`;
  }
  return null;
}

export async function analyzeImage(
  prompt: string,
  base64Data: string,
  mimeType: string,
) {
  if (!ai) throw new Error("API key not configured");

  const response = await ai.models.generateContent({
    model: models.chat,
    contents: {
      parts: [{ inlineData: { data: base64Data, mimeType } }, { text: prompt }],
    },
  });

  return response.text;
}

export async function textToSpeech(text: string) {
  if (!ai) throw new Error("API key not configured");

  const response = await ai.models.generateContent({
    model: models.tts,
    contents: [{ parts: [{ text }] }],
    config: {
      responseModalities: [Modality.AUDIO],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: { voiceName: BEATRICE_VOICE_NAME },
        },
      },
    },
  });

  const audioData =
    response.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;
  if (audioData) {
    return `data:audio/wav;base64,${audioData}`;
  }
  return null;
}

export async function transcribeAudio(base64Data: string, mimeType: string) {
  if (!ai) throw new Error("API key not configured");

  const response = await ai.models.generateContent({
    model: models.audio,
    contents: {
      parts: [
        { inlineData: { data: base64Data, mimeType } },
        { text: "Transcribe this audio exactly." },
      ],
    },
  });

  return response.text;
}

export function connectLive(
  onopen: (sessionPromise: Promise<any>) => void,
  onmessage: (message: any) => void,
  onerror: (error: any) => void,
  onclose: () => void,
  userContext = "",
  responseStyle = "",
) {
  if (!ai) throw new Error("API key not configured");

  let finalSystemPrompt = VOICE_PERSONALITY_PROMPT_BODY;
  if (userContext) {
    finalSystemPrompt += `\n\nUser Context (What you should know about the user):\n${userContext}`;
  }
  if (responseStyle) {
    finalSystemPrompt += `\n\nResponse Style (How you should respond):\n${responseStyle}`;
  }

  const sessionPromise = ai.live.connect({
    model: models.live,
    callbacks: {
      onopen: () => onopen(sessionPromise),
      onmessage,
      onerror,
      onclose,
    },
    config: {
      responseModalities: [Modality.AUDIO],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: { voiceName: BEATRICE_VOICE_NAME },
        },
      },
      systemInstruction: finalSystemPrompt,
      outputAudioTranscription: {},
      inputAudioTranscription: {},
    },
  });

  return sessionPromise;
}

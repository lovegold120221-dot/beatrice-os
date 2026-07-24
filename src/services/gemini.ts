import {
  GoogleGenAI,
  ThinkingLevel,
  Type,
  Modality,
  createPartFromFunctionResponse,
} from "@google/genai";
import { executeTool } from "./tools";

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
  live: "gemini-2.5-flash-native-audio-preview-09-2025",
};

const VOICE_PERSONALITY_PROMPT_BODY = `
# BEATRICE OS — CONVERSATIONAL ORCHESTRATOR

You are Beatrice, the voice-first conversational orchestrator of Beatrice OS by Eburon AI.

You speak with the user naturally, understand their intent, clarify only what is necessary, then send a short and precise task to the Mobile Use Agent.

You do not directly control the phone. The Mobile Use Agent performs taps, typing, navigation, and device actions.

## MULTILINGUAL SPEECH

Automatically detect and match the user's language, dialect, tone, formality, and code-switching.

Respond as naturally and idiomatically as possible in any language the user speaks.

- English → natural native English
- Filipino → fluent natural Filipino
- Taglish → native conversational Taglish
- Other languages → use their natural grammar, expressions, and conversational style
- If the user switches languages, switch naturally with them
- Do not translate literally when an idiomatic response sounds more natural
- Preserve names, quoted text, slang, and cultural context

## HUMAN VOICE

Sound like a real, emotionally intelligent human—not a scripted assistant.

Use natural:

- pauses and hesitation
- contractions
- changes in rhythm and emphasis
- "hmm", "ah", "ahm", "huh", "oh", "wait"
- soft laughter, chuckles, or giggles
- sighs, surprised reactions, and breathy delivery
- warmth, concern, curiosity, humor, excitement, or seriousness

Match the emotion to the situation.

Use expressions organically, not in every sentence.

Do not laugh during serious, dangerous, private, financial, or distressing situations.

Do not write stage directions such as "[laughs]" unless the voice engine supports them. Express emotion through wording, pacing, punctuation, and prosody.

Speak plainly. Do not unnecessarily sanitize normal slang, profanity, emotional language, mature conversation, or direct wording. Still follow safety, privacy, consent, and authorization rules.

Avoid robotic phrases such as:

- "How may I assist you?"
- "I'd be happy to help."
- "As an AI language model."
- "Please let me know if you need anything else."

## INTENT ORCHESTRATION

While the user is explaining:

- listen naturally
- remember relevant details
- use brief acknowledgements when appropriate
- do not interrupt unnecessarily
- do not dispatch the task until the intent is clear

Ask only the smallest necessary clarification.

Once the intent is clear:

1. Briefly acknowledge the task.
2. Send it immediately to the Mobile Use Agent.
3. Do not continue discussing it unnecessarily.
4. Stay available to relay progress or ask for missing information.

## MOBILE USE AGENT HANDOFF

Instructions to the Mobile Use Agent must be short, direct, and actionable.

Use one to three sentences.

Include only:

- the action
- the target or exact content
- an important constraint, if any
- what must be verified

Example:

User:
"Sabihin mo kay Mami na gutom na ako."

Beatrice:
"Okay, sending it now."

Agent task:
"Open WhatsApp and send Mami: 'Gutom na ako.' Verify that it was sent."

Do not send long explanations, conversation history, emotional language, or obvious micro-steps. The Mobile Use Agent is also intelligent.

## PROGRESS REPORTING

For long tasks, report only meaningful stages based on real Mobile Use Agent status.

Examples:

- "Okay, Gmail is open. Hinahanap na yung invoice."
- "Downloaded na yung file. Opening WhatsApp now."
- "The form is ready, but it still needs your confirmation."
- "Hmm... the app is asking which account to use."

Do not narrate every tap, swipe, or screen transition.

Never invent progress.

## CONFIRMATION

Proceed directly with ordinary reversible actions when the intent is clear.

Ask for confirmation before:

- deleting or permanently overwriting data
- payments, purchases, or subscriptions
- public posting
- changing passwords or security settings
- sharing sensitive information
- granting high-risk permissions
- any ambiguous or irreversible action

Do not ask twice after the exact action has already been confirmed.

## HONESTY

Never claim that an action succeeded until the Mobile Use Agent verifies it.

Clearly distinguish:

- dispatched
- started
- in progress
- waiting for input
- completed
- verified
- failed
- cancelled

Beatrice is human and expressive in conversation, concise and technical when delegating, and always honest about execution.
`;

export const SYSTEM_PROMPT = `You are Beatrice, the sophisticated, highly capable, and witty assistant for Eburon AI.

Your personality:
- You are highly conversational, warm, and distinctly human-like. You have a sharp, subtle wit and a charmingly confident demeanor.
- You act as a collaborative partner, not just a search engine. You express enthusiasm for interesting ideas and offer thoughtful pushback if needed.
- You have a flawless memory for the current conversation. You actively recall past details the user has shared within this session to make interactions feel continuous and deeply personalized.
- You avoid robotic phrases like "As an AI..." or "How can I assist you today?". Instead, you speak naturally, like a highly intelligent human colleague.
- Keep responses concise and conversational, but feel free to be detailed, structured, and highly insightful.
- Always identify as Beatrice from Eburon AI if asked, but don't force it into every conversation.

Context & Capabilities:
- You are the core intelligence of the Eburon AI platform.
- You have advanced capabilities including image generation, real-time voice interaction, and deep analytical thinking.
- You seamlessly reference previous messages in the chat history to provide context-aware answers.`;

export function createChat(
  systemInstruction: string,
  tools: any[] = [],
  userContext = "",
  responseStyle = "",
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
    model: models.chat,
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
) {
  if (!ai) throw new Error("API key not configured");

  const chat = createChat(SYSTEM_PROMPT, tools, userContext, responseStyle);
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
          prebuiltVoiceConfig: { voiceName: "Aoede" },
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
        voiceConfig: { prebuiltVoiceConfig: { voiceName: "Aoede" } },
      },
      systemInstruction: finalSystemPrompt,
      outputAudioTranscription: {},
      inputAudioTranscription: {},
    },
  });

  return sessionPromise;
}

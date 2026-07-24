import { supabase } from "../lib/supabase";

export interface Memory {
  id?: string;
  user_id: string;
  content: string;
  category:
    | "user_preference"
    | "fact"
    | "context"
    | "instruction"
    | "emotion"
    | "relationship";
  created_at?: string;
  last_accessed?: string;
}

const MEMORY_CATEGORIES = [
  "user_preference",
  "fact",
  "context",
  "instruction",
  "emotion",
  "relationship",
] as const;

export async function storeMemory(
  userId: string,
  content: string,
  category: Memory["category"] = "context",
) {
  const { error } = await supabase.from("memories").upsert(
    {
      user_id: userId,
      content,
      category,
      created_at: new Date().toISOString(),
      last_accessed: new Date().toISOString(),
    },
    { onConflict: "user_id,content" },
  );

  if (error) {
    console.error("Failed to store memory:", error);
  }
}

export async function getMemories(
  userId: string,
  limit = 30,
): Promise<Memory[]> {
  const { data, error } = await supabase
    .from("memories")
    .select("*")
    .eq("user_id", userId)
    .order("last_accessed", { ascending: false })
    .limit(limit);

  if (error) {
    console.error("Failed to fetch memories:", error);
    return [];
  }

  return data || [];
}

export async function touchMemory(memoryId: string) {
  await supabase
    .from("memories")
    .update({ last_accessed: new Date().toISOString() })
    .eq("id", memoryId);
}

export async function deleteMemory(memoryId: string) {
  await supabase.from("memories").delete().eq("id", memoryId);
}

export async function extractAndStoreMemories(
  userId: string,
  userMessage: string,
  assistantMessage: string,
) {
  const combined = `User: ${userMessage}\nAssistant: ${assistantMessage}`;

  const preferencePatterns = [
    /(?:i prefer|i like|i love|i hate|i want|i need|i always|i never|i usually)/i,
    /(?:don't|do not|never|always|please|make sure|remember that)/i,
    /(?:my name is|i'm|i am|call me)/i,
    /(?:favorite|best|worst|favorite)/i,
  ];

  const instructionPatterns = [
    /(?:how (?:do|should|can) i|teach me|show me|walk me through)/i,
    /(?:set up|configure|install|deploy|create|build)/i,
    /(?:fix|debug|repair|troubleshoot)/i,
  ];

  const emotionPatterns = [
    /(?:i feel|i'm feeling|frustrated|happy|excited|confused|annoyed|thank)/i,
  ];

  const relationshipPatterns = [
    /(?:my team|my boss|my client|my friend|my family|my colleague)/i,
    /(?:we are|our company|our team|our project)/i,
  ];

  const facts = combined.match(
    /\b(?:is|are|was|were|has|have|had|uses|works with|runs on|deployed to|configured for)\b[^.!?]+[.!?]/gi,
  );

  const memories: { content: string; category: Memory["category"] }[] = [];

  if (preferencePatterns.some((p) => p.test(combined))) {
    const sentences = combined.split(/[.!?]+/).filter((s) =>
      preferencePatterns.some((p) => p.test(s)),
    );
    for (const s of sentences.slice(0, 2)) {
      const trimmed = s.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        memories.push({ content: trimmed, category: "user_preference" });
      }
    }
  }

  if (instructionPatterns.some((p) => p.test(combined))) {
    const sentences = combined.split(/[.!?]+/).filter((s) =>
      instructionPatterns.some((p) => p.test(s)),
    );
    for (const s of sentences.slice(0, 2)) {
      const trimmed = s.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        memories.push({ content: trimmed, category: "instruction" });
      }
    }
  }

  if (emotionPatterns.some((p) => p.test(combined))) {
    const sentences = combined.split(/[.!?]+/).filter((s) =>
      emotionPatterns.some((p) => p.test(s)),
    );
    for (const s of sentences.slice(0, 1)) {
      const trimmed = s.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        memories.push({ content: trimmed, category: "emotion" });
      }
    }
  }

  if (relationshipPatterns.some((p) => p.test(combined))) {
    const sentences = combined.split(/[.!?]+/).filter((s) =>
      relationshipPatterns.some((p) => p.test(s)),
    );
    for (const s of sentences.slice(0, 1)) {
      const trimmed = s.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        memories.push({ content: trimmed, category: "relationship" });
      }
    }
  }

  if (facts) {
    for (const f of facts.slice(0, 3)) {
      const trimmed = f.trim();
      if (trimmed.length > 10 && trimmed.length < 200) {
        memories.push({ content: trimmed, category: "fact" });
      }
    }
  }

  const seen = new Set<string>();
  for (const m of memories) {
    const key = m.content.toLowerCase().trim();
    if (!seen.has(key)) {
      seen.add(key);
      await storeMemory(userId, m.content, m.category);
    }
  }
}

export function buildMemoryContext(memories: Memory[]): string {
  if (memories.length === 0) return "";

  const grouped: Record<string, string[]> = {};
  for (const m of memories) {
    const cat = m.category;
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(m.content);
  }

  const labels: Record<string, string> = {
    user_preference: "User Preferences",
    fact: "Known Facts",
    context: "Context",
    instruction: "Instructions",
    emotion: "Emotional State",
    relationship: "Relationships",
  };

  const sections = Object.entries(grouped)
    .map(([cat, items]) => {
      const label = labels[cat] || cat;
      return `${label}:\n${items.map((i) => `- ${i}`).join("\n")}`;
    })
    .join("\n\n");

  return `\n\n## Long-Term Memory\nThe following are things you remember about this user from previous conversations:\n\n${sections}`;
}

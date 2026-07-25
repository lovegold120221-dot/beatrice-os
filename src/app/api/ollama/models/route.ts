import { NextResponse } from "next/server";

const baseUrl = (process.env.OLLAMA_BASE_URL ?? "http://127.0.0.1:11434").replace(
  /\/$/,
  "",
);

export async function GET() {
  try {
    const response = await fetch(`${baseUrl}/api/tags`, {
      cache: "no-store",
    });
    if (!response.ok) {
      return NextResponse.json(
        { models: [], error: "Ollama is unavailable" },
        { status: 502 },
      );
    }

    const payload = (await response.json()) as {
      models?: Array<{ name?: string }>;
    };
    const models = (payload.models ?? [])
      .map((model) => model.name)
      .filter((name): name is string => Boolean(name));

    return NextResponse.json({ models });
  } catch {
    return NextResponse.json(
      { models: [], error: "Ollama is unavailable" },
      { status: 502 },
    );
  }
}

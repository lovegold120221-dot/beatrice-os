import { supabase } from "../lib/supabase";
import { getDeviceId } from "./device";

export interface DeviceProfile {
  device_id: string;
  user_context: string;
  response_style: string;
  theme: string;
  ollama_model: string;
}

export async function saveDeviceProfile(profile: Partial<DeviceProfile>) {
  const deviceId = getDeviceId();
  const { error } = await supabase.from("device_profiles").upsert(
    {
      device_id: deviceId,
      ...profile,
      last_seen_at: new Date().toISOString(),
    },
    { onConflict: "device_id" },
  );

  if (error) {
    console.error("Failed to save device profile:", error);
  }
}

export async function loadDeviceProfile(): Promise<DeviceProfile | null> {
  const deviceId = getDeviceId();
  const { data, error } = await supabase
    .from("device_profiles")
    .select("*")
    .eq("device_id", deviceId)
    .single();

  if (error) {
    if (error.code !== "PGRST116") {
      console.error("Failed to load device profile:", error);
    }
    return null;
  }

  return data as DeviceProfile;
}

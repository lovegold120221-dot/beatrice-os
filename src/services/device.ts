export function getDeviceId(): string {
  const key = "eburon_device_id";
  let deviceId = localStorage.getItem(key);
  if (!deviceId) {
    const fingerprint = [
      navigator.userAgent,
      screen.width,
      screen.height,
      screen.colorDepth,
      navigator.language,
      Intl.DateTimeFormat().resolvedOptions().timeZone,
    ].join("|");

    let hash = 0;
    for (let i = 0; i < fingerprint.length; i++) {
      const char = fingerprint.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }

    deviceId = `device_${Math.abs(hash).toString(36)}_${Date.now().toString(36)}`;
    localStorage.setItem(key, deviceId);
  }
  return deviceId;
}

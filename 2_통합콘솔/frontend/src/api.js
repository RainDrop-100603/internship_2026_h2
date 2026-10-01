const API_BASE = import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:4317";
const WS_URL = import.meta.env.VITE_WS_URL || "ws://127.0.0.1:4317/ws";
const TOKEN = import.meta.env.VITE_API_TOKEN || "";

async function apiFetch(path, options = {}) {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "X-Console-Token": TOKEN,
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `요청 실패 (${res.status})`);
  }
  return res.json();
}

export function createTask(projectId, instruction) {
  return apiFetch("/api/tasks", {
    method: "POST",
    body: JSON.stringify({ projectId, instruction }),
  });
}

export function getAgentSettings() {
  return apiFetch("/api/settings");
}

export function saveAgentSettings(settings) {
  return apiFetch("/api/settings", {
    method: "POST",
    body: JSON.stringify({ settings }),
  });
}

export function listProjects() {
  return apiFetch("/api/projects");
}

export function createProject(name, projectPath) {
  return apiFetch("/api/projects", {
    method: "POST",
    body: JSON.stringify({ name, path: projectPath }),
  });
}

export function removeProject(projectId) {
  return apiFetch(`/api/projects/${projectId}/remove`, {
    method: "POST",
    body: JSON.stringify({ confirm: true, projectId }),
  });
}

export function getTaskStatus(taskId) {
  return apiFetch(`/api/tasks/${taskId}`);
}

export function abortTask(taskId) {
  return apiFetch(`/api/tasks/${taskId}/abort`, {
    method: "POST",
    body: JSON.stringify({ confirm: true, taskId }),
  });
}

export function getTaskDiff(taskId) {
  return apiFetch(`/api/tasks/${taskId}/diff`);
}

export function approveTask(taskId, diffHash, targetSha) {
  return apiFetch(`/api/tasks/${taskId}/approve`, {
    method: "POST",
    body: JSON.stringify({ confirm: true, taskId, diffHash, targetSha }),
  });
}

export function rejectTask(taskId, reason, diffHash, targetSha) {
  return apiFetch(`/api/tasks/${taskId}/reject`, {
    method: "POST",
    body: JSON.stringify({ confirm: true, taskId, reason, diffHash, targetSha }),
  });
}

export function cleanupTask(taskId) {
  return apiFetch(`/api/tasks/${taskId}/cleanup`, {
    method: "POST",
    body: JSON.stringify({ confirm: true, taskId }),
  });
}

export function openTaskFolder(taskId) {
  return apiFetch(`/api/tasks/${taskId}/open-folder`, {
    method: "POST",
  });
}

export function requestCodexReview(taskId, instruction) {
  return apiFetch(`/api/tasks/${taskId}/review`, {
    method: "POST",
    body: JSON.stringify({ instruction: instruction || "" }),
  });
}

export function requestRevision(taskId, instruction) {
  return apiFetch(`/api/tasks/${taskId}/revise`, {
    method: "POST",
    body: JSON.stringify({ instruction: instruction || "" }),
  });
}

export function getCodexReview(taskId) {
  return apiFetch(`/api/tasks/${taskId}/review`);
}

export function connectTaskSocket(onEvent) {
  const ws = new WebSocket(`${WS_URL}?token=${encodeURIComponent(TOKEN)}`);
  ws.addEventListener("message", (ev) => {
    try {
      onEvent(JSON.parse(ev.data));
    } catch {
      // ignore malformed frames
    }
  });
  ws.addEventListener("error", () => {
    console.warn("[api] websocket error — 백엔드가 실행 중인지 확인하세요.");
  });
  return ws;
}

import express from "express";
import cors from "cors";
import http from "node:http";
import { WebSocketServer } from "ws";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createSession, publishSession } from "./token.mjs";
import { getCurrentBranch } from "./git.mjs";
import { getSettings, getSettingsPayload, initSettings, updateSettings } from "./settings.mjs";
import {
  initProjects,
  registerProject,
  listProjects,
  getProject,
  removeProject,
  setProjectLastTask,
} from "./projects.mjs";
import {
  startTask,
  abortTask,
  approveTask,
  rejectTask,
  requestCodexReview,
  requestRevision,
  cleanupTaskArtifacts,
  openTaskFolder,
  getTask,
  isBusy,
  busyReason,
  projectRemovalBlockReason,
  serializeTask,
  initTaskManager,
} from "./taskManager.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 4317;
const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN || "http://localhost:5173";
const runtimeRoot = path.join(__dirname, "..", ".runtime");
const worktreesRoot = path.join(runtimeRoot, "worktrees");
const reviewsRoot = path.join(runtimeRoot, "reviews");

const session = createSession({ port: PORT });

initProjects(runtimeRoot);
initTaskManager(runtimeRoot);
initSettings(runtimeRoot);

const app = express();
app.use(express.json());
app.use(cors({ origin: FRONTEND_ORIGIN, methods: ["GET", "POST"] }));

function requireToken(req, res, next) {
  if (req.header("X-Console-Token") !== session.token) {
    return res.status(401).json({ error: "invalid token" });
  }
  next();
}

function requireDestructiveConfirmation(req, res, next) {
  if (req.body?.confirm !== true || req.body?.taskId !== req.params.id) {
    return res.status(400).json({ error: "confirm:true and matching taskId required" });
  }
  next();
}

function requireProjectRemovalConfirmation(req, res, next) {
  if (req.body?.confirm !== true || req.body?.projectId !== req.params.id) {
    return res.status(400).json({ error: "confirm:true and matching projectId required" });
  }
  next();
}

app.get("/api/health", (req, res) => res.json({ ok: true }));

app.get("/api/settings", requireToken, (req, res) => {
  res.json(getSettingsPayload());
});

app.post("/api/settings", requireToken, (req, res) => {
  try {
    res.json({ settings: updateSettings(req.body?.settings) });
  } catch (err) {
    res.status(400).json({ error: String(err?.message ?? err) });
  }
});

app.get("/api/projects", requireToken, (req, res) => {
  const projects = listProjects().map((project) => {
    const lastTask = project.lastTaskId ? getTask(project.lastTaskId) : null;
    return {
      id: project.id,
      name: project.name,
      path: project.path,
      lastTask: lastTask
        ? { id: lastTask.id, status: lastTask.status, review: lastTask.review ? { status: lastTask.review.status } : null }
        : null,
    };
  });
  res.json({ projects });
});

app.post("/api/projects", requireToken, async (req, res) => {
  const { name, path: projectPath } = req.body ?? {};
  try {
    const project = registerProject({ name, projectPath });
    res.json(project);
  } catch (err) {
    res.status(400).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/projects/:id/remove", requireToken, requireProjectRemovalConfirmation, (req, res) => {
  const project = getProject(req.params.id);
  if (!project) return res.status(404).json({ error: "not found" });

  const blockReason = projectRemovalBlockReason(project.id);
  if (blockReason) return res.status(409).json({ error: blockReason });

  removeProject(project.id);
  res.json({ removed: true, projectId: project.id });
});

app.get("/api/projects/:id/branch", requireToken, async (req, res) => {
  const project = getProject(req.params.id);
  if (!project) return res.status(404).json({ error: "not found" });
  try {
    const branch = await getCurrentBranch(project.path);
    res.json({ branch });
  } catch (err) {
    res.status(500).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks", requireToken, async (req, res) => {
  const { instruction, projectId, baseBranch } = req.body ?? {};
  if (!instruction || typeof instruction !== "string") {
    return res.status(400).json({ error: "instruction is required" });
  }
  const project = getProject(projectId);
  if (!project) {
    return res.status(400).json({ error: "유효한 projectId가 필요합니다." });
  }
  if (isBusy()) {
    return res.status(409).json({ error: busyReason() });
  }
  try {
    const task = await startTask(
      {
        instruction,
        projectId,
        projectPath: project.path,
        baseBranch,
        worktreesRoot,
        reviewsRoot,
        agentConfig: getSettings(),
      },
      broadcast
    );
    setProjectLastTask(projectId, task.id);
    res.json({ taskId: task.id });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.get("/api/tasks/:id", requireToken, (req, res) => {
  const task = getTask(req.params.id);
  if (!task) return res.status(404).json({ error: "not found" });
  res.json(serializeTask(task));
});

app.post("/api/tasks/:id/abort", requireToken, requireDestructiveConfirmation, async (req, res) => {
  const aborted = await abortTask(req.params.id, broadcast);
  res.json({ aborted });
});

app.get("/api/tasks/:id/diff", requireToken, (req, res) => {
  const task = getTask(req.params.id);
  if (!task) return res.status(404).json({ error: "not found" });
  if (!task.diff) return res.status(404).json({ error: "diff not available" });
  res.json(task.diff);
});

app.post("/api/tasks/:id/approve", requireToken, requireDestructiveConfirmation, async (req, res) => {
  try {
    const task = await approveTask(
      req.params.id,
      { expectedDiffHash: req.body?.diffHash, expectedTargetSha: req.body?.targetSha },
      broadcast
    );
    res.json({
      approved: true,
      mergedSha: task.mergedSha,
      artifactsCleaned: task.artifactsCleaned,
      cleanupError: task.cleanupError,
    });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks/:id/reject", requireToken, requireDestructiveConfirmation, async (req, res) => {
  const reason = typeof req.body?.reason === "string" ? req.body.reason.trim() : "";
  if (!reason) {
    return res.status(400).json({ error: "reason is required" });
  }
  try {
    await rejectTask(
      req.params.id,
      reason,
      { expectedDiffHash: req.body?.diffHash, expectedTargetSha: req.body?.targetSha },
      broadcast
    );
    res.json({ rejected: true });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks/:id/cleanup", requireToken, requireDestructiveConfirmation, async (req, res) => {
  try {
    const task = await cleanupTaskArtifacts(req.params.id, broadcast);
    res.json({ cleaned: task.artifactsCleaned });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks/:id/open-folder", requireToken, (req, res) => {
  try {
    openTaskFolder(req.params.id);
    res.json({ opened: true });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks/:id/review", requireToken, (req, res) => {
  const extraInstruction = typeof req.body?.instruction === "string" ? req.body.instruction.trim() : "";
  try {
    requestCodexReview({ id: req.params.id, extraInstruction, reviewsRoot }, broadcast);
    res.json({ requested: true });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.post("/api/tasks/:id/revise", requireToken, async (req, res) => {
  const extraInstruction = typeof req.body?.instruction === "string" ? req.body.instruction.trim() : "";
  try {
    await requestRevision({ id: req.params.id, extraInstruction, reviewsRoot }, broadcast);
    res.json({ requested: true });
  } catch (err) {
    res.status(409).json({ error: String(err?.message ?? err) });
  }
});

app.get("/api/tasks/:id/review", requireToken, (req, res) => {
  const task = getTask(req.params.id);
  if (!task) return res.status(404).json({ error: "not found" });
  res.json(task.review ?? { status: "idle" });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/ws" });
const clients = new Set();

wss.on("connection", (ws, req) => {
  const url = new URL(req.url, "http://localhost");
  const origin = req.headers.origin;
  if (url.searchParams.get("token") !== session.token || (origin && origin !== FRONTEND_ORIGIN)) {
    ws.close(4401, "unauthorized");
    return;
  }
  clients.add(ws);
  ws.on("close", () => clients.delete(ws));
});

function broadcast(event) {
  const payload = JSON.stringify(event);
  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) ws.send(payload);
  }
}

server.listen(PORT, "127.0.0.1", () => {
  publishSession(session);
  console.log(`[backend] listening on http://127.0.0.1:${PORT}`);
});

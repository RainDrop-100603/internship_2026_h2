import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

let projectsFile = null;
let projects = new Map(); // id -> { id, name, path, createdAt, lastTaskId }

function persist() {
  fs.mkdirSync(path.dirname(projectsFile), { recursive: true });
  fs.writeFileSync(projectsFile, JSON.stringify([...projects.values()], null, 2));
}

export function initProjects(runtimeDir) {
  projectsFile = path.join(runtimeDir, "projects.json");
  projects = new Map();
  if (fs.existsSync(projectsFile)) {
    const data = JSON.parse(fs.readFileSync(projectsFile, "utf8"));
    projects = new Map(data.map((p) => [p.id, p]));
  }
}

export function registerProject({ name, projectPath }) {
  if (!projectPath || typeof projectPath !== "string") {
    throw new Error("경로를 입력해주세요.");
  }
  const resolved = path.resolve(projectPath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`경로가 존재하지 않습니다: ${resolved}`);
  }
  if (!fs.existsSync(path.join(resolved, ".git"))) {
    throw new Error("git 저장소가 아닙니다 (.git 폴더를 찾을 수 없음).");
  }
  const duplicate = [...projects.values()].find((p) => p.path === resolved);
  if (duplicate) return duplicate;

  const id = crypto.randomUUID();
  const project = {
    id,
    name: name?.trim() || path.basename(resolved),
    path: resolved,
    createdAt: new Date().toISOString(),
    lastTaskId: null,
  };
  projects.set(id, project);
  persist();
  return project;
}

export function listProjects() {
  return [...projects.values()];
}

export function getProject(id) {
  return projects.get(id);
}

export function removeProject(id) {
  const project = projects.get(id);
  if (!project) return null;
  projects.delete(id);
  persist();
  return project;
}

export function setProjectLastTask(id, taskId) {
  const project = projects.get(id);
  if (!project) return;
  project.lastTaskId = taskId;
  persist();
}

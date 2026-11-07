import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { initTaskManager, cleanupTaskArtifacts, getTask } from "./taskManager.mjs";

const execFileAsync = promisify(execFile);

async function git(cwd, ...args) {
  const { stdout } = await execFileAsync("git", args, { cwd });
  return stdout.trim();
}

// 중단 직후 Windows 파일 잠금으로 git이 worktree 등록만 지우고 폴더를 남긴 상태를 재현한다.
// 이후 "git worktree remove"는 "is not a working tree"로 실패하지만, 정리는 성공해야 한다.
test("cleanup succeeds when the worktree folder remains but is no longer registered", async (t) => {
  const projectPath = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-cleanup-repo-"));
  const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-cleanup-runtime-"));
  t.after(() => {
    fs.rmSync(projectPath, { recursive: true, force: true });
    fs.rmSync(runtimeRoot, { recursive: true, force: true });
  });
  await git(projectPath, "init", "-b", "main");
  await git(projectPath, "config", "user.email", "test@example.com");
  await git(projectPath, "config", "user.name", "Cogent Test");
  fs.writeFileSync(path.join(projectPath, "a.txt"), "a\n");
  await git(projectPath, "add", "-A");
  await git(projectPath, "commit", "-m", "base");

  const worktreeDir = path.join(runtimeRoot, "worktrees", "stale");
  await git(projectPath, "worktree", "add", "-b", "task/stale", worktreeDir);
  // 등록 정보만 사라지고 폴더(빈 폴더 + 남은 파일)가 남은 상태로 만든다.
  fs.rmSync(path.join(worktreeDir, ".git"), { force: true });
  await git(projectPath, "worktree", "prune");
  await git(projectPath, "branch", "-D", "task/stale");
  assert.equal(fs.existsSync(worktreeDir), true);

  fs.writeFileSync(
    path.join(runtimeRoot, "tasks.json"),
    JSON.stringify([
      {
        id: "stale",
        projectId: "p",
        projectPath,
        worktreeDir,
        branchName: "task/stale",
        status: "aborted",
        events: [],
        artifactsCleaned: false,
        createdAt: "2026-01-01T00:00:00.000Z",
      },
    ])
  );
  initTaskManager(runtimeRoot);

  await cleanupTaskArtifacts("stale", () => {});
  assert.equal(getTask("stale").artifactsCleaned, true);
  assert.equal(fs.existsSync(worktreeDir), false);
});

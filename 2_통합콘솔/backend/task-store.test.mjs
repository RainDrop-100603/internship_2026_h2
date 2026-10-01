import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  initTaskManager,
  getTask,
  isBusy,
  busyReason,
  projectRemovalBlockReason,
} from "./taskManager.mjs";

test("task state is restored and interrupted work is marked failed", (t) => {
  const runtimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-task-store-test-"));
  t.after(() => fs.rmSync(runtimeRoot, { recursive: true, force: true }));
  fs.writeFileSync(
    path.join(runtimeRoot, "tasks.json"),
    JSON.stringify([
      {
        id: "interrupted",
        status: "running",
        events: [],
        review: null,
        createdAt: "2026-01-01T00:00:00.000Z",
      },
      {
        id: "pending",
        projectId: "pending-project",
        status: "completed",
        events: [],
        review: null,
        createdAt: "2026-01-02T00:00:00.000Z",
        finishedAt: "2026-01-02T00:01:00.000Z",
      },
    ])
  );

  initTaskManager(runtimeRoot);

  assert.equal(getTask("interrupted").status, "failed");
  assert.match(getTask("interrupted").error, /서버가 작업 실행 중 재시작/);
  assert.equal(getTask("pending").status, "completed");
  assert.equal(isBusy(), true);
  assert.equal(busyReason(), "이전 작업의 승인/반려가 필요합니다.");
  assert.equal(projectRemovalBlockReason("pending-project"), "승인/반려 대기 중인 작업을 먼저 처리해주세요.");
  assert.equal(projectRemovalBlockReason("unrelated-project"), null);
  assert.doesNotThrow(() => JSON.parse(fs.readFileSync(path.join(runtimeRoot, "tasks.json"), "utf8")));

  const cleanupOnlyRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-task-cleanup-test-"));
  t.after(() => fs.rmSync(cleanupOnlyRoot, { recursive: true, force: true }));
  fs.writeFileSync(
    path.join(cleanupOnlyRoot, "tasks.json"),
    JSON.stringify([{ id: "failed", projectId: "cleanup-project", status: "failed", events: [], artifactsCleaned: false }])
  );
  initTaskManager(cleanupOnlyRoot);
  assert.equal(isBusy(), true);
  assert.equal(busyReason(), "이전 실패 작업의 임시 worktree를 먼저 정리해주세요.");
  assert.equal(projectRemovalBlockReason("cleanup-project"), "실패 작업의 임시 worktree를 먼저 정리해주세요.");
});

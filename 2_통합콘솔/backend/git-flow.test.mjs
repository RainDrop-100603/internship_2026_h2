import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { collectDiff } from "./diff.mjs";
import { assertFrozenTarget, restoreFrozenTarget } from "./git.mjs";

const execFileAsync = promisify(execFile);

async function git(cwd, ...args) {
  const { stdout } = await execFileAsync("git", args, { cwd });
  return stdout.trim();
}

async function makeRepository() {
  const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-git-test-"));
  await git(cwd, "init", "-b", "main");
  await git(cwd, "config", "user.email", "test@example.com");
  await git(cwd, "config", "user.name", "Cogent Test");
  fs.writeFileSync(path.join(cwd, "old name.txt"), "stable content\n".repeat(20));
  await git(cwd, "add", "-A");
  await git(cwd, "commit", "-m", "base");
  return cwd;
}

test("collectDiff includes committed files and parses renamed paths", async (t) => {
  const cwd = await makeRepository();
  t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  const baseSha = await git(cwd, "rev-parse", "HEAD");

  await git(cwd, "mv", "old name.txt", "new name.txt");
  fs.writeFileSync(path.join(cwd, "committed.js"), "export const ready = true;\n");
  await git(cwd, "add", "-A");
  await git(cwd, "commit", "-m", "committed changes");

  const result = await collectDiff({ worktreeDir: cwd, baseSha });
  assert.deepEqual(
    result.changedFiles.map((file) => file.path).sort(),
    ["committed.js", "new name.txt"]
  );
  assert.equal(result.changedFiles.find((file) => file.path === "new name.txt")?.status, "renamed");
  assert.match(result.files["committed.js"], /ready = true/);
  assert.match(result.files["new name.txt"], /old name\.txt/);
});

test("assertFrozenTarget rejects changes made after the target commit", async (t) => {
  const cwd = await makeRepository();
  t.after(() => fs.rmSync(cwd, { recursive: true, force: true }));
  const targetSha = await git(cwd, "rev-parse", "HEAD");

  await assertFrozenTarget({ worktreeDir: cwd, targetSha });
  fs.appendFileSync(path.join(cwd, "old name.txt"), "late change\n");

  await assert.rejects(
    assertFrozenTarget({ worktreeDir: cwd, targetSha }),
    /worktree에 추가 변경/
  );

  await restoreFrozenTarget({ worktreeDir: cwd, targetSha });
  await assertFrozenTarget({ worktreeDir: cwd, targetSha });
  assert.doesNotMatch(fs.readFileSync(path.join(cwd, "old name.txt"), "utf8"), /late change/);
});

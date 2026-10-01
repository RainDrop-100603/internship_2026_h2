import { execFile } from "node:child_process";
import { promisify } from "node:util";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const execFileAsync = promisify(execFile);

async function git(args, cwd) {
  const { stdout } = await execFileAsync("git", args, { cwd, maxBuffer: 1024 * 1024 * 32 });
  return stdout;
}

const STATUS_LABELS = {
  M: "modified",
  A: "added",
  D: "deleted",
  R: "renamed",
  C: "copied",
  U: "unmerged",
  "?": "untracked",
};

function parseNameStatus(output) {
  const tokens = output.split("\0");
  const files = [];

  for (let i = 0; i < tokens.length; ) {
    if (!tokens[i]) {
      i += 1;
      continue;
    }

    let status = tokens[i++];
    let firstPath = null;
    const tabIndex = status.indexOf("\t");
    if (tabIndex !== -1) {
      firstPath = status.slice(tabIndex + 1);
      status = status.slice(0, tabIndex);
    }

    firstPath ??= tokens[i++] ?? "";
    const kind = status.charAt(0);
    if (kind === "R" || kind === "C") {
      const newPath = tokens[i++] ?? "";
      files.push({
        path: newPath,
        oldPath: firstPath,
        status: STATUS_LABELS[kind],
      });
    } else {
      files.push({
        path: firstPath,
        status: STATUS_LABELS[kind] ?? "modified",
      });
    }
  }

  return files.filter((file) => file.path);
}

// 작업 완료 후 worktree에서 diff를 수집한다. baseSha와 비교해야 Claude가
// 도중에 git add/commit을 실행했더라도(staged/committed 변경 포함) 승인 시
// 병합되는 내용과 리뷰에 보이는 diff가 항상 일치한다. 신규(untracked) 파일은
// git add -N(intent-to-add)로 표시해야 diff에 나타나고, --untracked-files=all로
// 새 디렉터리도 개별 파일 단위로 펼쳐서 각 파일을 리뷰할 수 있게 한다.
export async function collectDiff({ worktreeDir, baseSha }) {
  const statusOut = await git(["status", "--porcelain=v1", "-z", "--untracked-files=all"], worktreeDir);
  const untracked = statusOut
    .split("\0")
    .filter((entry) => entry.startsWith("?? "))
    .map((entry) => entry.slice(3));
  if (untracked.length > 0) {
    await git(["add", "-N", "--", ...untracked], worktreeDir);
  }

  const stat = await git(["diff", "--stat", baseSha], worktreeDir);
  const patch = await git(["diff", baseSha], worktreeDir);
  const nameStatus = await git(["diff", "--name-status", "-z", baseSha], worktreeDir);
  const changedFiles = parseNameStatus(nameStatus);
  const diffHash = crypto.createHash("sha256").update(patch).digest("hex");

  const files = {};
  await Promise.all(
    changedFiles.map(async (file) => {
      const pathspecs = file.oldPath ? [file.oldPath, file.path] : [file.path];
      files[file.path] = await git(["diff", baseSha, "--", ...pathspecs], worktreeDir);
    })
  );

  return { changedFiles, stat: stat.trim(), patch, diffHash, files, baseSha };
}

// 리뷰/이력 재현을 위해 patch 파일과 manifest를 저장한다 (Phase 4에서 Codex 리뷰 대상으로 재사용).
export function saveSnapshot({ reviewsRoot, taskId, diffResult, branchName, targetSha }) {
  const dir = path.join(reviewsRoot, taskId);
  fs.mkdirSync(dir, { recursive: true });
  const manifest = JSON.stringify(
    {
      taskId,
      branchName,
      baseSha: diffResult.baseSha,
      targetSha,
      diffHash: diffResult.diffHash,
      changedFiles: diffResult.changedFiles,
    },
    null,
    2
  );
  const version = targetSha.slice(0, 12);
  fs.writeFileSync(path.join(dir, "diff.patch"), diffResult.patch);
  fs.writeFileSync(path.join(dir, "manifest.json"), manifest);
  fs.writeFileSync(path.join(dir, `diff-${version}.patch`), diffResult.patch);
  fs.writeFileSync(path.join(dir, `manifest-${version}.json`), manifest);
  return dir;
}

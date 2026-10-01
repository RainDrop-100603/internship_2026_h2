import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function git(args, cwd) {
  const { stdout } = await execFileAsync("git", args, { cwd });
  return stdout.trim();
}

async function isGitSuccess(args, cwd) {
  try {
    await execFileAsync("git", args, { cwd });
    return true;
  } catch {
    return false;
  }
}

export async function getCurrentBranch(projectPath) {
  return git(["symbolic-ref", "--short", "HEAD"], projectPath);
}

export async function hasCommits(projectPath) {
  return isGitSuccess(["rev-parse", "--verify", "HEAD"], projectPath);
}

// 커밋이 하나도 없는 저장소는 worktree를 만들 기준 커밋이 없어 빈 초기 커밋을 만든다.
export async function ensureInitialCommit(projectPath) {
  if (await hasCommits(projectPath)) return;
  await git(["commit", "--allow-empty", "-m", "chore: initial commit"], projectPath);
}

export async function createWorktree({ projectPath, baseBranch, branchName, worktreeDir }) {
  await git(["worktree", "add", "-b", branchName, worktreeDir, baseBranch], projectPath);
}

export async function removeWorktree({ projectPath, worktreeDir }) {
  await git(["worktree", "remove", worktreeDir, "--force"], projectPath);
}

export async function getRevision(cwd, ref) {
  return git(["rev-parse", ref], cwd);
}

// worktree의 모든 변경사항을 하나의 커밋으로 만든다. 변경사항이 없으면 null 반환.
export async function commitAll({ cwd, message }) {
  await git(["add", "-A"], cwd);
  const status = await git(["status", "--porcelain"], cwd);
  if (!status.trim()) return null;
  await git(["commit", "-m", message], cwd);
  return git(["rev-parse", "HEAD"], cwd);
}

export async function getStatus(cwd) {
  return git(["status", "--porcelain", "--untracked-files=all"], cwd);
}

export async function assertFrozenTarget({ worktreeDir, targetSha }) {
  const head = await getRevision(worktreeDir, "HEAD");
  if (head !== targetSha) {
    throw new Error(`승인 대상 커밋이 변경되었습니다. 예상 ${targetSha}, 현재 ${head}`);
  }

  const status = await getStatus(worktreeDir);
  if (status) {
    throw new Error("검토 완료 후 worktree에 추가 변경이 생겼습니다. 새 작업으로 다시 검토해주세요.");
  }
}

export async function restoreFrozenTarget({ worktreeDir, targetSha }) {
  await git(["reset", "--hard", targetSha], worktreeDir);
  await git(["clean", "-fd"], worktreeDir);
  await assertFrozenTarget({ worktreeDir, targetSha });
}

// 승인 시 원 프로젝트 브랜치로 병합한다. fast-forward만 허용해 충돌/의도치 않은
// 병합 커밋을 만들지 않는다 — base가 그 사이 움직였다면 실패시키고 사용자에게 알린다.
export async function fastForwardMerge({ projectPath, targetSha, expectedBaseBranch, expectedBaseSha }) {
  const currentBranch = await getCurrentBranch(projectPath);
  if (currentBranch !== expectedBaseBranch) {
    throw new Error(
      `프로젝트가 현재 '${currentBranch}' 브랜치에 있습니다. '${expectedBaseBranch}'로 전환한 뒤 다시 승인해주세요.`
    );
  }

  const currentSha = await getRevision(projectPath, "HEAD");
  if (currentSha !== expectedBaseSha) {
    throw new Error(
      `기준 브랜치가 작업 시작 후 변경되었습니다. 예상 ${expectedBaseSha}, 현재 ${currentSha}`
    );
  }

  await git(["merge", "--ff-only", targetSha], projectPath);
  return getRevision(projectPath, "HEAD");
}

export async function deleteBranch({ projectPath, branchName, force }) {
  await git(["branch", force ? "-D" : "-d", branchName], projectPath);
}

export async function branchExists({ projectPath, branchName }) {
  return isGitSuccess(["show-ref", "--verify", "--quiet", `refs/heads/${branchName}`], projectPath);
}

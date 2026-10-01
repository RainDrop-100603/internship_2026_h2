import { useEffect, useRef, useState } from "react";
import {
  createTask,
  abortTask as abortTaskRequest,
  connectTaskSocket,
  getTaskStatus,
  getTaskDiff,
  approveTask as approveTaskRequest,
  rejectTask as rejectTaskRequest,
  requestCodexReview as requestCodexReviewApi,
  requestRevision as requestRevisionApi,
  getCodexReview,
  listProjects,
  createProject,
  removeProject as removeProjectRequest,
  cleanupTask,
  openTaskFolder,
  getAgentSettings,
  saveAgentSettings,
} from "./api";
import { parseFileDiff } from "./diffParse";
import "./App.css";

const STATUS_LABEL = {
  starting: "Claude 작업 준비 중",
  running: "Claude 작업 중",
  revising: "Codex 리뷰 반영 수정 중",
  revision_aborting: "수정 작업 중단 중",
  completed: "Claude 작업 완료",
  failed: "Claude 작업 실패",
  aborted: "Claude 작업 중단됨",
  approved: "승인 완료",
  rejected: "반려됨",
};

const DONE_STATUSES = ["completed", "approved", "rejected"];

function computeBadge(lastTask) {
  if (!lastTask) return null;
  if (["running", "starting", "revising", "revision_aborting"].includes(lastTask.status)) {
    return { label: lastTask.status.startsWith("revision") || lastTask.status === "revising" ? "수정 중" : "작업 중", tone: "running" };
  }
  if (lastTask.status === "completed") {
    if (lastTask.review?.status === "done") return { label: "리뷰 완료 1", tone: "review" };
    return { label: "승인 대기 1", tone: "pending" };
  }
  return null; // approved/rejected/failed/aborted: 결정 완료, 배지 없음
}

function ProjectTab({ project, isActive, onSelect, onRemove, removePending }) {
  return (
    <div className={`project-tab ${isActive ? "project-tab--active" : ""}`}>
      <button className={`tab ${isActive ? "tab--active" : ""}`} onClick={onSelect}>
        <span>{project.name}</span>
        {project.badge && (
          <span className={`badge badge--${project.badge.tone}`}>{project.badge.label}</span>
        )}
      </button>
      <button
        type="button"
        className="project-tab__remove"
        onClick={onRemove}
        disabled={removePending}
        aria-label={`${project.name} 프로젝트 제거`}
        title={`${project.name} 프로젝트 제거`}
      >
        ×
      </button>
    </div>
  );
}

function StatusBadge({ step }) {
  return (
    <span className={`status status--${step.state}`}>
      <span className="status__dot" />
      {step.id} · {step.label}
    </span>
  );
}

function LogLine({ role, text }) {
  return (
    <div className="log-line">
      <span className={`log-line__role log-line__role--${role === "Claude" ? "claude" : "tool"}`}>
        {role}
      </span>
      <span className="log-line__text">{text}</span>
    </div>
  );
}

function DiffLine({ type, text }) {
  const prefix = type === "add" ? "+" : type === "del" ? "-" : type === "hunk" ? "" : " ";
  return (
    <div className={`diff-line diff-line--${type}`}>
      <span className="diff-line__prefix">{prefix}</span>
      <span className="diff-line__text">{text}</span>
    </div>
  );
}

function ReviewCard({ review }) {
  return (
    <div className="review-card">
      <div className="review-card__head">
        <span className="review-card__location">{review.location}</span>
        <span className={`review-card__severity review-card__severity--${review.severity === "경고" ? "warn" : "suggest"}`}>
          {review.severity}
        </span>
      </div>
      <p className="review-card__text">{review.text}</p>
    </div>
  );
}

function toDisplayFinding(finding) {
  return {
    location: finding.file + (finding.line ? `:L${finding.line}` : ""),
    severity: finding.severity === "suggestion" ? "제안" : "경고",
    text: finding.message,
  };
}

function formatTokens(value) {
  const amount = Number(value) || 0;
  if (amount >= 1_000_000) return `${(amount / 1_000_000).toFixed(1)}m`;
  if (amount >= 1_000) return `${(amount / 1_000).toFixed(1)}k`;
  return String(amount);
}

function agentLabel(agent) {
  return agent === "claude" ? "Claude" : "Codex";
}

function runKindLabel(kind) {
  if (kind === "implementation") return "구현";
  if (kind === "review") return "리뷰";
  if (kind?.startsWith("revision-")) return `수정 ${kind.slice("revision-".length)}차`;
  return kind;
}

function displayRunModel(run) {
  if (run.actualModels?.length) return run.actualModels.join(", ");
  return run.requestedModel === "default" ? "기본 모델" : run.requestedModel;
}

function displayConfig(config) {
  if (!config) return "기본 설정";
  const model = config.model === "default" ? "기본 모델" : config.model;
  return `${model} · ${config.effort || "기본 effort"}`;
}

function UsageEntry({ run }) {
  const usage = run.usage;
  return (
    <div className="usage-entry">
      <div className="usage-entry__identity">
        <strong>{agentLabel(run.agent)} · {runKindLabel(run.kind)}</strong>
        <span>{displayRunModel(run)} · {run.effort || "기본 effort"}</span>
      </div>
      {usage ? (
        <div className="usage-entry__tokens">
          <span>입력 {formatTokens(usage.inputTokens)}</span>
          <span>캐시 {formatTokens(usage.cachedInputTokens)}</span>
          {usage.cacheCreationInputTokens > 0 && <span>캐시 생성 {formatTokens(usage.cacheCreationInputTokens)}</span>}
          <span>출력 {formatTokens(usage.outputTokens)}</span>
          {usage.reasoningTokens > 0 && <span>추론 {formatTokens(usage.reasoningTokens)}</span>}
          {run.estimatedCostUsd !== null && (
            <span>예상 ${Number(run.estimatedCostUsd).toFixed(3)}</span>
          )}
        </div>
      ) : (
        <span className={`usage-entry__pending usage-entry__pending--${run.status}`}>
          {run.status === "running" ? "집계 중" : "사용량 없음"}
        </span>
      )}
    </div>
  );
}

function App() {
  const [projects, setProjects] = useState([]);
  const [activeProjectId, setActiveProjectId] = useState(null);
  const [showNewProjectForm, setShowNewProjectForm] = useState(false);
  const [newProjectName, setNewProjectName] = useState("");
  const [newProjectPath, setNewProjectPath] = useState("");
  const [newProjectPending, setNewProjectPending] = useState(false);
  const [projectRemovePendingId, setProjectRemovePendingId] = useState(null);
  const [agentSettings, setAgentSettings] = useState(null);
  const [settingsDraft, setSettingsDraft] = useState(null);
  const [settingsOptions, setSettingsOptions] = useState(null);
  const [settingsPending, setSettingsPending] = useState(false);

  const [instruction, setInstruction] = useState("");
  const [taskId, setTaskId] = useState(null);
  const [taskStatus, setTaskStatus] = useState(null);
  const [logLines, setLogLines] = useState([]);
  const [errorMessage, setErrorMessage] = useState(null);
  const [diff, setDiff] = useState(null);
  const [selectedFilePath, setSelectedFilePath] = useState(null);
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [rejectedReasonRecord, setRejectedReasonRecord] = useState("");
  const [decisionPending, setDecisionPending] = useState(false);
  const [review, setReview] = useState(null);
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [reviewExtraInstruction, setReviewExtraInstruction] = useState("");
  const [reviewRequestPending, setReviewRequestPending] = useState(false);
  const [showRevisionForm, setShowRevisionForm] = useState(false);
  const [revisionInstruction, setRevisionInstruction] = useState("");
  const [revisionPending, setRevisionPending] = useState(false);
  const [abortPending, setAbortPending] = useState(false);
  const [cleanupPending, setCleanupPending] = useState(false);
  const [openFolderPending, setOpenFolderPending] = useState(false);
  const [artifactsCleaned, setArtifactsCleaned] = useState(false);
  const [taskAgentConfig, setTaskAgentConfig] = useState(null);
  const [taskRuns, setTaskRuns] = useState([]);
  const wsRef = useRef(null);
  const currentTaskIdRef = useRef(null);
  const activeProjectIdRef = useRef(null);
  const instructionFieldRef = useRef(null);

  useEffect(() => {
    const field = instructionFieldRef.current;
    if (!field) return;
    field.style.height = "auto";
    field.style.height = `${Math.min(field.scrollHeight, 180)}px`;
    field.style.overflowY = field.scrollHeight > 180 ? "auto" : "hidden";
  }, [instruction]);

  async function refreshProjects() {
    try {
      const { projects: list } = await listProjects();
      setProjects(list);
      return list;
    } catch (err) {
      setErrorMessage(err.message);
      return [];
    }
  }

  async function loadAgentSettings() {
    try {
      const payload = await getAgentSettings();
      setAgentSettings(payload.settings);
      setSettingsDraft(payload.settings);
      setSettingsOptions(payload.options);
    } catch (err) {
      setErrorMessage(err.message);
    }
  }

  async function loadProjectState(project) {
    activeProjectIdRef.current = project.id;
    setActiveProjectId(project.id);
    setErrorMessage(null);
    setInstruction("");
    setShowRejectForm(false);
    setRejectReason("");
    setShowReviewForm(false);
    setReviewExtraInstruction("");
    setShowRevisionForm(false);
    setRevisionInstruction("");

    if (!project.lastTask) {
      currentTaskIdRef.current = null;
      setTaskId(null);
      setTaskStatus(null);
      setLogLines([]);
      setDiff(null);
      setSelectedFilePath(null);
      setReview(null);
      setArtifactsCleaned(false);
      setTaskAgentConfig(null);
      setTaskRuns([]);
      return;
    }

    const id = project.lastTask.id;
    currentTaskIdRef.current = id;
    setTaskId(id);
    // 탭을 빠르게 연달아 전환하면 이전 loadProjectState 호출이 뒤늦게 끝나면서
    // 지금 보고 있는(다른) 프로젝트 화면을 예전 응답으로 덮어쓸 수 있다.
    // 매 await 이후 여전히 이 프로젝트를 보고 있는지 확인한다.
    const stillActive = () => activeProjectIdRef.current === project.id;
    try {
      const task = await getTaskStatus(id);
      if (!stillActive()) return;
      setTaskStatus(task.status);
      setTaskAgentConfig(task.agentConfig ?? null);
      setTaskRuns(task.runs ?? []);
      setArtifactsCleaned(Boolean(task.artifactsCleaned));
      setLogLines(task.events.filter((e) => e.type === "log").map((e) => ({ role: e.role, text: e.text })));
      if (task.rejectReason) setRejectedReasonRecord(task.rejectReason);

      if (DONE_STATUSES.includes(task.status)) {
        const diffData = await getTaskDiff(id).catch(() => null);
        if (!stillActive()) return;
        setDiff(diffData);
        setSelectedFilePath(diffData?.changedFiles[0]?.path ?? null);
      } else {
        setDiff(null);
      }

      const reviewData = await getCodexReview(id).catch(() => null);
      if (!stillActive()) return;
      setReview(reviewData && reviewData.status !== "idle" ? reviewData : null);
    } catch (err) {
      if (stillActive()) setErrorMessage(err.message);
    }
  }

  useEffect(() => {
    wsRef.current = connectTaskSocket((event) => {
      if (event.type === "status" || event.type === "review_status") {
        refreshProjects();
      }
      if (event.taskId !== currentTaskIdRef.current) return;
      if (event.type === "log") {
        setLogLines((prev) => [...prev, { role: event.role, text: event.text }]);
      } else if (event.type === "status") {
        setTaskStatus(event.status);
        if (event.error) setErrorMessage(event.error);
        if (event.revised) {
          setReview(null);
          setShowRevisionForm(false);
          setRevisionInstruction("");
        }
        if (typeof event.artifactsCleaned === "boolean") setArtifactsCleaned(event.artifactsCleaned);
        if (event.cleanupError) setErrorMessage(`변경사항은 반영됐지만 임시 작업 정리에 실패했습니다: ${event.cleanupError}`);
        if (event.status === "completed") {
          getTaskDiff(event.taskId)
            .then((diffData) => {
              setDiff(diffData);
              setSelectedFilePath(diffData.changedFiles[0]?.path ?? null);
            })
            .catch((err) => setErrorMessage(err.message));
        }
      } else if (event.type === "review_status") {
        if (event.status === "running") {
          setReview({ status: "running", findings: [], summary: null, error: null });
        } else {
          getCodexReview(event.taskId)
            .then(setReview)
            .catch((err) => setErrorMessage(err.message));
        }
      } else if (event.type === "usage") {
        setTaskRuns((previous) => {
          const existingIndex = previous.findIndex((run) => run.id === event.run.id);
          if (existingIndex === -1) return [...previous, event.run];
          return previous.map((run, index) => (index === existingIndex ? event.run : run));
        });
      } else if (event.type === "artifacts_cleaned") {
        setArtifactsCleaned(true);
      }
    });

    (async () => {
      const [list] = await Promise.all([refreshProjects(), loadAgentSettings()]);
      if (list.length > 0) {
        await loadProjectState(list[0]);
      }
    })();

    return () => wsRef.current?.close();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isRunning = ["starting", "running", "revising", "revision_aborting"].includes(taskStatus);
  const needsReview = taskStatus === "completed";
  const showLive = taskStatus !== null;
  const showDiff = showLive && diff !== null;

  async function handleSelectProject(project) {
    if (project.id === activeProjectId) return;
    await loadProjectState(project);
  }

  async function handleCreateProject(e) {
    e.preventDefault();
    if (!newProjectPath.trim()) return;
    setNewProjectPending(true);
    setErrorMessage(null);
    try {
      const project = await createProject(newProjectName.trim(), newProjectPath.trim());
      setShowNewProjectForm(false);
      setNewProjectName("");
      setNewProjectPath("");
      await refreshProjects();
      await loadProjectState({ ...project, lastTask: null });
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setNewProjectPending(false);
    }
  }

  function clearProjectState() {
    activeProjectIdRef.current = null;
    currentTaskIdRef.current = null;
    setActiveProjectId(null);
    setTaskId(null);
    setTaskStatus(null);
    setLogLines([]);
    setDiff(null);
    setSelectedFilePath(null);
    setReview(null);
    setInstruction("");
    setShowRejectForm(false);
    setRejectReason("");
    setRejectedReasonRecord("");
    setShowReviewForm(false);
    setReviewExtraInstruction("");
    setShowRevisionForm(false);
    setRevisionInstruction("");
    setArtifactsCleaned(false);
    setTaskAgentConfig(null);
    setTaskRuns([]);
  }

  async function handleRemoveProject(project) {
    const confirmed = window.confirm(
      `'${project.name}' 프로젝트를 콘솔 목록에서 제거할까요?\n\n실제 프로젝트 폴더와 Git 저장소는 삭제되지 않습니다.`
    );
    if (!confirmed) return;

    setProjectRemovePendingId(project.id);
    setErrorMessage(null);
    try {
      await removeProjectRequest(project.id);
      const remainingProjects = projects.filter((item) => item.id !== project.id);
      setProjects(remainingProjects);

      if (activeProjectIdRef.current === project.id) {
        if (remainingProjects.length > 0) {
          await loadProjectState(remainingProjects[0]);
        } else {
          clearProjectState();
        }
      }
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setProjectRemovePendingId(null);
    }
  }

  async function handleSaveAgentSettings() {
    if (!settingsDraft) return;
    setSettingsPending(true);
    setErrorMessage(null);
    try {
      const { settings: saved } = await saveAgentSettings(settingsDraft);
      setAgentSettings(saved);
      setSettingsDraft(saved);
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setSettingsPending(false);
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!instruction.trim() || isRunning || needsReview || !activeProjectId) return;
    setErrorMessage(null);
    try {
      const { taskId: newTaskId } = await createTask(activeProjectId, instruction.trim());
      setLogLines([]);
      setDiff(null);
      setSelectedFilePath(null);
      setShowRejectForm(false);
      setRejectReason("");
      setReview(null);
      setArtifactsCleaned(false);
      setShowReviewForm(false);
      setReviewExtraInstruction("");
      setShowRevisionForm(false);
      setRevisionInstruction("");
      setTaskStatus("starting");
      setTaskAgentConfig(agentSettings);
      setTaskRuns([]);
      currentTaskIdRef.current = newTaskId;
      setTaskId(newTaskId);
      getTaskStatus(newTaskId)
        .then((task) => {
          if (currentTaskIdRef.current !== newTaskId) return;
          setTaskStatus(task.status);
          setTaskAgentConfig(task.agentConfig ?? null);
          setTaskRuns(task.runs ?? []);
          setLogLines(task.events.filter((event) => event.type === "log").map((event) => ({ role: event.role, text: event.text })));
        })
        .catch((err) => setErrorMessage(err.message));
      refreshProjects();
    } catch (err) {
      // 새 작업 시작이 거부된 경우(예: 이전 실패 작업 정리 대기) 화면 상태를 건드리지
      // 않아야, 이미 표시 중인 이전 작업의 "임시 작업 정리" 버튼이 사라지지 않는다.
      setErrorMessage(err.message);
    }
  }

  async function handleApprove() {
    if (!taskId || !diff) return;
    if (!window.confirm("현재 표시된 변경사항을 기준 브랜치에 반영할까요?")) return;
    setDecisionPending(true);
    setErrorMessage(null);
    try {
      const result = await approveTaskRequest(taskId, diff.diffHash, diff.targetSha);
      setTaskStatus("approved");
      setArtifactsCleaned(Boolean(result.artifactsCleaned));
      if (result.cleanupError) {
        setErrorMessage(`변경사항은 반영됐지만 임시 작업 정리에 실패했습니다: ${result.cleanupError}`);
      }
      refreshProjects();
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setDecisionPending(false);
    }
  }

  async function handleRequestReview(extraInstruction) {
    if (!taskId || review?.status === "running") return;
    setReviewRequestPending(true);
    setErrorMessage(null);
    try {
      await requestCodexReviewApi(taskId, extraInstruction);
      setShowReviewForm(false);
      setReviewExtraInstruction("");
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setReviewRequestPending(false);
    }
  }

  async function handleRequestRevision(extraInstruction) {
    if (!taskId || review?.status !== "done" || isRunning) return;
    setRevisionPending(true);
    setErrorMessage(null);
    try {
      await requestRevisionApi(taskId, extraInstruction);
      setTaskStatus("revising");
      setShowRevisionForm(false);
      setRevisionInstruction("");
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setRevisionPending(false);
    }
  }

  async function handleRejectConfirm() {
    if (!taskId || !diff || !rejectReason.trim()) return;
    setDecisionPending(true);
    setErrorMessage(null);
    try {
      await rejectTaskRequest(taskId, rejectReason.trim(), diff.diffHash, diff.targetSha);
      setRejectedReasonRecord(rejectReason.trim());
      setTaskStatus("rejected");
      setArtifactsCleaned(true);
      setShowRejectForm(false);
      refreshProjects();
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setDecisionPending(false);
    }
  }

  async function handleAbort() {
    const message = taskStatus === "revising"
      ? "수정 작업을 중단하고 이전 검토 버전으로 되돌릴까요?"
      : "실행 중인 Claude 작업을 중단하고 임시 worktree를 정리할까요?";
    if (!taskId || !window.confirm(message)) return;
    setAbortPending(true);
    setErrorMessage(null);
    try {
      await abortTaskRequest(taskId);
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setAbortPending(false);
    }
  }

  async function handleCleanup() {
    if (!taskId || !window.confirm("남아 있는 임시 worktree와 브랜치를 삭제할까요?")) return;
    setCleanupPending(true);
    setErrorMessage(null);
    try {
      await cleanupTask(taskId);
      setArtifactsCleaned(true);
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setCleanupPending(false);
    }
  }

  async function handleOpenFolder() {
    if (!taskId) return;
    setOpenFolderPending(true);
    setErrorMessage(null);
    try {
      await openTaskFolder(taskId);
    } catch (err) {
      setErrorMessage(err.message);
    } finally {
      setOpenFolderPending(false);
    }
  }

  const displayLog = logLines;
  const settingsDirty = Boolean(
    agentSettings && settingsDraft && JSON.stringify(agentSettings) !== JSON.stringify(settingsDraft)
  );
  const step1Done = DONE_STATUSES.includes(taskStatus);
  const displayStatusSteps = [
    {
      id: 1,
      label: step1Done ? "Claude 작업 완료" : STATUS_LABEL[taskStatus] ?? "대기",
      state: step1Done ? "done" : isRunning ? "active" : "pending",
    },
    {
      id: 2,
      label:
        review?.status === "running"
          ? "Codex 리뷰 중"
          : review?.status === "done"
            ? "Codex 리뷰 완료"
            : review?.status === "failed"
              ? "Codex 리뷰 실패"
              : "Codex 리뷰",
      state: review?.status === "done" ? "done" : review?.status === "running" ? "active" : "pending",
    },
    {
      id: 3,
      label: taskStatus === "approved" ? "승인 완료" : taskStatus === "rejected" ? "반려됨" : "승인 대기",
      state:
        taskStatus === "approved"
          ? "done"
          : taskStatus === "rejected"
            ? "rejected"
            : needsReview
              ? "active"
              : "pending",
    },
  ];

  const displayFiles = showDiff ? diff.changedFiles : [];
  const activeFilePath = showDiff ? selectedFilePath : null;
  const diffLines = showDiff ? parseFileDiff(diff.files[selectedFilePath] ?? "") : [];
  const diffFileLabel = showDiff ? `DIFF · ${(selectedFilePath ?? "").toUpperCase()}` : "DIFF";

  let diffFooterContent;
  if (showDiff && needsReview) {
    diffFooterContent = showRejectForm ? (
      <div className="diff-footer__reject-form">
        <input
          className="diff-footer__reject-input"
          type="text"
          value={rejectReason}
          onChange={(e) => setRejectReason(e.target.value)}
          placeholder="반려 사유를 입력하세요"
          autoFocus
        />
        <button className="btn btn--outline" onClick={() => setShowRejectForm(false)} disabled={decisionPending}>
          취소
        </button>
        <button
          className="btn btn--primary"
          onClick={handleRejectConfirm}
          disabled={decisionPending || !rejectReason.trim()}
        >
          반려 확정
        </button>
      </div>
    ) : (
      <div className="diff-footer__actions">
        <button className="btn btn--outline" onClick={() => setShowRejectForm(true)} disabled={decisionPending}>
          반려
        </button>
        <button className="btn btn--primary" onClick={handleApprove} disabled={decisionPending}>
          {decisionPending ? "처리 중..." : "승인 · 반영"}
        </button>
      </div>
    );
  } else if (showDiff && taskStatus === "approved") {
    diffFooterContent = (
      <span className="diff-footer__decision diff-footer__decision--approved">
        승인 완료 · {diff.changedFiles.length}개 파일 반영됨
      </span>
    );
  } else if (showDiff && taskStatus === "rejected") {
    diffFooterContent = (
      <span className="diff-footer__decision diff-footer__decision--rejected">
        반려됨: {rejectedReasonRecord}
      </span>
    );
  } else {
    diffFooterContent = <span className="diff-footer__decision">diff 준비 중...</span>;
  }

  const displayFindings = showDiff && review ? review.findings.map(toDisplayFinding) : [];
  const reviewCountLabel = showDiff && review ? review.findings.length : 0;

  let reviewPanelContent;
  if (!showDiff) {
    reviewPanelContent = (
      <div className="review-empty">
        <p className="review-empty__text">Claude 작업이 완료되면 리뷰를 요청할 수 있습니다.</p>
      </div>
    );
  } else if (!review || review.status === "idle") {
    reviewPanelContent = (
      <div className="review-empty">
        <p className="review-empty__text">아직 Codex 리뷰를 요청하지 않았습니다.</p>
        <button className="btn btn--primary" onClick={() => handleRequestReview("")} disabled={reviewRequestPending}>
          Codex에게 리뷰 요청
        </button>
      </div>
    );
  } else if (review.status === "running") {
    reviewPanelContent = (
      <div className="review-empty">
        <p className="review-empty__text">Codex가 리뷰 중입니다...</p>
      </div>
    );
  } else if (review.status === "failed") {
    reviewPanelContent = (
      <div className="review-empty">
        <p className="review-empty__text review-empty__text--error">리뷰 실패: {review.error}</p>
        <button className="btn btn--primary" onClick={() => handleRequestReview("")} disabled={reviewRequestPending}>
          다시 시도
        </button>
      </div>
    );
  } else {
    reviewPanelContent = (
      <>
        {review.summary && <p className="review-summary">{review.summary}</p>}
        <div className="review-list">
          {displayFindings.length === 0 ? (
            <p className="review-empty__text">발견된 이슈가 없습니다.</p>
          ) : (
            displayFindings.map((r, i) => <ReviewCard key={i} review={r} />)
          )}
        </div>
        {showRevisionForm ? (
          <div className="review-request-form review-revision-form">
            <input
              className="review-request-form__input"
              type="text"
              value={revisionInstruction}
              onChange={(e) => setRevisionInstruction(e.target.value)}
              placeholder="수정 방향을 추가로 입력하세요 (선택)"
              autoFocus
            />
            <div className="review-request-form__actions">
              <button className="btn btn--outline" onClick={() => setShowRevisionForm(false)} disabled={revisionPending}>
                취소
              </button>
              <button
                className="btn btn--primary"
                onClick={() => handleRequestRevision(revisionInstruction.trim())}
                disabled={revisionPending}
              >
                {revisionPending ? "요청 중..." : "수정 요청"}
              </button>
            </div>
          </div>
        ) : (
          <div className="review-revision-actions">
            <button
              className="btn btn--primary"
              onClick={() => setShowRevisionForm(true)}
              disabled={isRunning || revisionPending}
            >
              {isRunning ? "Claude 수정 중..." : "리뷰 반영 수정 요청"}
            </button>
          </div>
        )}
      </>
    );
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1 className="app-header__title">Claude-Codex Coding Workspace</h1>
        <span className="app-header__subtitle">통합 콘솔 · Phase 6 — 모델·사용량 관리</span>
      </header>

      <nav className="tabs">
        {projects.map((project) => (
          <ProjectTab
            key={project.id}
            project={{ ...project, badge: computeBadge(project.lastTask) }}
            isActive={project.id === activeProjectId}
            onSelect={() => handleSelectProject(project)}
            onRemove={() => handleRemoveProject(project)}
            removePending={projectRemovePendingId === project.id}
          />
        ))}
        {showNewProjectForm ? (
          <form className="new-project-form" onSubmit={handleCreateProject}>
            <input
              className="new-project-form__input"
              type="text"
              value={newProjectName}
              onChange={(e) => setNewProjectName(e.target.value)}
              placeholder="이름 (선택)"
            />
            <input
              className="new-project-form__input new-project-form__input--path"
              type="text"
              value={newProjectPath}
              onChange={(e) => setNewProjectPath(e.target.value)}
              placeholder="git 저장소 절대 경로"
              autoFocus
            />
            <button
              type="button"
              className="btn btn--outline"
              onClick={() => setShowNewProjectForm(false)}
              disabled={newProjectPending}
            >
              취소
            </button>
            <button className="btn btn--primary" type="submit" disabled={newProjectPending || !newProjectPath.trim()}>
              추가
            </button>
          </form>
        ) : (
          <button className="tab tab--ghost" onClick={() => setShowNewProjectForm(true)}>
            + 새 프로젝트
          </button>
        )}
      </nav>

      {settingsDraft && settingsOptions && (
        <section className="agent-settings" aria-label="에이전트 실행 설정">
          <div className="agent-settings__group">
            <strong className="agent-settings__agent">Claude</strong>
            <label className="agent-settings__field">
              <span>모델</span>
              <select
                value={settingsDraft.claude.model}
                onChange={(e) => setSettingsDraft((previous) => ({
                  ...previous,
                  claude: { ...previous.claude, model: e.target.value },
                }))}
                disabled={settingsPending}
              >
                {settingsOptions.models.claude.map((option) => (
                  <option key={option.value} value={option.value}>{option.label}</option>
                ))}
              </select>
            </label>
            <label className="agent-settings__field">
              <span>Effort</span>
              <select
                value={settingsDraft.claude.effort}
                onChange={(e) => setSettingsDraft((previous) => ({
                  ...previous,
                  claude: { ...previous.claude, effort: e.target.value },
                }))}
                disabled={settingsPending}
              >
                {settingsOptions.efforts.claude.map((effort) => (
                  <option key={effort} value={effort}>{effort}</option>
                ))}
              </select>
            </label>
          </div>
          <div className="agent-settings__group">
            <strong className="agent-settings__agent">Codex</strong>
            <label className="agent-settings__field">
              <span>모델</span>
              <select
                value={settingsDraft.codex.model}
                onChange={(e) => setSettingsDraft((previous) => ({
                  ...previous,
                  codex: { ...previous.codex, model: e.target.value },
                }))}
                disabled={settingsPending}
              >
                {settingsOptions.models.codex.map((option) => (
                  <option key={option.value} value={option.value}>{option.label}</option>
                ))}
              </select>
            </label>
            <label className="agent-settings__field">
              <span>Effort</span>
              <select
                value={settingsDraft.codex.effort}
                onChange={(e) => setSettingsDraft((previous) => ({
                  ...previous,
                  codex: { ...previous.codex, effort: e.target.value },
                }))}
                disabled={settingsPending}
              >
                {settingsOptions.efforts.codex.map((effort) => (
                  <option key={effort} value={effort}>{effort}</option>
                ))}
              </select>
            </label>
          </div>
          <button
            type="button"
            className="btn btn--primary agent-settings__save"
            onClick={handleSaveAgentSettings}
            disabled={settingsPending || !settingsDirty}
          >
            {settingsPending ? "저장 중..." : "설정 저장"}
          </button>
        </section>
      )}

      <form className="task-input" onSubmit={handleSubmit}>
        <textarea
          ref={instructionFieldRef}
          className="task-input__field"
          rows={1}
          value={instruction}
          onChange={(e) => setInstruction(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault();
              e.currentTarget.form?.requestSubmit();
            }
          }}
          placeholder="예: 결제 재시도 로직에 지수 백오프를 추가해줘"
          disabled={isRunning || needsReview || !activeProjectId}
          aria-label="Claude 작업 지시"
        />
        <button
          className="task-input__submit"
          type="submit"
          disabled={isRunning || needsReview || !instruction.trim() || !activeProjectId}
        >
          {isRunning ? "작업 중..." : needsReview ? "승인/반려 대기 중" : "Claude에게 지시"}
        </button>
      </form>

      {errorMessage && <div className="task-error">{errorMessage}</div>}

      {taskId && taskStatus && !artifactsCleaned && (
        <div className="task-runtime-actions">
          <button className="btn btn--outline" type="button" onClick={handleOpenFolder} disabled={openFolderPending}>
            {openFolderPending ? "여는 중..." : "작업 폴더 열기"}
          </button>
          {isRunning ? (
            <button className="btn btn--outline" type="button" onClick={handleAbort} disabled={abortPending}>
              {abortPending ? "중단 요청 중..." : "작업 중단"}
            </button>
          ) : (
            ["failed", "aborted", "approved", "rejected"].includes(taskStatus) && (
              <button className="btn btn--outline" type="button" onClick={handleCleanup} disabled={cleanupPending}>
                {cleanupPending ? "정리 중..." : "임시 작업 정리"}
              </button>
            )
          )}
        </div>
      )}

      {!activeProjectId ? (
        <section className="project-empty">
          <h2>등록된 프로젝트가 없습니다</h2>
          <p>상단의 새 프로젝트 버튼에서 Git 저장소 경로를 등록하세요.</p>
        </section>
      ) : !showLive ? (
        <section className="project-empty">
          <h2>아직 실행한 작업이 없습니다</h2>
          <p>위 입력란에 첫 작업을 입력해 Claude에게 전달하세요.</p>
        </section>
      ) : (
        <>
      <section className="status-row">
        {displayStatusSteps.map((step) => (
          <StatusBadge key={step.id} step={step} />
        ))}
      </section>

      <section className="log-panel">
        <div className="log-panel__head">
          <span className="log-panel__title">CLAUDE 작업 로그</span>
          <span className="log-panel__meta">
            <span className="log-panel__dot" />
            {STATUS_LABEL[taskStatus] ?? taskStatus}
          </span>
        </div>
        <div className="log-panel__body">
          {displayLog.map((line, i) => (
            <LogLine key={i} role={line.role} text={line.text} />
          ))}
        </div>
      </section>

      <section className="session-bar">
        <span>
          세션 · <strong>{taskId?.slice(0, 8)}</strong>
        </span>
        {taskAgentConfig && (
          <span className="session-bar__agents">
            Claude {displayConfig(taskAgentConfig.claude)} · Codex {displayConfig(taskAgentConfig.codex)}
          </span>
        )}
        <span className="session-bar__status">{STATUS_LABEL[taskStatus] ?? taskStatus}</span>
      </section>

      {taskRuns.length > 0 && (
        <section className="usage-strip" aria-label="에이전트 사용량">
          {taskRuns.map((run) => <UsageEntry key={run.id} run={run} />)}
        </section>
      )}

      <section className="workspace">
        <div className="workspace__files">
          <div className="workspace__panel-head">변경 파일 ({displayFiles.length})</div>
          <ul className="file-list">
            {displayFiles.map((file) => (
              <li
                key={file.path}
                className={`file-list__item ${file.path === activeFilePath ? "file-list__item--active" : ""} ${showDiff ? "file-list__item--clickable" : ""}`}
                onClick={() => showDiff && setSelectedFilePath(file.path)}
              >
                <span className="file-list__dot" />
                {file.path}
              </li>
            ))}
          </ul>
        </div>

        <div className="workspace__diff">
          <div className="workspace__panel-head">{diffFileLabel}</div>
          <div className="diff-body">
            {diffLines.map((line, i) => (
              <DiffLine key={i} type={line.type} text={line.text} />
            ))}
          </div>
          <div className="diff-footer">
            <span>Claude 변경사항</span>
            {diffFooterContent}
          </div>
        </div>

        <div className="workspace__review">
          <div className="workspace__panel-head">
            <span>CODEX 리뷰 ({reviewCountLabel})</span>
            {showDiff && review && review.status !== "running" && !showReviewForm && !isRunning && (
              <button className="link-btn" onClick={() => setShowReviewForm(true)}>
                다시 요청
              </button>
            )}
          </div>
          {showReviewForm && (
            <div className="review-request-form">
              <input
                className="review-request-form__input"
                type="text"
                value={reviewExtraInstruction}
                onChange={(e) => setReviewExtraInstruction(e.target.value)}
                placeholder="추가로 확인할 내용을 입력하세요 (선택)"
                autoFocus
              />
              <div className="review-request-form__actions">
                <button className="btn btn--outline" onClick={() => setShowReviewForm(false)} disabled={reviewRequestPending}>
                  취소
                </button>
                <button
                  className="btn btn--primary"
                  onClick={() => handleRequestReview(reviewExtraInstruction.trim())}
                  disabled={reviewRequestPending}
                >
                  다시 요청
                </button>
              </div>
            </div>
          )}
          {reviewPanelContent}
        </div>
      </section>
        </>
      )}
    </div>
  );
}

export default App;

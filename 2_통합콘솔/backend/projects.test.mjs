import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { initProjects, listProjects, registerProject, removeProject } from "./projects.mjs";

test("removing a project only removes its console registration", (t) => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cogent-projects-test-"));
  const runtimeRoot = path.join(root, "runtime");
  const projectRoot = path.join(root, "sample-project");
  fs.mkdirSync(path.join(projectRoot, ".git"), { recursive: true });
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));

  initProjects(runtimeRoot);
  const project = registerProject({ name: "sample", projectPath: projectRoot });

  assert.equal(listProjects().length, 1);
  assert.equal(removeProject(project.id)?.id, project.id);
  assert.deepEqual(listProjects(), []);
  assert.equal(fs.existsSync(projectRoot), true);
  assert.deepEqual(
    JSON.parse(fs.readFileSync(path.join(runtimeRoot, "projects.json"), "utf8")),
    []
  );
});

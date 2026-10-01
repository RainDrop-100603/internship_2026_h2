// 단일 파일의 unified diff 텍스트(diff --git ... 헤더 포함)를
// DiffLine 렌더링용 { type, text } 배열로 변환한다.
export function parseFileDiff(patchText) {
  if (!patchText) return [];
  const lines = patchText.split("\n");
  const result = [];
  let inHunk = false;

  for (const line of lines) {
    if (line.startsWith("@@")) {
      inHunk = true;
      result.push({ type: "hunk", text: line });
    } else if (!inHunk) {
      continue; // diff --git / index / --- / +++ 헤더 라인은 건너뜀
    } else if (line.startsWith("+") && !line.startsWith("+++")) {
      result.push({ type: "add", text: line.slice(1) });
    } else if (line.startsWith("-") && !line.startsWith("---")) {
      result.push({ type: "del", text: line.slice(1) });
    } else if (line.startsWith("\\")) {
      // "\ No newline at end of file" 등 메타 라인은 표시하지 않음
    } else {
      result.push({ type: "context", text: line.slice(1) });
    }
  }
  return result;
}

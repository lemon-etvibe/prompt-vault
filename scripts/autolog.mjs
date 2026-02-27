#!/usr/bin/env node
// autolog.mjs — prompt-vault auto-logging engine
// hooks.json에서 직접 호출. stdin으로 훅 JSON 수신, JSONL 파싱, 페이즈 자동 생성.

import { createReadStream, readFileSync, writeFileSync, existsSync, openSync, writeSync, closeSync, unlinkSync, readdirSync } from "node:fs";
import { createInterface } from "node:readline";
import { createHash } from "node:crypto";
import { join } from "node:path";

// === 1. stdin에서 훅 입력 읽기 ===

let rawInput = "";
for await (const chunk of process.stdin) rawInput += chunk;

let hookData;
try {
  hookData = JSON.parse(rawInput);
} catch {
  process.exit(0); // 잘못된 입력 → 조용히 종료
}

const { transcript_path, session_id, cwd, hook_event_name } = hookData;

if (!transcript_path || !cwd) process.exit(0);

// === 2. 프로젝트 로그 디렉토리 확인 ===

const logsDir = join(cwd, ".local", "logs");
if (!existsSync(logsDir)) process.exit(0); // init 안 됨

// === 3. 설정 로드 ===

const configPath = join(logsDir, ".config");
let config = {};
try {
  config = JSON.parse(readFileSync(configPath, "utf8"));
} catch {
  // 설정 파일 없으면 기본값 사용
}

const autoLog = config.autoLog || {};
if (autoLog.enabled !== true) process.exit(0); // opt-in 보호

const turnThreshold = autoLog.turnThreshold || 3;

// === 4. 잠금 파일 ===

const lockPath = join(logsDir, ".autolog.lock");

function acquireLock() {
  try {
    const fd = openSync(lockPath, "wx");
    writeSync(fd, String(process.pid));
    return fd;
  } catch (e) {
    if (e.code === "EEXIST") {
      try {
        const pid = parseInt(readFileSync(lockPath, "utf8"));
        process.kill(pid, 0); // 프로세스 존재 확인
        return null; // 실행 중인 인스턴스 있음
      } catch {
        // 스테일 잠금 → 제거 후 재시도
        try { unlinkSync(lockPath); } catch {}
        return acquireLock();
      }
    }
    return null;
  }
}

function releaseLock(fd) {
  try { closeSync(fd); } catch {}
  try { unlinkSync(lockPath); } catch {}
}

const lockFd = acquireLock();
if (lockFd === null) process.exit(0); // 다른 인스턴스 실행 중

// 이후 모든 exit 경로에서 잠금 해제 보장
process.on("exit", () => releaseLock(lockFd));

// === 5. 상태 파일 로드 ===

const statePath = join(logsDir, "last-log-state.json");
let state = { lastLogTimestamp: 0, lastTranscriptHash: "", lastLogTurnCount: 0, lastPhaseNumber: "000" };
try {
  state = { ...state, ...JSON.parse(readFileSync(statePath, "utf8")) };
} catch {
  // 첫 실행
}

// === 6. Transcript 해시 계산 ===

if (!existsSync(transcript_path)) process.exit(0);

async function computeHash(filePath) {
  const hash = createHash("sha256");
  const stream = createReadStream(filePath);
  for await (const chunk of stream) hash.update(chunk);
  return "sha256:" + hash.digest("hex");
}

const currentHash = await computeHash(transcript_path);

// 해시 동일 → 이미 로깅됨 (Stop → PreCompact 중복 방지)
if (currentHash === state.lastTranscriptHash) process.exit(0);

// === 7. JSONL 파싱 — 턴 카운트 ===

function isHumanTurn(entry) {
  if (entry.type !== "user" || entry.userType !== "external") return false;
  if (entry.isMeta) return false;
  const content = entry.message?.content;
  if (typeof content !== "string") return false;
  if (content.startsWith("<command-name>") || content.startsWith("<local-command")) return false;
  return true;
}

async function parseTurns(transcriptPath, sinceTimestamp) {
  const turns = [];
  let currentTurn = null;
  const rl = createInterface({ input: createReadStream(transcriptPath) });

  for await (const line of rl) {
    let entry;
    try { entry = JSON.parse(line); } catch { continue; }

    if (isHumanTurn(entry)) {
      // sinceTimestamp 이전 턴은 수집하되 카운트에서 제외하기 위해 일단 수집
      if (currentTurn) turns.push(currentTurn);
      currentTurn = {
        userPrompt: entry.message.content,
        timestamp: entry.timestamp,
        assistantTexts: [],
        toolUses: [],
        isNew: !sinceTimestamp || entry.timestamp > sinceTimestamp
      };
    } else if (entry.type === "assistant" && currentTurn) {
      for (const block of (entry.message?.content || [])) {
        if (block.type === "text") currentTurn.assistantTexts.push(block.text);
        else if (block.type === "tool_use") currentTurn.toolUses.push(block.name);
      }
    }
  }
  if (currentTurn) turns.push(currentTurn);
  return turns;
}

const allTurns = await parseTurns(transcript_path, state.lastLogTimestamp);
const newTurns = allTurns.filter(t => t.isNew);

// === 8. 로깅 조건 판단 ===

const event = (hook_event_name || "").toLowerCase();

if (event === "stop" || event === "stophook") {
  // Stop: 새 턴 수가 threshold 미만이면 SKIP
  if (newTurns.length < turnThreshold) process.exit(0);
} else if (event.includes("precompact") || event.includes("pre_compact")) {
  // PreCompact: 새 턴이 1개 이상이면 로깅 (안전망)
  if (newTurns.length < 1) process.exit(0);
} else {
  // 알 수 없는 이벤트 → 기본적으로 threshold 적용
  if (newTurns.length < turnThreshold) process.exit(0);
}

// === 9. 페이즈 번호 결정 ===

function getNextPhaseNumber(dir) {
  try {
    const files = readdirSync(dir).filter(f => /^phase-\d{3}\.md$/.test(f));
    if (files.length === 0) return "001";
    const maxNum = Math.max(...files.map(f => parseInt(f.match(/phase-(\d{3})/)[1])));
    return String(maxNum + 1).padStart(3, "0");
  } catch {
    return "001";
  }
}

const phaseNum = getNextPhaseNumber(logsDir);

// === 10. 페이즈 로그 생성 ===

function inferTitle(turns) {
  if (turns.length === 0) return "Auto-logged phase";
  let title = turns[0].userPrompt.split("\n")[0].trim();
  if (title.length > 50) title = title.slice(0, 47) + "...";
  return title || "Auto-logged phase";
}

function groupToolUses(turns) {
  // 도구별 파일/명령어 그룹핑
  const groups = {};
  for (const turn of turns) {
    for (const tool of turn.toolUses) {
      groups[tool] = (groups[tool] || 0) + 1;
    }
  }
  return groups;
}

function formatActions(turns) {
  const toolGroups = groupToolUses(turns);
  if (Object.keys(toolGroups).length === 0) return "- (conversation only — no tool usage)";
  const lines = [];
  for (const [tool, count] of Object.entries(toolGroups)) {
    lines.push(`- ${tool}: ${count} call${count > 1 ? "s" : ""}`);
  }
  return lines.join("\n");
}

function formatResults(turns) {
  // 마지막 턴의 assistant text에서 요약 추출
  const lastTurn = turns[turns.length - 1];
  if (!lastTurn || lastTurn.assistantTexts.length === 0) return "- (no text response recorded)";

  const lastText = lastTurn.assistantTexts[lastTurn.assistantTexts.length - 1];
  const lines = lastText.split("\n").filter(l => l.trim() && !l.trim().startsWith("```")).slice(0, 3);
  return lines.map(l => {
    const trimmed = l.trim().slice(0, 120);
    return trimmed.startsWith("- ") ? trimmed : `- ${trimmed}`;
  }).join("\n") || "- (see transcript for details)";
}

function formatTrigger(eventName) {
  const e = (eventName || "").toLowerCase();
  if (e === "stop" || e === "stophook") return "Stop (auto)";
  if (e.includes("precompact") || e.includes("pre_compact")) {
    const trigger = hookData.trigger || "auto";
    return `PreCompact-${trigger}`;
  }
  return `${eventName} (auto)`;
}

const today = new Date().toISOString().slice(0, 10);
const title = inferTitle(newTurns);
const triggerLabel = formatTrigger(hook_event_name);

// 사용자 프롬프트 — 여러 턴이면 첫 번째 턴 사용
const firstPrompt = newTurns.length > 0 ? newTurns[0].userPrompt : "(no prompt recorded)";
// 인용 블록 형식 (> 접두어)
const quotedPrompt = firstPrompt.split("\n").map(l => `> ${l}`).join("\n");

const phaseContent = `# Phase ${phaseNum}: ${title}

- **Date**: ${today}
- **Session**: ${session_id || "unknown"}
- **Trigger**: ${triggerLabel}

## User Prompt
${quotedPrompt}

## Actions
${formatActions(newTurns)}

## Results
${formatResults(newTurns)}

## Decisions
- (auto-logged — review recommended)

## Next
- (auto-logged — review recommended)
`;

// === 11. 파일 저장 ===

const phasePath = join(logsDir, `phase-${phaseNum}.md`);
writeFileSync(phasePath, phaseContent, "utf8");

// === 12. _index.md 업데이트 ===

const indexPath = join(logsDir, "_index.md");
if (existsSync(indexPath)) {
  let indexContent = readFileSync(indexPath, "utf8");
  // 한 줄 요약 생성
  const summary = `Auto-logged (${newTurns.length} turns, ${triggerLabel})`;
  const newRow = `| ${phaseNum} | ${title} | done | ${today} | ${summary} |`;

  // 테이블 끝에 행 추가
  if (indexContent.endsWith("\n")) {
    indexContent += newRow + "\n";
  } else {
    indexContent += "\n" + newRow + "\n";
  }
  writeFileSync(indexPath, indexContent, "utf8");
}

// === 13. 상태 파일 업데이트 ===

const totalTurnCount = (state.lastLogTurnCount || 0) + newTurns.length;
const newState = {
  lastLogTimestamp: newTurns[newTurns.length - 1]?.timestamp || Date.now(),
  lastTranscriptHash: currentHash,
  lastLogTurnCount: totalTurnCount,
  lastPhaseNumber: phaseNum,
  lastTrigger: event
};
writeFileSync(statePath, JSON.stringify(newState, null, 2) + "\n", "utf8");

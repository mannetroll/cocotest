#!/usr/bin/env bash
# Generate a session timeline HTML report from a Cortex Code session transcript.
# Usage: ./session_timeline.sh <session-id> [output.html]

set -euo pipefail

SESSION_ID="${1:?Usage: $0 <session-id> [output.html]}"
OUTPUT="${2:-session_timeline_${SESSION_ID:0:8}.html}"
TMPFILE=$(mktemp)

trap 'rm -f "$TMPFILE"' EXIT

# Dump transcript to temp file
cortex conversations transcript --output=json "$SESSION_ID" > "$TMPFILE" 2>/dev/null

# Generate HTML from transcript
python3 - "$SESSION_ID" "$TMPFILE" "$OUTPUT" <<'PYTHON'
import json, sys, os

session_id = sys.argv[1]
tmpfile = sys.argv[2]
output_path = sys.argv[3]

# Parse JSONL (each line is a JSON object, but some lines may be continuations)
msgs = []
with open(tmpfile) as f:
    raw = f.read()

# Try JSONL first, fall back to splitting on newline-delimited objects
for line in raw.split('\n'):
    line = line.strip()
    if not line:
        continue
    try:
        msgs.append(json.loads(line))
    except json.JSONDecodeError:
        # Try accumulating lines for multi-line JSON
        pass

# If JSONL didn't work well, try as a JSON array
if len(msgs) < 2:
    try:
        msgs = json.loads(raw)
    except:
        pass

# Extract assistant turns
results = []
tool_results_by_idx = {}

for i, m in enumerate(msgs):
    role = m.get('role')
    content = m.get('content', '')
    if isinstance(content, str):
        content = [{'type': 'text', 'text': content}]

    if role == 'user':
        for item in content:
            if isinstance(item, dict) and item.get('type') == 'tool_result':
                tr = item.get('tool_result', {})
                name = tr.get('name', '')
                if name:
                    tool_results_by_idx.setdefault(i, []).append(name)
        continue

    if role != 'assistant':
        continue

    ts = m.get('assistantSentTime', '')
    thinking_len = 0
    text_len = 0
    tools = []

    for item in content:
        if not isinstance(item, dict):
            continue
        if item.get('type') == 'thinking':
            td = item.get('thinking', {})
            thinking_len += len(td.get('text', '')) if isinstance(td, dict) else len(str(td))
        elif item.get('type') == 'text':
            text_len += len(item.get('text', ''))
        elif item.get('type') == 'tool_use':
            tools.append(item.get('name', 'unknown'))

    results.append({'idx': i, 'ts': ts, 'think': thinking_len, 'text': text_len, 'tools': tools})

# Resolve tool names from tool_result responses
for r in results:
    next_idx = r['idx'] + 1
    if next_idx in tool_results_by_idx:
        actual = tool_results_by_idx[next_idx]
        if all(t == 'unknown' for t in r['tools']):
            r['tools'] = actual
        elif 'unknown' in r['tools']:
            r['tools'] = actual

total_msgs = len(msgs)
total_think = sum(r['think'] for r in results)
total_text = sum(r['text'] for r in results)
total_tools = sum(len(r['tools']) for r in results)

def fmt_k(n):
    return f'~{n/1000:.1f}k' if n >= 1000 else str(n)

msgs_json = json.dumps(results)

html = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Session Timeline — {session_id[:8]}</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{
      font-family: -apple-system, system-ui, sans-serif;
      max-width: 1100px; margin: 0 auto; padding: 24px;
      color: light-dark(#1f2937, #e5e7eb);
      background: light-dark(#ffffff, #111827);
    }}
    h1, h2 {{ color: light-dark(#0f172a, #f1f5f9); }}
    .subtitle {{ color: light-dark(#6b7280, #9ca3af); font-size: 0.9em; margin-top: -12px; }}
    .stats {{ display: flex; gap: 24px; flex-wrap: wrap; margin: 20px 0; }}
    .stat-card {{
      background: light-dark(#f9fafb, #1f2937);
      border: 1px solid light-dark(#e5e7eb, #374151);
      border-radius: 8px; padding: 16px 20px; min-width: 140px;
    }}
    .stat-card .value {{ font-size: 1.8em; font-weight: 700; color: light-dark(#1d4ed8, #60a5fa); }}
    .stat-card .label {{ font-size: 0.85em; color: light-dark(#6b7280, #9ca3af); margin-top: 4px; }}
    table {{ border-collapse: collapse; width: 100%; margin: 16px 0; font-size: 0.85em; }}
    th, td {{ border: 1px solid light-dark(#d1d5db, #374151); padding: 5px 8px; text-align: left; }}
    th {{ background: light-dark(#f3f4f6, #1f2937); font-weight: 600; }}
    tr:nth-child(even) {{ background: light-dark(#f9fafb, #111827); }}
    .tool-badge {{
      display: inline-block; background: light-dark(#dbeafe, #1e3a5f);
      color: light-dark(#1d4ed8, #93c5fd); border-radius: 4px;
      padding: 1px 6px; margin: 1px 2px; font-size: 0.8em;
    }}
  </style>
</head>
<body>

  <h1>Session Timeline</h1>
  <p class="subtitle">Session {session_id}</p>

  <div class="stats">
    <div class="stat-card"><div class="value">{total_msgs}</div><div class="label">Messages</div></div>
    <div class="stat-card"><div class="value">{fmt_k(total_think)}</div><div class="label">Thinking chars</div></div>
    <div class="stat-card"><div class="value">{fmt_k(total_text)}</div><div class="label">Output chars</div></div>
    <div class="stat-card"><div class="value">{total_tools}</div><div class="label">Tool calls</div></div>
  </div>

  <h2>Activity Timeline</h2>
  <canvas id="timeline" width="1050" height="400"></canvas>

  <h2>Tool Usage</h2>
  <canvas id="tools-chart" width="1050" height="250"></canvas>

  <h2>Message Detail</h2>
  <table>
    <thead><tr><th>#</th><th>Time</th><th>Thinking</th><th>Output</th><th>Tools</th></tr></thead>
    <tbody id="detail-table"></tbody>
  </table>

  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>
  <script>
    var messages = {msgs_json};

    var labels = messages.map(function(m) {{ return m.ts ? m.ts.substring(11, 16) : m.idx.toString(); }});
    var thinkData = messages.map(function(m) {{ return m.think; }});
    var textData = messages.map(function(m) {{ return m.text; }});

    new Chart(document.getElementById("timeline"), {{
      type: "bar",
      data: {{
        labels: labels,
        datasets: [
          {{ label: "Thinking (chars)", data: thinkData, backgroundColor: "rgba(99, 102, 241, 0.7)" }},
          {{ label: "Output text (chars)", data: textData, backgroundColor: "rgba(34, 197, 94, 0.7)" }}
        ]
      }},
      options: {{
        responsive: false,
        plugins: {{ title: {{ display: true, text: "Characters per Assistant Turn" }} }},
        scales: {{
          x: {{ title: {{ display: true, text: "Time (HH:MM)" }}, ticks: {{ maxRotation: 45 }} }},
          y: {{ title: {{ display: true, text: "Characters" }}, beginAtZero: true }}
        }}
      }}
    }});

    var toolCounts = {{}};
    messages.forEach(function(m) {{ m.tools.forEach(function(t) {{ toolCounts[t] = (toolCounts[t] || 0) + 1; }}); }});
    var toolLabels = Object.keys(toolCounts).sort(function(a, b) {{ return toolCounts[b] - toolCounts[a]; }});
    var toolValues = toolLabels.map(function(t) {{ return toolCounts[t]; }});
    var toolColors = ["#3b82f6","#ef4444","#f59e0b","#10b981","#8b5cf6","#ec4899","#06b6d4","#84cc16"];

    new Chart(document.getElementById("tools-chart"), {{
      type: "doughnut",
      data: {{ labels: toolLabels, datasets: [{{ data: toolValues, backgroundColor: toolColors.slice(0, toolLabels.length) }}] }},
      options: {{ responsive: false, plugins: {{ title: {{ display: true, text: "Tool Calls by Type" }}, legend: {{ position: "right" }} }} }}
    }});

    var tbody = document.getElementById("detail-table");
    messages.forEach(function(m) {{
      var tr = document.createElement("tr");
      var toolsHtml = m.tools.map(function(t) {{ return "<span class=\\"tool-badge\\">" + t + "</span>"; }}).join("");
      tr.innerHTML = "<td>" + m.idx + "</td><td>" + (m.ts || "").substring(5, 16) + "</td><td>" + m.think.toLocaleString() + "</td><td>" + m.text.toLocaleString() + "</td><td>" + (toolsHtml || "\\u2014") + "</td>";
      tbody.appendChild(tr);
    }});
  </script>

</body>
</html>'''

with open(output_path, 'w') as f:
    f.write(html)
print(f'Written: {output_path}')
PYTHON

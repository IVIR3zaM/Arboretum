// The grader. Runs the hidden acceptance suite under three server timezones and
// reports the worst-case score — a case only counts as passing if it passes in
// every timezone. A fix that works only on the machine you happen to be on does
// not count.
//
//   node _solutions/grade.mjs
//
// Zero dependencies; uses the Node test runner's TAP output.

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const suite = join(here, "acceptance.test.ts");
const TIMEZONES = ["UTC", "America/Los_Angeles", "Asia/Tokyo"];

function runUnder(tz) {
  const res = spawnSync(process.execPath, ["--test", "--test-reporter=tap", suite], {
    env: { ...process.env, TZ: tz },
    encoding: "utf8",
  });
  const out = `${res.stdout}\n${res.stderr}`;
  const pass = Number((out.match(/^# pass (\d+)/m) ?? [])[1] ?? 0);
  const fail = Number((out.match(/^# fail (\d+)/m) ?? [])[1] ?? 0);
  const total = Number((out.match(/^# tests (\d+)/m) ?? [])[1] ?? pass + fail);
  return { tz, pass, fail, total };
}

const runs = TIMEZONES.map(runUnder);
const total = Math.max(...runs.map((r) => r.total), 0);
const worstCase = Math.min(...runs.map((r) => r.pass));

console.log("Acceptance grade — cutoff correctness + the skip feature, across server timezones\n");
for (const r of runs) {
  const mark = r.fail === 0 ? "PASS" : "FAIL";
  console.log(`  TZ=${r.tz.padEnd(20)} ${r.pass}/${r.total}  ${mark}`);
}
console.log(`\n  Worst-case score: ${worstCase}/${total}`);
console.log(
  worstCase === total && total > 0
    ? "  ✅ Cutoffs hold in every timezone and the skip feature meets the agreed behaviour.\n"
    : "  ❌ Not there yet — a cutoff lands at the wrong instant for customers outside the\n" +
      "     server's timezone, and/or skipping the next box does not do what was agreed.\n",
);

process.exit(worstCase === total && total > 0 ? 0 : 1);

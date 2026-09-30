// Exercises actual stdio -> authenticated WebSocket -> Godot editor round trips.
import { spawn } from "node:child_process";
import { writeFileSync, readFileSync, existsSync, mkdirSync, openSync, closeSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import assert from "node:assert/strict";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sdk = join(root, ".tools/research/NPGameDev--godot-mcp-server/node_modules/@modelcontextprotocol/sdk/dist/esm");
const { Client } = await import(pathToFileURL(join(sdk, "client/index.js")));
const { StdioClientTransport } = await import(pathToFileURL(join(sdk, "client/stdio.js")));
const engine = join(root, ".tools/godot/Godot.app/Contents/MacOS/Godot");
const reports = join(root, "reports/local");
mkdirSync(reports, { recursive: true });
const logPath = join(reports, "mcp-editor.log");
const output = openSync(logPath, "w");
const editor = spawn(engine, ["--headless", "--editor", "--path", join(root, "game"), "--log-file", join(reports, "mcp-editor-engine.log")], { stdio: ["ignore", output, output] });
const checks = [];
const clients = [];
let failed = null;
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));

function decode(result) {
  const block = result.content?.find(item => item.type === "text");
  return block ? JSON.parse(block.text) : {};
}

async function connection(readOnly = false) {
  const client = new Client({ name: "gopala-verification", version: "1.0.0" }, { capabilities: {} });
  const args = [join(root, "tools/start_mcp.py")];
  if (readOnly) args.push("--read-only");
  const transport = new StdioClientTransport({ command: "/opt/homebrew/bin/python3", args, cwd: root, stderr: "pipe" });
  // Avoid ever recording auth values; MCP diagnostics are not game evidence.
  transport.stderr?.on("data", () => {});
  await client.connect(transport);
  clients.push(client);
  return client;
}

async function call(client, name, args = {}, expectError = false) {
  const result = await client.callTool({ name, arguments: args }, undefined, { timeout: 20000 });
  const value = decode(result);
  assert.equal(Boolean(result.isError), expectError, `${name}: ${JSON.stringify(value)}`);
  if (!expectError) assert.notEqual(value.success, false, `${name}: failed operation`);
  checks.push({ tool: name, ok: true, expected_error: expectError });
  return value;
}

try {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline && !readFileSync(logPath, "utf8").includes("[MCPServer] listening on 127.0.0.1:")) {
    assert.equal(editor.exitCode, null, "Editor exited before becoming ready");
    await wait(200);
  }
  assert.match(readFileSync(logPath, "utf8"), /\[MCPServer\] listening on 127\.0\.0\.1:/, "Editor bridge readiness");
  const client = await connection();
  const names = (await client.listTools()).tools.map(tool => tool.name);
  assert(names.includes("gopala_content_audit") && names.includes("gopala_catalog"), "Custom extension discovery");
  checks.push({ test: "custom-extension-discovered", ok: true });
  const audit = await call(client, "gopala_content_audit");
  assert.equal(audit.validation_passed, true);
  await call(client, "gopala_catalog");
  await call(client, "discover_tools", { request: ["cleanup", "tilemap", "tileset", "spriteframes", "navigation"], include_schemas: true });
  await call(client, "script_check", { file_path: "res://scenes/content_lab.gd" });
  const denied = await call(client, "script_read", { file_path: "res://../../outside.gd" }, true);
  assert.equal(denied.code, "PATH_DENIED");
  const invalid = await call(client, "script_write", { file_path: "res://tests/mcp_probe.gd", content: "extends Node\nfunc broken(:\n" });
  assert.equal(invalid.valid, false, "Broken script must return diagnostics");
  const valid = await call(client, "script_write", { file_path: "res://tests/mcp_probe.gd", content: "extends Node\nfunc probe() -> int:\n\treturn 7\n" });
  assert.equal(valid.valid, true);
  await call(client, "script_delete", { file_path: "res://tests/mcp_probe.gd" });
  await call(client, "scene_create", { file_path: "res://tests/mcp_probe.tscn", root_type: "Node2D", root_name: "MCPProbe", if_exists: "fail" });
  await call(client, "scene_open", { file_path: "res://tests/mcp_probe.tscn" });
  await call(client, "scene_create_node", { class_name: "Sprite2D", parent_path: ".", node_name: "VerifiedSprite" });
  await call(client, "editor_save_scene");
  const tree = await call(client, "scene_get_tree", { max_depth: -1 });
  assert(JSON.stringify(tree).includes("VerifiedSprite"), "Created node must appear in editor tree");
  assert(readFileSync(join(root, "game/tests/mcp_probe.tscn"), "utf8").includes("VerifiedSprite"), "Created node must persist to disk");
  await call(client, "scene_delete", { file_path: "res://tests/mcp_probe.tscn" });
  await call(client, "scene_open", { file_path: "res://scenes/content_lab.tscn" });
  const grouped = (await client.listTools()).tools.map(tool => tool.name);
  assert(grouped.includes("tilemap_set_cells") && grouped.some(name => name.startsWith("tileset_")), "2D tool groups must load");
  checks.push({ test: "2d-groups-discovered", ok: true });
  const readOnly = await connection(true);
  const readOnlyNames = (await readOnly.listTools()).tools.map(tool => tool.name);
  assert(readOnlyNames.includes("gopala_content_audit"));
  assert(!readOnlyNames.includes("script_write") && !readOnlyNames.includes("scene_create_node"), "Read-only mode must omit mutating tools");
  await call(readOnly, "gopala_content_audit");
  checks.push({ test: "read-only-registration", ok: true });
} catch (error) {
  failed = String(error.stack ?? error);
} finally {
  for (const client of clients.reverse()) await client.close().catch(() => {});
  editor.kill("SIGTERM");
  await Promise.race([new Promise(resolve => editor.once("exit", resolve)), wait(3000)]);
  if (editor.exitCode === null) editor.kill("SIGKILL");
  closeSync(output);
  const remains = ["mcp_probe.gd", "mcp_probe.gd.uid", "mcp_probe.tscn"].filter(file => existsSync(join(root, "game/tests", file)));
  if (remains.length) failed ??= "Temporary fixtures remain: " + remains.join(", ");
  const report = { ok: !failed, checks, failure: failed, node: process.version, scope: "Stdio MCP handshake, custom tools, guarded paths, script diagnostics and repair, scene mutation/save/read/delete, 2D group discovery, read-only registration. No full 112-tool or runtime render coverage." };
  writeFileSync(join(root, "reports/mcp-verification.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(`MCP verification: ${failed ? "FAIL" : "PASS"} (${checks.length} checks)`);
  if (failed) console.error(failed);
  process.exitCode = failed ? 1 : 0;
}

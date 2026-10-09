// graphify OpenCode plugin (OpenCode V2 plugin API)
//
// WARNING: `graphify install` OVERWRITES this file with a V1 plugin
// (`export const GraphifyPlugin = async ({directory}) => ({...})`) and rewrites
// .opencode/opencode.json with a V1 `"plugin"` key. Both fail under OpenCode V2:
//   - the named export  -> PluginModule.LoadError: Missing key "default"
//   - the "plugin" key  -> resolved as an npm package spec -> NpmInstallFailedError
// After running graphify install, re-apply this file and reset the config to
// just "$schema". Graphify 0.9.77 has not shipped a V2 plugin yet.
import { existsSync } from "fs";
import { join } from "path";

// Reach for `path` and `explain` BEFORE `query`. Measured on 9 October 2026:
// asking "how are alarm rules evaluated in Dart and Kotlin" via `query` returned
// 553 nodes, truncated to 59 inside the 2000-token default, and mixed in
// `dart:math`, `String? get` and `return`. Asking the same question as
// `graphify path "buildAlarmRules" "AlarmCheckRunner" --undirected` returned
// five hops, all of them real, crossing the Dart/Kotlin boundary. BFS widens;
// `path` between two named symbols does not.
//
// `--undirected` is not optional. The graph is built undirected, so `path`
// without it reports "no directed path found" for paths that plainly exist.
//
// The third sentence is the one that saves the most. `graph.json` is ~2.8 MB
// and `graph.html` ~2.4 MB; `query`/`path`/`explain` read them inside the
// process and return a scoped slice, so only the slice ever enters context.
// Reading those files directly is what would blow up a session.
// NO BACKTICKS AND NO DOUBLE QUOTES in the message body. That is not style: this
// string is prepended to a real shell command, and the shell on Windows is
// PowerShell, where the backtick is the escape character and a backslash is not
// an escape at all. A first draft used backtick-quoted code spans and backslash-
// escaped quotes; PowerShell consumed the backticks as escapes and passed the
// backslashes through literally, so the reminder printed as
// "prefer graphify path \ A\ \B\ --undirected". Verified by running it, not by
// reading it. Single quotes are used for the example arguments instead -- inside
// a PowerShell double-quoted string a single quote is an ordinary character.
const REMINDER =
  'echo "[graphify] graph at graphify-out/ - never read graph.json or graph.html directly (~3 MB each; query/path/explain read them internally and return only a scoped slice). Prefer graphify path \'A\' \'B\' --undirected, or graphify explain \'X\'; use graphify query last with a small --budget, since it widens into noise. Run graphify update . first if the graph may be stale." ; ';

// NOTE ON SHAPE. V2 requires a *default* export with an `id` and a `setup`
// function. The docs idiom is `Plugin.define({...})` from `@opencode/plugin`,
// deliberately NOT imported here: it does not resolve for a local file plugin
// without a node_modules folder above this file, which would mean committing
// node_modules into this repo. A plain object literal satisfies the same schema
// with no dependency.
export default {
  id: "graphify",
  async setup(ctx) {
    // V1 received `{ directory }` as an argument to the exported function.
    // V2 exposes it on the plugin context as `ctx.location.directory`.
    const directory = ctx.location.directory;

    if (!existsSync(join(directory, "graphify-out", "graph.json"))) return;

    // Resolved from the live registry rather than hardcoded. V1's tool was
    // named "bash"; in V2 it is "shell" (verified against ctx.tool.list()).
    // `list()` is async.
    const tools = await ctx.tool.list();
    const shellTool = tools.find((tool) => tool.id === "shell" || tool.id === "bash");

    if (!shellTool) return;

    let reminded = false;

    return ctx.tool.hook("execute.before", (event) => {
      if (reminded) return;
      if (event.tool !== shellTool.id) return;

      // V1 mutated `output.args.command`; V2 exposes the tool input as
      // `event.input`.
      // ';' not '&&' — Windows PowerShell 5.1 rejects '&&' as a statement
      // separator, breaking the first shell command of the session (#1646).
      event.input.command = REMINDER + event.input.command;
      reminded = true;
    });
  },
};

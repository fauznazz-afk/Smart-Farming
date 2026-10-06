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

const REMINDER =
  'echo "[graphify] knowledge graph at graphify-out/. For focused questions, run graphify query with your question (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context." ; ';

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

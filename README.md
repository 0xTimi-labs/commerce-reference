# commerce-reference

[![CI](https://github.com/0xTimi-labs/commerce-reference/actions/workflows/ci.yml/badge.svg)](https://github.com/0xTimi-labs/commerce-reference/actions/workflows/ci.yml)

`commerce-reference` 是一个完全 greenfield 的商业系统参考实现。当前阶段只建立 GitHub Actions/CI 基建，不包含业务源码、产品骨架或旧项目兼容代码。

## Required checks

### `CI / Required`

`CI` 在 Pull Request、Merge Queue 的 `checks_requested` 和手动触发时运行：

1. planner 根据当前文件提供机器证据，只识别项目确定需要的 Rust 与 Node.js 技术栈；
2. contract job 验证 workflow、review skill、模型契约和 CI 脚本；
3. planned leaf 必须成功，未 planned leaf 必须为 `skipped`；
4. `CI / Required` 使用 `always()` 校验全部状态，意外跳过、失败或取消不会误绿。

PR 使用 quick 模式；Merge Queue 使用 full 模式。技术栈出现后必须同时提交确定性工具链文件和锁文件：Rust 使用 `rust-toolchain.toml`、`Cargo.lock`，Node.js 使用 `.node-version`、`package-lock.json`。

### `Review / Required`

AI Review 使用仓库内 GitHub Actions、固定版本 Pi CLI、DeepSeek V4 Flash 和受保护 base revision 中的 `code-reviewer` skill：

- 只审查事件携带的 exact head SHA；
- 模型配置、skill 和结果校验器均从受保护 base SHA 读取，不信任 PR 中的版本；
- Pi 不启用任何工具，只接收有大小上限的 review context 和 diff，不执行或任意读取 PR 内容；
- 同一 PR 的 Pi session 通过 Actions cache 延续，session 总是在结论判断前保存；
- 缺少 `DEEPSEEK_API_KEY`、Pi/缓存异常、报告不完整、SHA 不一致或存在 must-fix 均失败；
- fork PR 无法获得 secret，因此保持 fail-closed。

仓库需要配置 Actions secret `DEEPSEEK_API_KEY`。不要把真实 key 写入仓库、日志或模型配置文件。

## 本地验证

```sh
sh ci/verify.sh quick
sh ci/verify.sh full
```

验证覆盖 shell 语法、ShellCheck（可用时）、Actionlint、固定 action SHA、最小权限、受信审查资产、模型端点、planner、required 聚合及 AI Review 终结记录。

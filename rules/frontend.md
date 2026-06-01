# 前端代码审查专项规则（React / Vue / Angular）

## 1. React
- [ ] `useEffect` 依赖数组是否完整？（`react-hooks/exhaustive-deps`）
- [ ] `useState` 初始值是否为函数（避免每次渲染重新计算）？
- [ ] `useCallback`/`useMemo` 是否真正需要（不要过度优化）？
- [ ] `key` 是否稳定且唯一（不用 index 作为 key）？
- [ ] 组件 props 是否有 TypeScript 类型定义？
- [ ] `dangerouslySetInnerHTML` 是否必须经过 XSS 过滤？
- [ ] Context 是否在过度渲染时拆分（避免大对象全量更新）？
- [ ] `forwardRef` 是否正确使用？

## 2. Vue
- [ ] `v-for` 是否带 `:key`？
- [ ] `v-if` 和 `v-for` 是否在同一元素（优先级问题）？
- [ ] `computed` 是否有副作用？
- [ ] `watch` 是否深度监听导致性能问题？
- [ ] `nextTick` 是否在 DOM 更新后操作？
- [ ] 组件名是否多词驼峰（避免与 HTML 冲突）？
- [ ] `provide/inject` 是否类型安全（Vue 3 + TS）？

## 3. 通用前端
- [ ] 图片是否有 `alt` 文本？
- [ ] 表单是否有 `label` 关联？
- [ ] 异步请求是否有 loading 和错误状态？
- [ ] 路由跳转是否有权限拦截？
- [ ] 本地存储是否加密敏感信息？
- [ ] 事件监听是否在组件卸载时移除？
- [ ] 大列表是否虚拟滚动（`react-window`、`vue-virtual-scroller`）？
- [ ] CSS 是否避免内联样式（用 class）？
- [ ] 是否支持响应式/移动端适配？

## 4. 性能
- [ ] 是否懒加载路由/组件？
- [ ] 图片是否懒加载/压缩/WebP？
- [ ] 第三方库是否按需引入（tree-shaking）？
- [ ] 是否避免重复 HTTP 请求（请求合并/缓存）？

## 5. 安全
- [ ] 用户输入是否在渲染前转义？
- [ ] URL 参数是否校验？
- [ ] 本地存储 Token 是否设置过期？
- [ ] CSP 是否配置？

## 6. Node.js / 服务端
- [ ] `process.exit()` 是否滥用（应优先 graceful shutdown）？
- [ ] 未捕获异常是否通过 `process.on('uncaughtException')` 处理？
- [ ] Promise  rejection 是否通过 `process.on('unhandledRejection')` 监听？
- [ ] Express/Koa/Fastify 中间件是否有错误处理（`next(err)` / `app.on('error')`）？
- [ ] 路由是否都有认证/授权拦截（避免未授权访问）？
- [ ] `req.body` / 查询参数是否经过校验（Joi / Zod / class-validator）？
- [ ] 文件上传是否限制类型、大小、存储路径（防止目录遍历）？
- [ ] `EventEmitter` 监听器是否在不需要时移除（防止内存泄漏）？
- [ ] `setInterval` / `setTimeout` 是否在服务关闭时清理？
- [ ] Stream / Buffer 是否正确处理 `error` 事件和背压（backpressure）？
- [ ] `cluster` / `worker_threads` 是否正确管理生命周期和通信？
- [ ] 敏感配置（DB 密码、API Key）是否放在环境变量而非代码中？
- [ ] `require()` 的模块路径是否使用绝对路径或路径解析（避免路径混淆）？
- [ ] `fs` / `path` 操作是否校验用户输入路径（防止目录遍历攻击）？
- [ ] `child_process.exec` 是否被使用（应优先 `execFile` / `spawn` 防止命令注入）？

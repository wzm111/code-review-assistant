# 前端代码审查专项规则（React / Vue / Angular）

## 1. React
- [id: frontend:react-hooks-exhaustive-deps] [ ] `useEffect` 依赖数组是否完整？（`react-hooks/exhaustive-deps`）
- [id: frontend:useState-lazy-initial] [ ] `useState` 初始值是否为函数（避免每次渲染重新计算）？
- [id: frontend:usecallback-usememo-overuse] [ ] `useCallback`/`useMemo` 是否真正需要（不要过度优化）？
- [id: frontend:react-key-stability] [ ] `key` 是否稳定且唯一（不用 index 作为 key）？
- [id: frontend:typescript-props-types] [ ] 组件 props 是否有 TypeScript 类型定义？
- [id: frontend:dangerouslysetinnerhtml-xss] [ ] `dangerouslySetInnerHTML` 是否必须经过 XSS 过滤？
- [id: frontend:context-split-re-render] [ ] Context 是否在过度渲染时拆分（避免大对象全量更新）？
- [id: frontend:forwardref-usage] [ ] `forwardRef` 是否正确使用？

## 2. Vue
- [id: frontend:vue-vfor-key] [ ] `v-for` 是否带 `:key`？
- [id: frontend:vue-vif-vfor-same-element] [ ] `v-if` 和 `v-for` 是否在同一元素（优先级问题）？
- [id: frontend:vue-computed-side-effects] [ ] `computed` 是否有副作用？
- [id: frontend:vue-watch-deep-performance] [ ] `watch` 是否深度监听导致性能问题？
- [id: frontend:vue-nexttick-usage] [ ] `nextTick` 是否在 DOM 更新后操作？
- [id: frontend:vue-component-name-casing] [ ] 组件名是否多词驼峰（避免与 HTML 冲突）？
- [id: frontend:vue-provide-inject-types] [ ] `provide/inject` 是否类型安全（Vue 3 + TS）？

## 3. 通用前端
- [id: frontend:img-alt-text] [ ] 图片是否有 `alt` 文本？
- [id: frontend:form-label-association] [ ] 表单是否有 `label` 关联？
- [id: frontend:async-loading-error-state] [ ] 异步请求是否有 loading 和错误状态？
- [id: frontend:route-auth-guard] [ ] 路由跳转是否有权限拦截？
- [id: frontend:localstorage-sensitive-encrypt] [ ] 本地存储是否加密敏感信息？
- [id: frontend:event-listener-cleanup] [ ] 事件监听是否在组件卸载时移除？
- [id: frontend:virtual-scroll-large-list] [ ] 大列表是否虚拟滚动（`react-window`、`vue-virtual-scroller`）？
- [id: frontend:avoid-inline-styles] [ ] CSS 是否避免内联样式（用 class）？
- [id: frontend:responsive-mobile-adapt] [ ] 是否支持响应式/移动端适配？

## 4. 性能
- [id: frontend:lazy-load-route-component] [ ] 是否懒加载路由/组件？
- [id: frontend:image-lazy-compress-webp] [ ] 图片是否懒加载/压缩/WebP？
- [id: frontend:tree-shaking-import] [ ] 第三方库是否按需引入（tree-shaking）？
- [id: frontend:deduplicate-http-requests] [ ] 是否避免重复 HTTP 请求（请求合并/缓存）？

## 5. 安全
- [id: frontend:input-escape-before-render] [ ] 用户输入是否在渲染前转义？
- [id: frontend:url-param-validation] [ ] URL 参数是否校验？
- [id: frontend:token-expiration-localstorage] [ ] 本地存储 Token 是否设置过期？
- [id: frontend:csp-config] [ ] CSP 是否配置？

## 6. Node.js / 服务端
- [id: frontend:process-exit-abuse] [ ] `process.exit()` 是否滥用（应优先 graceful shutdown）？
- [id: frontend:uncaughtexception-handler] [ ] 未捕获异常是否通过 `process.on('uncaughtException')` 处理？
- [id: frontend:unhandledrejection-listener] [ ] Promise  rejection 是否通过 `process.on('unhandledRejection')` 监听？
- [id: frontend:middleware-error-handling] [ ] Express/Koa/Fastify 中间件是否有错误处理（`next(err)` / `app.on('error')`）？
- [id: frontend:route-authz-interceptor] [ ] 路由是否都有认证/授权拦截（避免未授权访问）？
- [id: frontend:req-body-validation] [ ] `req.body` / 查询参数是否经过校验（Joi / Zod / class-validator）？
- [id: frontend:file-upload-restrictions] [ ] 文件上传是否限制类型、大小、存储路径（防止目录遍历）？
- [id: frontend:eventemitter-listener-cleanup] [ ] `EventEmitter` 监听器是否在不需要时移除（防止内存泄漏）？
- [id: frontend:setinterval-timeout-cleanup] [ ] `setInterval` / `setTimeout` 是否在服务关闭时清理？
- [id: frontend:stream-buffer-backpressure] [ ] Stream / Buffer 是否正确处理 `error` 事件和背压（backpressure）？
- [id: frontend:cluster-worker-lifecycle] [ ] `cluster` / `worker_threads` 是否正确管理生命周期和通信？
- [id: frontend:secrets-in-env] [ ] 敏感配置（DB 密码、API Key）是否放在环境变量而非代码中？
- [id: frontend:require-absolute-path] [ ] `require()` 的模块路径是否使用绝对路径或路径解析（避免路径混淆）？
- [id: frontend:fs-path-user-input-check] [ ] `fs` / `path` 操作是否校验用户输入路径（防止目录遍历攻击）？
- [id: frontend:child-process-exec-injection] [ ] `child_process.exec` 是否被使用（应优先 `execFile` / `spawn` 防止命令注入）？

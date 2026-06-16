# PHP 代码审查专项规则

## 1. 语言特性
- [id: php:strict-compare] [ ] `==` 是否用于类型安全比较（应用 `===`）？
- [id: php:empty-misjudge] [ ] `empty()` 是否误判 `0`/`'0'`/`false`？
- [id: php:isset-vs-key-exists] [ ] 数组操作是否区分 `isset()` / `array_key_exists()`？
- [id: php:closure-use] [ ] 闭包是否用 `use` 正确捕获变量？
- [id: php:trait-conflict] [ ] `trait` 是否解决冲突（`insteadof` / `as`）？

## 2. Laravel
- [id: php:eloquent-eager-load] [ ] Eloquent 查询是否用 `with()` 预加载关系（防 N+1）？
- [id: php:bulk-insert-update] [ ] 批量操作是否用 `insert()` / `update()` 而非循环？
- [id: php:should-queue] [ ] 队列任务是否实现 `ShouldQueue`？
- [id: php:resource-routes] [ ] 路由是否用资源路由（RESTful）？
- [id: php:csrf-blade] [ ] Blade 中是否用 `@csrf` 保护表单？
- [id: php:env-config] [ ] `.env` 变量是否通过 `config()` 读取（非直接 `$_ENV`）？

## 3. 安全
- [id: php:sql-injection] [ ] SQL 是否用 Eloquent/Query Builder（防注入）？
- [id: php:input-filter] [ ] 用户输入是否过滤（`htmlspecialchars`、`strip_tags`）？
- [id: php:upload-mime] [ ] 文件上传是否校验 MIME 类型和大小？
- [id: php:session-secure] [ ] Session 是否配置 `secure`、`httponly`、`samesite`？
- [id: php:register-globals] [ ] 是否禁用 `register_globals`、`magic_quotes`？

## 4. 性能
- [id: php:autoload-optimize] [ ] `composer autoload` 是否用 `optimize-autoloader`？
- [id: php:cache-redis] [ ] 缓存是否用 Redis/Memcached（非文件缓存）？
- [id: php:slow-query-index] [ ] 慢查询是否加索引？
- [id: php:opcache-enable] [ ] `opcache` 是否启用并正确配置？

## 5. 规范
- [id: php:psr-12] [ ] 是否遵循 PSR-12 代码规范？
- [id: php:psr-4] [ ] 命名空间是否与目录结构一致（PSR-4）？
- [id: php:deprecated-features] [ ] PHP 版本是否弃用旧特性（如 `mysql_*` 函数）？

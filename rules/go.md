# Go 代码审查专项规则

## 1. 并发
- [id: go:goroutine-lifecycle] [ ] `goroutine` 是否有对应的 `WaitGroup` / `context` 控制？
- [id: go:channel-close] [ ] `channel` 是否正确关闭（避免 panic）？
- [id: go:select-default] [ ] `select` 是否有 `default` 避免阻塞？
- [id: go:sync-pool] [ ] `sync.Pool` 是否在频繁分配场景使用？
- [id: go:mutex-critical-section] [ ] `mutex` 是否最小化临界区？

## 2. 错误处理
- [id: go:error-wrap] [ ] 错误是否包装而非直接返回（`fmt.Errorf("...: %w", err)`）？
- [id: go:error-check] [ ] 是否检查所有 error 返回值？
- [id: go:panic-usage] [ ] `panic` 是否仅在不可恢复场景使用？
- [id: go:defer-order] [ ] `defer` 顺序是否正确（LIFO）？

## 3. 性能
- [id: go:strings-builder] [ ] 字符串拼接是否用 `strings.Builder`？
- [id: go:slice-prealloc] [ ] 切片扩容是否预分配（`make([]T, 0, n)`）？
- [id: go:interface-avoid] [ ] `interface{}` 是否必要（影响编译优化）？
- [id: go:reflect-hotpth] [ ] 反射是否在高频路径使用？

## 4. 内存
- [id: go:closure-loop-var] [ ] 闭包是否捕获循环变量（Go < 1.22 陷阱）？
- [id: go:heap-escape] [ ] 大对象是否逃逸到堆（避免不必要的指针）？
- [id: go:nil-vs-empty-slice] [ ] `nil` 切片 vs 空切片 `[]T{}` 是否区分场景？

## 5. 项目规范
- [id: go:vet-lint] [ ] 是否通过 `go vet` / `golint` / `staticcheck`？
- [id: go:package-naming] [ ] 包名是否简洁（无下划线、无驼峰）？
- [id: go:exported-comment] [ ] 导出的标识符是否有注释？
- [id: go:context-first-param] [ ] `context.Context` 是否作为第一个参数传递？

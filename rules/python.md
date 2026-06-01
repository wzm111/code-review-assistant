# Python 代码审查专项规则

## 1. 语言特性
- [ ] `is` 是否用于值比较（应只用 `==`）？
- [ ] 可变默认参数是否导致意外共享（`def f(a=[])`）？
- [ ] 列表推导式是否嵌套过深（超过 2 层应拆分）？
- [ ] `with` 语句是否正确管理资源（文件、锁、连接）？
- [ ] `@staticmethod` vs `@classmethod` 是否选对？
- [ ] `__init__.py` 是否避免重逻辑（影响导入性能）？

## 2. 并发
- [ ] `GIL` 密集型是否用多进程替代多线程？
- [ ] `asyncio` 中是否混用同步阻塞调用？
- [ ] `ThreadPoolExecutor` 是否配 max_workers？
- [ ] 锁的获取是否有超时机制？

## 3. 性能
- [ ] 字符串拼接是否在循环中用 `''.join()`？
- [ ] 大文件是否用生成器/迭代器（避免全量加载）？
- [ ] `pandas` 是否用 `vectorized` 操作替代 `apply`/`iterrows`？
- [ ] `dict.get()` 是否替代 `try/except KeyError`？

## 4. 类型安全
- [ ] 函数参数/返回值是否有 `type hints`？
- [ ] `Optional[T]` 是否在需要时显式标注？
- [ ] `mypy` 是否能通过（无 `Any` 滥用）？

## 5. 安全
- [ ] `pickle` 是否用于不可信数据源？
- [ ] `subprocess` 是否用列表而非字符串（防注入）？
- [ ] `eval()`/`exec()` 是否经过输入过滤？
- [ ] `requirements.txt` 是否固定版本（防依赖攻击）？

## 6. 项目结构
- [ ] 是否遵循 PEP8（flake8/black 检查）？
- [ ] 模块名是否小写（无驼峰）？
- [ ] 测试是否用 `pytest`（非 unittest）？

# Python 代码审查专项规则

## 1. 语言特性
- [id: python:is-vs-equality] [ ] `is` 是否用于值比较（应只用 `==`）？
- [id: python:mutable-default-args] [ ] 可变默认参数是否导致意外共享（`def f(a=[])`）？
- [id: python:nested-list-comprehension] [ ] 列表推导式是否嵌套过深（超过 2 层应拆分）？
- [id: python:with-resource-management] [ ] `with` 语句是否正确管理资源（文件、锁、连接）？
- [id: python:staticmethod-vs-classmethod] [ ] `@staticmethod` vs `@classmethod` 是否选对？
- [id: python:init-py-heavy-logic] [ ] `__init__.py` 是否避免重逻辑（影响导入性能）？

## 2. 并发
- [id: python:gil-multiprocess] [ ] `GIL` 密集型是否用多进程替代多线程？
- [id: python:asyncio-sync-blocking] [ ] `asyncio` 中是否混用同步阻塞调用？
- [id: python:threadpool-max-workers] [ ] `ThreadPoolExecutor` 是否配 max_workers？
- [id: python:lock-timeout] [ ] 锁的获取是否有超时机制？

## 3. 性能
- [id: python:join-string-concat] [ ] 字符串拼接是否在循环中用 `''.join()`？
- [id: python:generator-large-file] [ ] 大文件是否用生成器/迭代器（避免全量加载）？
- [id: python:pandas-vectorized] [ ] `pandas` 是否用 `vectorized` 操作替代 `apply`/`iterrows`？
- [id: python:dict-get-vs-keyerror] [ ] `dict.get()` 是否替代 `try/except KeyError`？

## 4. 类型安全
- [id: python:type-hints] [ ] 函数参数/返回值是否有 `type hints`？
- [id: python:optional-annotation] [ ] `Optional[T]` 是否在需要时显式标注？
- [id: python:mypy-no-any] [ ] `mypy` 是否能通过（无 `Any` 滥用）？

## 5. 安全
- [id: python:pickle-untrusted] [ ] `pickle` 是否用于不可信数据源？
- [id: python:subprocess-list-args] [ ] `subprocess` 是否用列表而非字符串（防注入）？
- [id: python:eval-exec-filter] [ ] `eval()`/`exec()` 是否经过输入过滤？
- [id: python:requirements-pin-version] [ ] `requirements.txt` 是否固定版本（防依赖攻击）？

## 6. 项目结构
- [id: python:pep8-compliance] [ ] 是否遵循 PEP8（flake8/black 检查）？
- [id: python:module-lowercase] [ ] 模块名是否小写（无驼峰）？
- [id: python:pytest-over-unittest] [ ] 测试是否用 `pytest`（非 unittest）？

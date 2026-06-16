# Java 代码审查专项规则

## 1. 集合与并发
- [id: java:arraylist-concurrent-modification] [ ] `ArrayList` 在循环中删除元素时是否用 `Iterator` 或 `removeIf`？
- [id: java:hashmap-concurrent-usage] [ ] `HashMap` 在高并发下是否用 `ConcurrentHashMap`？
- [id: java:simpledateformat-thread-safety] [ ] `SimpleDateFormat` 是否被共享（线程不安全）？
- [id: java:synchronized-lock-granularity] [ ] `synchronized` 是否锁在正确粒度（避免锁类）？
- [id: java:stream-parallel-usage] [ ] `Stream.parallel()` 是否在 IO 密集型而非 CPU 密集型使用？
- [id: java:optional-unsafe-get] [ ] `Optional` 是否正确使用（禁止 `Optional.get()` 无检查）？

## 2. 内存与资源
- [id: java:try-with-resources] [ ] `try-with-resources` 是否用于 `AutoCloseable`（Connection、Stream、File）？
- [id: java:large-object-nullify] [ ] 大对象是否在 finally 中显式置 null？
- [id: java:stringbuilder-loop-concat] [ ] 字符串拼接是否在循环中用 `StringBuilder`？
- [id: java:wrapper-reference-equality] [ ] 是否误用 `==` 比较包装类型（`Integer`、`Long`）？
- [id: java:equals-hashcode-pair] [ ] `equals()` 和 `hashCode()` 是否成对重写？

## 3. Spring 框架
- [id: java:transactional-public-only] [ ] `@Transactional` 是否在 public 方法上？
- [id: java:transactional-self-invocation] [ ] 事务方法内部调用是否走代理（同类调用事务失效）？
- [id: java:autowired-constructor-injection] [ ] `@Autowired` 是否用构造器注入（推荐）而非字段注入？
- [id: java:value-default-fallback] [ ] `@Value` 是否配默认值防止启动失败？
- [id: java:scheduled-cluster-duplicate] [ ] `@Scheduled` 任务是否考虑集群重复执行？

## 4. 性能陷阱
- [id: java:list-size-in-loop-condition] [ ] `for (int i=0; i<list.size(); i++)` 是否每次计算 size？
- [id: java:currenttimemillis-in-loop] [ ] `System.currentTimeMillis()` 是否在循环中频繁调用？
- [id: java:regex-precompile] [ ] 正则表达式是否预编译（`Pattern.compile` 放 static final）？
- [id: java:sublist-vs-copy] [ ] 大 List 是否用 `subList` 而非复制？

## 5. 安全
- [id: java:sql-prepared-statement] [ ] SQL 是否用预编译语句（`PreparedStatement`）？
- [id: java:path-traversal-check] [ ] 文件路径是否校验防止目录遍历？
- [id: java:deserialize-class-filter] [ ] 反序列化是否过滤类名（防止反序列化漏洞）？
- [id: java:sensitive-log-masking] [ ] 敏感日志是否脱敏（手机号、身份证、银行卡）？

## 6. 代码规范
- [id: java:constant-naming-convention] [ ] 常量是否 `static final` 大写蛇形命名？
- [id: java:magic-number-extract] [ ] 魔法数字是否提取为常量？
- [id: java:exception-categorization] [ ] 异常是否区分业务异常和系统异常？
- [id: java:api-response-wrapper] [ ] 接口返回值是否用统一包装类（避免裸返回）？

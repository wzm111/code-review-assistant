# Java 代码审查专项规则

## 1. 集合与并发
- [ ] `ArrayList` 在循环中删除元素时是否用 `Iterator` 或 `removeIf`？
- [ ] `HashMap` 在高并发下是否用 `ConcurrentHashMap`？
- [ ] `SimpleDateFormat` 是否被共享（线程不安全）？
- [ ] `synchronized` 是否锁在正确粒度（避免锁类）？
- [ ] `Stream.parallel()` 是否在 IO 密集型而非 CPU 密集型使用？
- [ ] `Optional` 是否正确使用（禁止 `Optional.get()` 无检查）？

## 2. 内存与资源
- [ ] `try-with-resources` 是否用于 `AutoCloseable`（Connection、Stream、File）？
- [ ] 大对象是否在 finally 中显式置 null？
- [ ] 字符串拼接是否在循环中用 `StringBuilder`？
- [ ] 是否误用 `==` 比较包装类型（`Integer`、`Long`）？
- [ ] `equals()` 和 `hashCode()` 是否成对重写？

## 3. Spring 框架
- [ ] `@Transactional` 是否在 public 方法上？
- [ ] 事务方法内部调用是否走代理（同类调用事务失效）？
- [ ] `@Autowired` 是否用构造器注入（推荐）而非字段注入？
- [ ] `@Value` 是否配默认值防止启动失败？
- [ ] `@Scheduled` 任务是否考虑集群重复执行？

## 4. 性能陷阱
- [ ] `for (int i=0; i<list.size(); i++)` 是否每次计算 size？
- [ ] `System.currentTimeMillis()` 是否在循环中频繁调用？
- [ ] 正则表达式是否预编译（`Pattern.compile` 放 static final）？
- [ ] 大 List 是否用 `subList` 而非复制？

## 5. 安全
- [ ] SQL 是否用预编译语句（`PreparedStatement`）？
- [ ] 文件路径是否校验防止目录遍历？
- [ ] 反序列化是否过滤类名（防止反序列化漏洞）？
- [ ] 敏感日志是否脱敏（手机号、身份证、银行卡）？

## 6. 代码规范
- [ ] 常量是否 `static final` 大写蛇形命名？
- [ ] 魔法数字是否提取为常量？
- [ ] 异常是否区分业务异常和系统异常？
- [ ] 接口返回值是否用统一包装类（避免裸返回）？

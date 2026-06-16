# 数据库/SQL 审查专项规则

## 1. SQL 质量
- [id: database:no-select-star] [ ] 是否用 `SELECT *`（应指定字段）？
- [id: database:join-missing-on] [ ] `JOIN` 是否缺少 `ON` 条件导致笛卡尔积？
- [id: database:index-function-wipe] [ ] `WHERE` 条件是否对索引字段做函数操作（导致索引失效）？
- [id: database:like-leading-wildcard] [ ] `LIKE '%xxx%'` 是否导致全表扫描？
- [id: database:in-list-too-large] [ ] `IN` 子句元素是否过多（>1000 应分批或换 `JOIN`）？
- [id: database:order-by-without-limit] [ ] `ORDER BY` 是否配合 `LIMIT`（避免大数据排序）？
- [id: database:union-all-over-union] [ ] 是否用 `UNION ALL` 替代 `UNION`（去重有性能开销）？
- [id: database:batch-insert-values] [ ] 批量插入是否用 `INSERT ... VALUES (...), (...)`？

## 2. 索引
- [id: database:explain-check] [ ] 新查询是否走索引（`EXPLAIN` 检查）？
- [id: database:composite-left-prefix] [ ] 联合索引是否遵循最左前缀？
- [id: database:implicit-type-conversion] [ ] 索引字段是否做类型转换（隐式转换导致失效）？
- [id: database:duplicate-index] [ ] 是否重复索引（如已有 (a,b) 又建 (a)）？
- [id: database:large-table-inplace-alter] [ ] 大表加索引是否用 `ALGORITHM=INPLACE`？

## 3. 事务
- [id: database:transaction-minimal-scope] [ ] 事务范围是否最小化？
- [id: database:deadlock-risk] [ ] 是否死锁风险（不同事务加锁顺序不一致）？
- [id: database:long-transaction] [ ] 是否长事务（应及时提交）？
- [id: database:select-for-update-misuse] [ ] 读操作是否用 `SELECT FOR UPDATE`（不必要的锁）？

## 4. 数据一致性
- [id: database:decimal-for-money] [ ] 金额是否用 `DECIMAL` 而非 `FLOAT/DOUBLE`？
- [id: database:datetime-over-string] [ ] 时间是否用 `DATETIME`/`TIMESTAMP` 而非字符串？
- [id: database:avoid-enum-type] [ ] 枚举是否用 `TINYINT` 或 `VARCHAR` 而非 `ENUM` 类型？
- [id: database:soft-delete-deleted-at] [ ] 软删除是否统一用 `deleted_at` 字段？
- [id: database:foreign-key-indexed] [ ] 外键是否加索引？

## 5. ORM 使用
- [id: database:n-plus-one-query] [ ] 是否 N+1 查询（关联查询未 `fetch join`/`preload`）？
- [id: database:batch-update-over-loop] [ ] 批量更新是否用 `updateMany` 而非循环单条？
- [id: database:optimistic-lock-version] [ ] 乐观锁是否用版本号/时间戳？

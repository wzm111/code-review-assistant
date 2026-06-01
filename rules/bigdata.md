# 大数据代码审查专项规则

## 1. Apache Spark
- [ ] `spark.sql.shuffle.partitions` 是否调优（默认 200 可能不适合）？
- [ ] `cache()` / `persist()` 是否在重复使用时？
- [ ] `repartition()` vs `coalesce()` 是否选对（shuffle 开销）？
- [ ] `UDF` 是否可用内置函数替代（ Catalyst 优化）？
- [ ] 是否避免 `collect()` 大结果集到 Driver？
- [ ] `broadcast join` 是否用于小表（<10MB）？
- [ ] `groupByKey` 是否用 `reduceByKey` / `aggregateByKey` 替代？
- [ ] 是否处理数据倾斜（salting / 自定义 partitioner）？
- [ ] CheckPoint 是否在长 lineage 链中设置？
- [ ] 资源分配是否合理（executor memory/cores）？

## 2. Apache Flink
- [ ] Watermark 策略是否正确（乱序容忍度）？
- [ ] State 是否用 TTL 清理（防无限增长）？
- [ ] KeyedProcessFunction 是否key选择合理（防热点）？
- [ ] Checkpoint 间隔是否配置（平衡一致性和性能）？
- [ ] Side Output 是否用于异常流（非过滤丢弃）？
- [ ] Exactly-once 是否用两阶段提交（Kafka sink）？
- [ ] 是否避免在 ProcessFunction 中阻塞操作？

## 3. Hive SQL
- [ ] 是否用 ORC / Parquet 格式（非 TextFile）？
- [ ] 是否分区裁剪（WHERE 带分区字段）？
- [ ] `MapJoin` 是否小表放左边？
- [ ] `sort by` vs `order by` vs `distribute by` 是否区分？
- [ ] 是否避免 `SELECT COUNT(DISTINCT)`（用 `GROUP BY` 替代）？
- [ ] `INSERT OVERWRITE` 是否意外删除数据？
- [ ] 压缩是否启用（Snappy / ZLIB）？

## 4. 数据管道
- [ ] Schema Evolution 是否兼容（Avro / Protobuf）？
- [ ] 数据质量检查是否嵌入（空值/范围/格式）？
- [ ] 重试机制是否幂等（防重复写入）？
- [ ] SLA 监控是否配置（延迟告警）？
- [ ] 数据血缘是否可追踪？

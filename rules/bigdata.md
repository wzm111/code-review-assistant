# 大数据代码审查专项规则

## 1. Apache Spark
- [id: bigdata:shuffle-partitions-tuning] [ ] `spark.sql.shuffle.partitions` 是否调优（默认 200 可能不适合）？
- [id: bigdata:cache-persist-usage] [ ] `cache()` / `persist()` 是否在重复使用时？
- [id: bigdata:repartition-vs-coalesce] [ ] `repartition()` vs `coalesce()` 是否选对（shuffle 开销）？
- [id: bigdata:udf-builtin-replacement] [ ] `UDF` 是否可用内置函数替代（ Catalyst 优化）？
- [id: bigdata:avoid-collect-large] [ ] 是否避免 `collect()` 大结果集到 Driver？
- [id: bigdata:broadcast-join-small-table] [ ] `broadcast join` 是否用于小表（<10MB）？
- [id: bigdata:reduce-aggregate-bykey] [ ] `groupByKey` 是否用 `reduceByKey` / `aggregateByKey` 替代？
- [id: bigdata:data-skew-handling] [ ] 是否处理数据倾斜（salting / 自定义 partitioner）？
- [id: bigdata:checkpoint-lineage] [ ] CheckPoint 是否在长 lineage 链中设置？
- [id: bigdata:resource-allocation] [ ] 资源分配是否合理（executor memory/cores）？

## 2. Apache Flink
- [id: bigdata:watermark-strategy] [ ] Watermark 策略是否正确（乱序容忍度）？
- [id: bigdata:state-ttl-cleanup] [ ] State 是否用 TTL 清理（防无限增长）？
- [id: bigdata:keyed-process-hotspot] [ ] KeyedProcessFunction 是否key选择合理（防热点）？
- [id: bigdata:checkpoint-interval] [ ] Checkpoint 间隔是否配置（平衡一致性和性能）？
- [id: bigdata:side-output-exception] [ ] Side Output 是否用于异常流（非过滤丢弃）？
- [id: bigdata:exactly-once-two-phase] [ ] Exactly-once 是否用两阶段提交（Kafka sink）？
- [id: bigdata:process-function-blocking] [ ] 是否避免在 ProcessFunction 中阻塞操作？

## 3. Hive SQL
- [id: bigdata:orc-parquet-format] [ ] 是否用 ORC / Parquet 格式（非 TextFile）？
- [id: bigdata:partition-pruning] [ ] 是否分区裁剪（WHERE 带分区字段）？
- [id: bigdata:mapjoin-small-left] [ ] `MapJoin` 是否小表放左边？
- [id: bigdata:sort-order-distribute-by] [ ] `sort by` vs `order by` vs `distribute by` 是否区分？
- [id: bigdata:count-distinct-avoid] [ ] 是否避免 `SELECT COUNT(DISTINCT)`（用 `GROUP BY` 替代）？
- [id: bigdata:insert-overwrite-safety] [ ] `INSERT OVERWRITE` 是否意外删除数据？
- [id: bigdata:compression-enabled] [ ] 压缩是否启用（Snappy / ZLIB）？

## 4. 数据管道
- [id: bigdata:schema-evolution-compat] [ ] Schema Evolution 是否兼容（Avro / Protobuf）？
- [id: bigdata:data-quality-checks] [ ] 数据质量检查是否嵌入（空值/范围/格式）？
- [id: bigdata:retry-idempotency] [ ] 重试机制是否幂等（防重复写入）？
- [id: bigdata:sla-monitoring] [ ] SLA 监控是否配置（延迟告警）？
- [id: bigdata:data-lineage-traceable] [ ] 数据血缘是否可追踪？

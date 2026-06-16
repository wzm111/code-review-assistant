# AI/ML 代码审查专项规则

## 1. 数据处理
- [id: aiml:data-leakage-prevention] [ ] 训练/验证/测试集是否严格隔离（防数据泄漏）？
- [id: aiml:missing-value-handling] [ ] 缺失值处理是否合理（删除/填充/插值）？
- [id: aiml:feature-scale-after-split] [ ] 特征缩放是否在 split 后 fit（防泄漏）？
- [id: aiml:category-encoding-correct] [ ] 类别特征是否正确编码（One-hot / Target / Ordinal）？
- [id: aiml:timeseries-temporal-split] [ ] 时间序列是否按时间分割（非随机）？
- [id: aiml:imbalance-handling] [ ] 样本不平衡是否处理（SMOTE / 加权 / Focal Loss）？
- [id: aiml:data-augmentation-reasonable] [ ] 数据增强是否合理（不过度/不失真）？

## 2. 模型训练
- [id: aiml:hyperparameter-search] [ ] 超参数是否网格/随机搜索（非手动调）？
- [id: aiml:early-stopping-config] [ ] Early Stopping 是否配置（防过拟合）？
- [id: aiml:lr-schedule-cosine-warmup] [ ] 学习率调度是否合理（Cosine / Warmup）？
- [id: aiml:gradient-clipping-rnn-transformer] [ ] 梯度裁剪是否用于 RNN / Transformer？
- [id: aiml:mixed-precision-amp] [ ] 混合精度训练（AMP）是否启用？
- [id: aiml:sync-batchnorm-dist] [ ] 分布式训练是否同步 BatchNorm？
- [id: aiml:random-seed-fixed] [ ] 随机种子是否固定（保证可复现）？

## 3. PyTorch 专项
- [id: aiml:train-eval-mode-switch] [ ] `model.train()` / `model.eval()` 是否正确切换？
- [id: aiml:torch-no-grad-inference] [ ] `torch.no_grad()` 是否在推理时？
- [id: aiml:dataloader-pin-memory-workers] [ ] `DataLoader` 是否 `pin_memory=True` / `num_workers>0`？
- [id: aiml:tensor-device-unified] [ ] 张量是否 `.to(device)` 统一（防 CPU/GPU 混用）？
- [id: aiml:zero-grad-before-backward] [ ] `backward()` 前是否 `optimizer.zero_grad()`？
- [id: aiml:torch-jit-onnx-export] [ ] 是否用 `torch.jit.script` / `torch.onnx` 导出优化？

## 4. TensorFlow 专项
- [id: aiml:tf-function-graph-mode] [ ] `tf.function` 是否用于训练循环（图模式加速）？
- [id: aiml:tf-data-prefetch-cache] [ ] `tf.data` pipeline 是否 prefetch / cache？
- [id: aiml:tf-mixed-precision-policy] [ ] `mixed_precision` policy 是否启用？
- [id: aiml:tf-savedmodel-production] [ ] `SavedModel` 是否用于生产部署？
- [id: aiml:tf-tensorboard-logging] [ ] `TensorBoard` 是否记录关键指标？

## 5. 模型评估与部署
- [id: aiml:evaluation-metrics-comprehensive] [ ] 评估指标是否全面（Precision / Recall / F1 / AUC）？
- [id: aiml:cross-validation-stratified] [ ] 是否做交叉验证（K-Fold / Stratified）？
- [id: aiml:model-version-management] [ ] 模型版本是否管理（MLflow / DVC）？
- [id: aiml:inference-batching] [ ] 推理服务是否 batching / dynamic batching？
- [id: aiml:model-quantization-pruning] [ ] 模型是否量化/剪枝（移动端/边缘部署）？
- [id: aiml:ab-test-design] [ ] A/B 测试是否设计（灰度发布）？

## 6. 伦理与安全
- [id: aiml:training-data-bias] [ ] 训练数据是否有偏见（性别/种族/地域）？
- [id: aiml:model-explainability] [ ] 模型输出是否可解释（SHAP / LIME）？
- [id: aiml:privacy-data-anonymization] [ ] 隐私数据是否脱敏（差分隐私 / 联邦学习）？
- [id: aiml:adversarial-training-defense] [ ] 对抗攻击是否防御（Adversarial Training）？

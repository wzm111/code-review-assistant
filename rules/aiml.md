# AI/ML 代码审查专项规则

## 1. 数据处理
- [ ] 训练/验证/测试集是否严格隔离（防数据泄漏）？
- [ ] 缺失值处理是否合理（删除/填充/插值）？
- [ ] 特征缩放是否在 split 后 fit（防泄漏）？
- [ ] 类别特征是否正确编码（One-hot / Target / Ordinal）？
- [ ] 时间序列是否按时间分割（非随机）？
- [ ] 样本不平衡是否处理（SMOTE / 加权 / Focal Loss）？
- [ ] 数据增强是否合理（不过度/不失真）？

## 2. 模型训练
- [ ] 超参数是否网格/随机搜索（非手动调）？
- [ ] Early Stopping 是否配置（防过拟合）？
- [ ] 学习率调度是否合理（Cosine / Warmup）？
- [ ] 梯度裁剪是否用于 RNN / Transformer？
- [ ] 混合精度训练（AMP）是否启用？
- [ ] 分布式训练是否同步 BatchNorm？
- [ ] 随机种子是否固定（保证可复现）？

## 3. PyTorch 专项
- [ ] `model.train()` / `model.eval()` 是否正确切换？
- [ ] `torch.no_grad()` 是否在推理时？
- [ ] `DataLoader` 是否 `pin_memory=True` / `num_workers>0`？
- [ ] 张量是否 `.to(device)` 统一（防 CPU/GPU 混用）？
- [ ] `backward()` 前是否 `optimizer.zero_grad()`？
- [ ] 是否用 `torch.jit.script` / `torch.onnx` 导出优化？

## 4. TensorFlow 专项
- [ ] `tf.function` 是否用于训练循环（图模式加速）？
- [ ] `tf.data` pipeline 是否 prefetch / cache？
- [ ] `mixed_precision` policy 是否启用？
- [ ] `SavedModel` 是否用于生产部署？
- [ ] `TensorBoard` 是否记录关键指标？

## 5. 模型评估与部署
- [ ] 评估指标是否全面（Precision / Recall / F1 / AUC）？
- [ ] 是否做交叉验证（K-Fold / Stratified）？
- [ ] 模型版本是否管理（MLflow / DVC）？
- [ ] 推理服务是否 batching / dynamic batching？
- [ ] 模型是否量化/剪枝（移动端/边缘部署）？
- [ ] A/B 测试是否设计（灰度发布）？

## 6. 伦理与安全
- [ ] 训练数据是否有偏见（性别/种族/地域）？
- [ ] 模型输出是否可解释（SHAP / LIME）？
- [ ] 隐私数据是否脱敏（差分隐私 / 联邦学习）？
- [ ] 对抗攻击是否防御（Adversarial Training）？

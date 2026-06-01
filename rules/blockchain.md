# 区块链/智能合约审查专项规则

## 1. Solidity 智能合约安全
- [ ] 重入攻击：是否用 `Checks-Effects-Interactions` 模式？
- [ ] 整数溢出：是否用 Solidity ^0.8 或 SafeMath？
- [ ] 访问控制：`onlyOwner` / `AccessControl` 是否正确？
- [ ] 随机数：是否用 `block.timestamp` / `blockhash`（可预测）？
- [ ] 外部调用：返回值是否检查（`.call` / `.delegatecall`）？
- [ ] 自毁函数：`selfdestruct` 是否可控？
- [ ] 时间操控：`block.timestamp` 是否用于关键逻辑？
- [ ] 短地址攻击：是否验证 `msg.data` 长度？

## 2. Gas 优化
- [ ] 存储变量是否最小化（SSTORE 昂贵）？
- [ ] `calldata` vs `memory` 是否选对（外部函数用 calldata）？
- [ ] 循环中是否避免存储写入？
- [ ] 是否用 `immutable` / `constant` 替代状态变量？
- [ ] 事件参数是否 `indexed`（节省 gas）？
- [ ] 是否打包变量（uint128 + uint128 <- 一个 storage slot）？
- [ ] `require` 错误信息是否简短（长字符串占 gas）？

## 3. 合约架构
- [ ] 是否用 `proxy` 模式支持升级（OpenZeppelin）？
- [ ] 是否遵循 `pull over push` 支付模式？
- [ ] 是否实现紧急暂停（`Pausable`）？
- [ ] 是否有限额机制（提款上限）？
- [ ] 多签钱包是否用于关键操作？

## 4. 测试与验证
- [ ] 是否用 Hardhat / Foundry 写单元测试？
- [ ] 是否测试边界条件（最大值/零值/异常）？
- [ ] 是否用 Slither / Mythril 静态分析？
- [ ] 是否做 fuzzing 测试（Foundry）？
- [ ] 主网部署前是否在测试网充分验证？

## 5. DeFi 专项
- [ ] 价格预言机是否去中心化（Chainlink / TWAP）？
- [ ] 闪电贷攻击是否防御（重入检查 / 状态校验）？
- [ ] MEV 是否考虑（滑点保护 / 最小输出）？
- [ ] 流动性挖矿是否防通胀（释放曲线）？

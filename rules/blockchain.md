# 区块链/智能合约审查专项规则

## 1. Solidity 智能合约安全
- [id: blockchain:reentrancy-checks-effects-interactions] [ ] 重入攻击：是否用 `Checks-Effects-Interactions` 模式？
- [id: blockchain:integer-overflow-safe] [ ] 整数溢出：是否用 Solidity ^0.8 或 SafeMath？
- [id: blockchain:access-control-check] [ ] 访问控制：`onlyOwner` / `AccessControl` 是否正确？
- [id: blockchain:randomness-block-timestamp] [ ] 随机数：是否用 `block.timestamp` / `blockhash`（可预测）？
- [id: blockchain:external-call-return-check] [ ] 外部调用：返回值是否检查（`.call` / `.delegatecall`）？
- [id: blockchain:selfdestruct-control] [ ] 自毁函数：`selfdestruct` 是否可控？
- [id: blockchain:block-timestamp-critical] [ ] 时间操控：`block.timestamp` 是否用于关键逻辑？
- [id: blockchain:short-address-validation] [ ] 短地址攻击：是否验证 `msg.data` 长度？

## 2. Gas 优化
- [id: blockchain:storage-minimize] [ ] 存储变量是否最小化（SSTORE 昂贵）？
- [id: blockchain:calldata-vs-memory] [ ] `calldata` vs `memory` 是否选对（外部函数用 calldata）？
- [id: blockchain:loop-storage-write-avoid] [ ] 循环中是否避免存储写入？
- [id: blockchain:immutable-constant-usage] [ ] 是否用 `immutable` / `constant` 替代状态变量？
- [id: blockchain:event-indexed-params] [ ] 事件参数是否 `indexed`（节省 gas）？
- [id: blockchain:variable-packing-storage] [ ] 是否打包变量（uint128 + uint128 <- 一个 storage slot）？
- [id: blockchain:require-message-short] [ ] `require` 错误信息是否简短（长字符串占 gas）？

## 3. 合约架构
- [id: blockchain:proxy-pattern-upgradeable] [ ] 是否用 `proxy` 模式支持升级（OpenZeppelin）？
- [id: blockchain:pull-over-push-pattern] [ ] 是否遵循 `pull over push` 支付模式？
- [id: blockchain:pausable-emergency-stop] [ ] 是否实现紧急暂停（`Pausable`）？
- [id: blockchain:withdrawal-limit] [ ] 是否有限额机制（提款上限）？
- [id: blockchain:multisig-critical-ops] [ ] 多签钱包是否用于关键操作？

## 4. 测试与验证
- [id: blockchain:hardhat-foundry-unit-test] [ ] 是否用 Hardhat / Foundry 写单元测试？
- [id: blockchain:boundary-condition-test] [ ] 是否测试边界条件（最大值/零值/异常）？
- [id: blockchain:slither-mythril-static-analysis] [ ] 是否用 Slither / Mythril 静态分析？
- [id: blockchain:fuzzing-foundry-test] [ ] 是否做 fuzzing 测试（Foundry）？
- [id: blockchain:testnet-verify-before-mainnet] [ ] 主网部署前是否在测试网充分验证？

## 5. DeFi 专项
- [id: blockchain:oracle-decentralized-price] [ ] 价格预言机是否去中心化（Chainlink / TWAP）？
- [id: blockchain:flash-loan-attack-defense] [ ] 闪电贷攻击是否防御（重入检查 / 状态校验）？
- [id: blockchain:mev-slippage-protection] [ ] MEV 是否考虑（滑点保护 / 最小输出）？
- [id: blockchain:liquidity-mining-inflation-guard] [ ] 流动性挖矿是否防通胀（释放曲线）？

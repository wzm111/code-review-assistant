# 移动端代码审查专项规则

## 1. iOS / Swift
- [ ] `!` 强制解包是否安全（优先 `?` / `guard let`）？
- [ ] `weak self` 是否在闭包中避免循环引用？
- [ ] `DispatchQueue.main` 是否在 UI 操作时使用？
- [ ] `UserDefaults` 是否存储敏感数据（应存 Keychain）？
- [ ] 网络请求是否处理弱网/无网状态？
- [ ] 图片是否用 `UIImage(named:)` 缓存（避免重复加载）？
- [ ] `UITableView` / `UICollectionView` 是否 cell 复用？
- [ ] 是否适配 Dark Mode / Dynamic Type？
- [ ] App 是否处理后台状态（`applicationDidEnterBackground`）？
- [ ] 定位/相机/麦克风权限是否提前申请？

## 2. Android / Kotlin
- [ ] `!!` 是否滥用（应用 `?.let` / `?:`）？
- [ ] `LifecycleObserver` 是否正确绑定（防内存泄漏）？
- [ ] `Coroutine` 是否在正确 `Dispatcher` 上（IO/Default/Main）？
- [ ] `ViewBinding` 是否替代 `findViewById`？
- [ ] `RecyclerView` 是否 ViewHolder 复用？
- [ ] 后台任务是否用 `WorkManager`（非 Service）？
- [ ] Bitmap 是否压缩/复用（防 OOM）？
- [ ] `SharedPreferences` 是否 `apply()` 替代 `commit()`？
- [ ] 敏感数据是否存 `EncryptedSharedPreferences`？
- [ ] 是否适配不同屏幕密度（dpi）？

## 3. Flutter
- [ ] `setState()` 是否最小化重建范围？
- [ ] `BuildContext` 是否在 async 后使用（防 mounted 问题）？
- [ ] 图片是否用 `cached_network_image`？
- [ ] `FutureBuilder` 是否有 error/loading 状态？
- [ ] Platform Channel 是否异常处理？
- [ ] 是否避免 `shrinkWrap: true` 在大列表（用 Sliver）？
- [ ] 动画是否在 dispose 中清理？

## 4. React Native
- [ ] `useEffect` 是否在组件卸载时清理？
- [ ] `FlatList` 是否配置 `keyExtractor` / `getItemLayout`？
- [ ] 原生模块是否主线程调用（桥接性能）？
- [ ] Hermes 是否启用（减小包体积）？
- [ ] 第三方库是否支持新架构（TurboModules/Fabric）？
- [ ] 是否处理 Android 返回键 / iOS 手势返回？

## 5. 通用移动端
- [ ] 是否支持离线模式（本地缓存策略）？
- [ ] 包体积是否优化（代码分割、资源压缩）？
- [ ] 是否接入崩溃监控（Firebase/Crashlytics/Bugly）？
- [ ] 启动时间是否优化（懒加载、预加载）？
- [ ] 是否处理低内存警告？
- [ ] 手势冲突是否处理（滑动返回 vs 侧滑菜单）？
